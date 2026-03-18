import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC9qZ3vYnQKDdrQRmhiWI2RSb3oyKE4RU0',
    appId: '1:709333360623:android:e65a6f679352994d0fa01a',
    messagingSenderId: '709333360623',
    projectId: 'servicios-domicilio-mvp',
    storageBucket: 'servicios-domicilio-mvp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCd9xFAjs9zG3F8JODaOcsY7m8EfZcPoho',
    appId: '1:709333360623:ios:81d9150aeea895f50fa01a',
    messagingSenderId: '709333360623',
    projectId: 'servicios-domicilio-mvp',
    storageBucket: 'servicios-domicilio-mvp.firebasestorage.app',
    iosBundleId: 'com.serviciosdomicilio.mvp',
  );
}
