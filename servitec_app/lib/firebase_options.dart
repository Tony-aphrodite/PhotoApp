import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show appFlavor;

/// Whether this build talks to the servitec-dev project instead of prod.
/// Set by the Android flavor: `flutter build apk --flavor dev`.
bool get isDevBuild => appFlavor == 'dev';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return isDevBuild ? androidDev : android;
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
    authDomain: 'servicios-domicilio-mvp.firebaseapp.com',
  );

  /// servitec-dev. Values come from that project's google-services.json
  /// (android/app/src/dev/google-services.json): apiKey = api_key.current_key,
  /// appId = client.client_info.mobilesdk_app_id for the .dev package,
  /// messagingSenderId = project_info.project_number.
  static const FirebaseOptions androidDev = FirebaseOptions(
    apiKey: 'PENDIENTE_DEV_API_KEY',
    appId: 'PENDIENTE_DEV_APP_ID',
    messagingSenderId: 'PENDIENTE_DEV_SENDER_ID',
    projectId: 'servitec-dev',
    storageBucket: 'servitec-dev.firebasestorage.app',
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
