import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';

/// Canal Android: máxima importancia, sonido y vibración. El servidor FCM
/// debe incluir `"android_channel_id": "scertta_trips_critical"` en el payload.
class PushNotificationChannels {
  PushNotificationChannels._();

  static const String tripsChannelId = 'scertta_trips_critical';
  static const String tripsChannelName = 'Viajes y alertas';
  static const String tripsChannelDescription =
      'Nuevo viaje y avisos urgentes. Sonido y vibración.';

  /// Con `res/raw/scertta_trip.wav` podés usar:
  /// `sound: RawResourceAndroidNotificationSound('scertta_trip')` en [_androidTripDetails].
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isConfigured) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService.displayBackgroundNotification(message);
}

class PushNotificationService {
  PushNotificationService._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _localReady = false;
  static StreamSubscription? _authSub;
  static StreamSubscription<String>? _tokenRefreshSub;

  static Future<void> initializeFirebaseAndMessaging() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        '[Push] Omitido: completá lib/firebase_options.dart o `flutterfire configure`.',
      );
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await _initLocalNotifications();

    final messaging = FirebaseMessaging.instance;

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('[Push] FCM permission: ${settings.authorizationStatus}');

    await messaging.setAutoInitEnabled(true);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('Push opened from background: ${message.data}',
          name: 'ScerttaPush');
      _maybeShowInAppHint(message);
    });

    try {
      await messaging.getToken();
      debugPrint('[Push] FCM token listo (se persistirá tras Supabase.initialize)');
    } catch (e, st) {
      debugPrint('[Push] getToken error: $e\n$st');
    }
  }

  static Future<void> bindSupabase(SupabaseClient client) async {
    if (!DefaultFirebaseOptions.isConfigured) return;

    await _persistToken(client, await FirebaseMessaging.instance.getToken());

    await _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) {
        await _persistToken(
          client,
          await FirebaseMessaging.instance.getToken(),
        );
      }
    });

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
      await _persistToken(client, t);
    });
  }

  static Future<void> handleInitialMessage() async {
    if (!DefaultFirebaseOptions.isConfigured) return;
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      developer.log('Push cold start: ${initial.data}', name: 'ScerttaPush');
      _maybeShowInAppHint(initial);
    }
  }

  static void _maybeShowInAppHint(RemoteMessage message) {
    final title = message.notification?.title ?? 'Scertta';
    final body = message.notification?.body ?? message.data.toString();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('$title\n$body'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
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
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        developer.log('Local notification tap: ${r.payload}', name: 'ScerttaPush');
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

  static Future<void> displayBackgroundNotification(RemoteMessage message) async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: initSettings);

    final androidPlugin = plugin.resolvePlatformSpecificImplementation<
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

    final id = message.messageId?.hashCode.abs() ??
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 30);

    await plugin.show(
      id: id,
      title: message.notification?.title ?? 'Scertta',
      body: message.notification?.body ?? message.data.toString(),
      notificationDetails: NotificationDetails(
        android: _androidTripDetails(),
        iOS: _darwinTripDetails(),
      ),
    );
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    await _initLocalNotifications();
    final id = message.messageId?.hashCode.abs() ??
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 30);

    await _local.show(
      id: id,
      title: message.notification?.title ?? 'Scertta',
      body: message.notification?.body ?? message.data.toString(),
      notificationDetails: NotificationDetails(
        android: _androidTripDetails(),
        iOS: _darwinTripDetails(),
      ),
    );
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

  static Future<void> _persistToken(
    SupabaseClient client,
    String? token,
  ) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null || token == null || token.isEmpty) return;
    try {
      await client.from('perfiles').update({
        'fcm_token': token,
        'fcm_token_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
      debugPrint('[Push] Token guardado en perfiles');
    } catch (e, st) {
      debugPrint('[Push] Error guardando token en Supabase: $e\n$st');
    }
  }
}
