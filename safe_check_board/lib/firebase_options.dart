// =====================================================================
// !! 이 파일을 실제 Firebase 설정으로 교체해야 합니다 !!
//
// Firebase 콘솔 → 프로젝트 설정 → 내 앱(웹) → Firebase SDK 스니펫 에서
// 아래 각 항목의 값을 복사해 붙여넣으세요.
// =====================================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('web 전용 앱입니다.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCGypAWvekehSZE6WsLaO0G8syExL8Fjok',
    appId: '1:59250273262:web:3ca963f95ce086340bfcff',
    messagingSenderId: '59250273262',
    projectId: 'safecheckboard',
    authDomain: 'safecheckboard.firebaseapp.com',
    storageBucket: 'safecheckboard.firebasestorage.app',
  );
}
