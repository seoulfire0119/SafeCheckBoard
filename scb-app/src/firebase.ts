import { initializeApp } from 'firebase/app';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';

const app = initializeApp({
  apiKey: import.meta.env.VITE_FB_API_KEY,
  authDomain: import.meta.env.VITE_FB_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FB_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FB_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FB_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FB_APP_ID,
});

export const db = getFirestore(app);

// 개발 중에는 로컬 에뮬레이터에 붙어서 실제 현장 데이터를 건드리지 않는다
export const usingEmulator = import.meta.env.VITE_USE_EMULATOR === '1';
if (usingEmulator) connectFirestoreEmulator(db, '127.0.0.1', 8080);
