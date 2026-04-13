// ignore_for_file: lines_longer_than_80_chars
//
// Firebase — Scertta Rider (Android: com.scertta.mobile · iOS: alinear con Xcode)
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure

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
      throw UnsupportedError('FCM web no configurado para Rider.');
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

  /// Debe coincidir con el Bundle ID de la app iOS en Xcode / Firebase.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _iosApiKey,
    appId: _iosAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: 'com.scertta.mobile',
  );

  static const String _androidApiKey = 'YOUR_ANDROID_API_KEY';
  static const String _androidAppId = 'YOUR_ANDROID_APP_ID';
  static const String _iosApiKey = 'YOUR_IOS_API_KEY';
  static const String _iosAppId = 'YOUR_IOS_APP_ID';
  static const String _messagingSenderId = 'YOUR_MESSAGING_SENDER_ID';
  static const String _projectId = 'YOUR_PROJECT_ID';
  static const String _storageBucket = 'YOUR_PROJECT_ID.appspot.com';
}
