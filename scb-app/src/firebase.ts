import { initializeApp } from 'firebase/app';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';
import { connectAuthEmulator, getAuth, GoogleAuthProvider, signInAnonymously, signInWithPopup } from 'firebase/auth';

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

/** Keep the same owner identity when signing in from another PC. */
export async function googleLogin() {
  await auth.authStateReady();
  const provider = new GoogleAuthProvider();
  provider.setCustomParameters({ prompt: 'select_account' });
  const result = await signInWithPopup(auth, provider);
  signingIn = null;
  return result.user;
}
