import { Suspense } from 'react';
import { AuthForm } from '@/components/auth-form';
export const metadata = {
  title: 'Войти',
  robots: { index: false, follow: false },
};
export default function SignIn() {
  return (
    <Suspense fallback={<p>Проверяем вход…</p>}>
      <AuthForm mode="login" />
    </Suspense>
  );
}
