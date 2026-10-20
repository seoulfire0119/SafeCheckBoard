import { initializeApp } from 'firebase/app';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';
import type { FirebaseError } from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth,
  GoogleAuthProvider,
  linkWithPopup,
  signInAnonymously,
  signInWithCredential,
  signInWithPopup,
  signOut,
  type User,
} from 'firebase/auth';

export const usingEmulator = import.meta.env.DEV && import.meta.env.VITE_USE_EMULATOR === '1';

const app = initializeApp({
  apiKey: import.meta.env.VITE_FB_API_KEY,
  authDomain: import.meta.env.VITE_FB_AUTH_DOMAIN,
  projectId: usingEmulator ? 'demo-safecheckboard' : import.meta.env.VITE_FB_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FB_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FB_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FB_APP_ID,
});

export const db = getFirestore(app);
export const auth = getAuth(app);

// 개발 중에는 로컬 에뮬레이터에 붙어서 실제 현장 데이터를 건드리지 않는다
if (usingEmulator) {
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
}

let signingIn: Promise<string> | null = null;
export function deviceUid(): Promise<string> {
  if (signingIn) return signingIn;
  signingIn = (async () => {
    await auth.authStateReady();
    if (auth.currentUser) return auth.currentUser.uid;
    return (await signInAnonymously(auth)).user.uid;
  })().catch((e) => {
    signingIn = null;
    if (e.code === 'auth/operation-not-allowed' || e.code === 'auth/admin-restricted-operation')
      throw new Error('Firebase Authentication에서 익명 로그인을 활성화해야 합니다.');
    throw e;
  });
  return signingIn;
}

/**
 * 다른 PC에서도 같은 개설자 권한을 쓰도록 Google 계정에 묶는다.
 * 익명으로 쓰던 기기는 그 계정에 Google을 연결해서 UID(=지금까지의 권한)를 그대로 유지한다.
 * 이미 다른 곳에서 쓰던 Google 계정이면 그 계정으로 전환한다 (이 기기의 익명 권한은 남지 않음).
 */
export async function googleLogin() {
  await auth.authStateReady();
  const provider = new GoogleAuthProvider();
  provider.setCustomParameters({ prompt: 'select_account' });
  const current = auth.currentUser;
  let user: User;
  if (current?.isAnonymous) {
    try {
      user = (await linkWithPopup(current, provider)).user;
    } catch (e) {
      const cred = (e as { code?: string }).code === 'auth/credential-already-in-use'
        ? GoogleAuthProvider.credentialFromError(e as FirebaseError)
        : null;
      if (!cred) throw e;
      user = (await signInWithCredential(auth, cred)).user;
    }
  } else {
    user = (await signInWithPopup(auth, provider)).user;
  }
  signingIn = null;
  return user;
}

/** 로그아웃하면 다음 접속 때 새 익명 기기로 시작한다 */
export async function logout() {
  await signOut(auth);
  signingIn = null;
}
