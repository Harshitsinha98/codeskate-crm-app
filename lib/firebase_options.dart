// Firebase configuration for project `sns-ads-erp`.
//
// These are public client identifiers (same values as
// android/app/google-services.json and ios/Runner/GoogleService-Info.plist).
// They are NOT secrets — access is enforced by Firestore security rules and
// backend auth. Never put a service-account / Admin SDK key in the app.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android and iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCzGYjPc0lv5mL5LFz7LS4rI6p9KQuDKHY',
    appId: '1:198172798900:android:a074d9b596d115c6370ce1',
    messagingSenderId: '198172798900',
    projectId: 'sns-ads-erp',
    storageBucket: 'sns-ads-erp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCd9SwDCqoTj2bloAWhShMH78_LDfGCRyg',
    appId: '1:198172798900:ios:71a478cadc9d0457370ce1',
    messagingSenderId: '198172798900',
    projectId: 'sns-ads-erp',
    storageBucket: 'sns-ads-erp.firebasestorage.app',
    iosBundleId: 'com.codeskate.crm',
  );

  // Web is not shipped from this repo (the web CRM lives in SNS-ADS-ERP);
  // reuse the Android key so `flutter run -d chrome` can at least boot.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCzGYjPc0lv5mL5LFz7LS4rI6p9KQuDKHY',
    appId: '1:198172798900:android:a074d9b596d115c6370ce1',
    messagingSenderId: '198172798900',
    projectId: 'sns-ads-erp',
    authDomain: 'sns-ads-erp.firebaseapp.com',
    storageBucket: 'sns-ads-erp.firebasestorage.app',
  );
}
