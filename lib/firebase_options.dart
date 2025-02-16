import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web platform is not supported for this application.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'Only Windows platform is supported for this application.',
        );
    }
  }

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBscRwh47cUzdyaYrnDdh6UrwijKgIGILU',
    appId: '1:105139609013:web:7405d090a256a4a7688dfc',
    messagingSenderId: '105139609013',
    projectId: 'personal-f8a14',
    authDomain: 'personal-f8a14.firebaseapp.com',
    databaseURL: 'https://personal-f8a14-default-rtdb.firebaseio.com',
    storageBucket: 'personal-f8a14.appspot.com',
    measurementId: 'G-T6QGMDDJ1C',
  );
} 