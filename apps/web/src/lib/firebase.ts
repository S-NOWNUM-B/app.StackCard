'use client';
import { getApps, initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth } from 'firebase/auth';
import {
  connectFirestoreEmulator,
  initializeFirestore,
  memoryLocalCache,
} from 'firebase/firestore';
import { connectStorageEmulator, getStorage } from 'firebase/storage';
export function firebaseConfig() {
  return {
    apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
    authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
    appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
    storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  };
}
let services: ReturnType<typeof initializeServices> | undefined;
function initializeServices() {
  const config = firebaseConfig();
  if (!config.apiKey || !config.authDomain || !config.projectId || !config.appId)
    throw new Error('Вход пока недоступен. Попробуйте позднее.');
  const app =
    getApps().find((a) => a.name === 'stackcard-web') ?? initializeApp(config, 'stackcard-web');
  const auth = getAuth(app);
  const firestore = initializeFirestore(app, {
    localCache: memoryLocalCache(),
  });
  const storage = getStorage(app);
  if (process.env.NEXT_PUBLIC_USE_EMULATORS === 'true') {
    if (!config.projectId.startsWith('demo-'))
      throw new Error('Эмуляторы разрешены только для demo Firebase проекта.');
    connectAuthEmulator(
      auth,
      process.env.NEXT_PUBLIC_AUTH_EMULATOR_URL ?? 'http://127.0.0.1:9099',
      { disableWarnings: true },
    );
    connectFirestoreEmulator(
      firestore,
      process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_HOST ?? '127.0.0.1',
      Number(process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_PORT ?? 8085),
    );
    connectStorageEmulator(
      storage,
      process.env.NEXT_PUBLIC_STORAGE_EMULATOR_HOST ?? '127.0.0.1',
      Number(process.env.NEXT_PUBLIC_STORAGE_EMULATOR_PORT ?? 9199),
    );
  }
  return { app, auth, firestore, storage };
}
export function firebaseServices() {
  if (typeof window === 'undefined')
    throw new Error('Private Firebase client доступен только в браузере.');
  return (services ??= initializeServices());
}
