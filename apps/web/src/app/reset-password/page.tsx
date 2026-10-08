import { Suspense } from 'react';
import { AuthForm } from '@/components/auth-form';
export const metadata = {
  title: 'Восстановить пароль',
  robots: { index: false, follow: false },
};
export default function Reset() {
  return (
    <Suspense fallback={<p>Загрузка…</p>}>
      <AuthForm mode="reset" />
    </Suspense>
  );
}
