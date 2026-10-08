'use client';
import { onAuthStateChanged, type User } from 'firebase/auth';
import { useEffect, useState } from 'react';
import { firebaseServices } from '@/lib/firebase';
export function useSession() {
  const [session, setSession] = useState<{
    user: User | null;
    loading: boolean;
    error: string | null;
  }>({ user: null, loading: true, error: null });
  useEffect(() => {
    try {
      return onAuthStateChanged(
        firebaseServices().auth,
        (user) => setSession({ user, loading: false, error: null }),
        () =>
          setSession({
            user: null,
            loading: false,
            error: 'Не удалось восстановить вход. Перезагрузите страницу.',
          }),
      );
    } catch (error) {
      setSession({
        user: null,
        loading: false,
        error: error instanceof Error ? error.message : 'Ошибка настройки Firebase.',
      });
    }
  }, []);
  return session;
}
