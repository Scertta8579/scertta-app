// ignore_for_file: lines_longer_than_80_chars
//
// Firebase — Scertta Driver (Android: com.scertta.scertta_driver · iOS: com.scertta.scerttaDriver)
//
// Opción A (recomendada): en la carpeta de la app ejecutá:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//   (sobrescribe este archivo con valores reales.)
//
// Opción B: en Firebase Console → Configuración del proyecto → Tus apps,
// copiá apiKey, appId, messagingSenderId, projectId, storageBucket y
// iosBundleId desde la hoja de cada plataforma.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static bool get isConfigured {
    const k = _androidApiKey;
    return k.isNotEmpty && !k.startsWith('YOUR_');
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('FCM web no configurado para Driver.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soporta esta plataforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _androidApiKey,
    appId: _androidAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _iosApiKey,
    appId: _iosAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: 'com.scertta.scerttaDriver',
  );

  static const String _androidApiKey = 'YOUR_ANDROID_API_KEY';
  static const String _androidAppId = 'YOUR_ANDROID_APP_ID';
  static const String _iosApiKey = 'YOUR_IOS_API_KEY';
  static const String _iosAppId = 'YOUR_IOS_APP_ID';
  static const String _messagingSenderId = 'YOUR_MESSAGING_SENDER_ID';
  static const String _projectId = 'YOUR_PROJECT_ID';
  static const String _storageBucket = 'YOUR_PROJECT_ID.appspot.com';
}
