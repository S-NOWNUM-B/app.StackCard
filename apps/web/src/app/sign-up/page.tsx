import { Suspense } from 'react';
import { AuthForm } from '@/components/auth-form';
export const metadata = {
  title: 'Создать аккаунт',
  robots: { index: false, follow: false },
};
export default function SignUp() {
  return (
    <Suspense fallback={<p>Проверяем вход…</p>}>
      <AuthForm mode="register" />
    </Suspense>
  );
}
