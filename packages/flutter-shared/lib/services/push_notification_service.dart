import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Canal Android: máxima importancia, sonido y vibración.
class PushNotificationChannels {
  PushNotificationChannels._();

  static const String tripsChannelId = 'rutmy_trips_critical';
  static const String tripsChannelName = 'Viajes y alertas';
  static const String tripsChannelDescription =
      'Nuevo viaje y avisos urgentes. Sonido y vibración.';
}

/// Servicio de notificaciones basado en **Supabase Realtime** (WebSocket).
/// Reemplaza a Firebase Cloud Messaging. Cero dependencias de terceros:
/// la app se suscribe al canal `notificaciones` de Supabase y dispara una
/// notificación local cuando llega un insert dirigido al usuario.
class PushNotificationService {
  PushNotificationService._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _localReady = false;
  static StreamSubscription? _authSub;
  static RealtimeChannel? _channel;

  /// Inicializa las notificaciones locales (sin Firebase).
  static Future<void> initialize() async {
    await _initLocalNotifications();
  }

  /// Suscribe al usuario a Supabase Realtime para recibir notificaciones.
  static Future<void> bindSupabase(SupabaseClient client) async {
    await _initLocalNotifications();

    await _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((data) {
      final uid = data.session?.user.id;
      if (uid != null) _subscribe(client, uid);
    });

    final uid = client.auth.currentUser?.id;
    if (uid != null) _subscribe(client, uid);
  }

  static void _subscribe(SupabaseClient client, String uid) {
    _channel?.unsubscribe();
    _channel = client
        .channel('notificaciones_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: uid,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            _showLocalNotification(
              title: record['titulo']?.toString() ?? 'Rutmy',
              body: record['mensaje']?.toString() ?? '',
            );
          },
        )
        .subscribe();
  }

  static Future<void> handleInitialMessage() async {
    // Sin FCM no hay "mensaje inicial" de arranque en frío; la app consulta
    // el centro de notificaciones in-app al cargar.
    developer.log('Push: Supabase Realtime activo (sin FCM).', name: 'RutmyPush');
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    await _initLocalNotifications();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 30);
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: _androidTripDetails(),
        iOS: _darwinTripDetails(),
      ),
    );
  }

  static Future<void> _initLocalNotifications() async {
    if (_localReady) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        developer.log('Local notification tap: ${r.payload}', name: 'RutmyPush');
      },
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          PushNotificationChannels.tripsChannelId,
          PushNotificationChannels.tripsChannelName,
          description: PushNotificationChannels.tripsChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        ),
      );
    }

    _localReady = true;
  }

  static AndroidNotificationDetails _androidTripDetails() {
    return AndroidNotificationDetails(
      PushNotificationChannels.tripsChannelId,
      PushNotificationChannels.tripsChannelName,
      channelDescription: PushNotificationChannels.tripsChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.status,
      fullScreenIntent: true,
    );
  }

  static DarwinNotificationDetails _darwinTripDetails() {
    return const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
  }
}
