'use client';
import {
  createUserWithEmailAndPassword,
  GoogleAuthProvider,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
} from 'firebase/auth';
import { useRouter, useSearchParams } from 'next/navigation';
import { useEffect, useState } from 'react';
import { firebaseServices } from '@/lib/firebase';
import { safeReturnPath } from '@/lib/model';
import { useSession } from './auth-session';
import { Button, Field, Header, LinkButton, Notice } from './ui';
export function AuthForm({ mode }: { mode: 'login' | 'register' | 'reset' }) {
  const router = useRouter(),
    params = useSearchParams();
  const destination = safeReturnPath(params.get('returnTo'));
  const session = useSession();
  const [email, setEmail] = useState(''),
    [password, setPassword] = useState(''),
    [confirmation, setConfirmation] = useState(''),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [accepted, setAccepted] = useState(false);
  useEffect(() => {
    if (session.user && mode !== 'reset') router.replace(destination);
  }, [session.user, mode, router, destination]);
  async function submit(google = false) {
    setError('');
    if (!google && mode === 'register' && (password.length < 8 || password !== confirmation)) {
      setError('Пароль должен содержать не меньше 8 символов. Подтверждение должно совпадать.');
      return;
    }
    setBusy(true);
    try {
      const { auth } = firebaseServices();
      if (google) await signInWithPopup(auth, new GoogleAuthProvider());
      else if (mode === 'reset') {
        await sendPasswordResetEmail(auth, email);
        setAccepted(true);
        return;
      } else if (mode === 'register') await createUserWithEmailAndPassword(auth, email, password);
      else await signInWithEmailAndPassword(auth, email, password);
      router.replace(destination);
    } catch (e) {
      const code = (e as { code?: string }).code;
      if (
        mode === 'reset' &&
        ['auth/user-not-found', 'auth/invalid-credential'].includes(code ?? '')
      )
        setAccepted(true);
      else
        setError(
          code === 'auth/popup-closed-by-user'
            ? 'Вход отменён.'
            : code === 'auth/too-many-requests'
              ? 'Слишком много попыток. Попробуйте позднее.'
              : code === 'auth/network-request-failed'
                ? 'Нет подключения. Проверьте сеть и повторите.'
                : 'Не удалось выполнить действие. Проверьте данные и повторите попытку.',
        );
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      <Header context="auth" />
      <main id="main" className="auth-container stack">
        <h1>
          {accepted
            ? 'Проверьте почту'
            : mode === 'login'
              ? 'Войти в StackCard'
              : mode === 'register'
                ? 'Создать аккаунт'
                : 'Восстановить пароль'}
        </h1>
        {session.loading && <Notice>Проверяем вход…</Notice>}
        {session.error && <Notice error>{session.error}</Notice>}
        {accepted ? (
          <>
            <p>
              Если аккаунт с этой почтой существует, вы получите письмо для восстановления пароля.
            </p>
            <LinkButton href="/sign-in">Вернуться ко входу</LinkButton>
          </>
        ) : (
          <form
            className="stack"
            onSubmit={(e) => {
              e.preventDefault();
              void submit();
            }}
          >
            <Field
              label="Почта"
              type="email"
              required
              autoComplete="email"
              value={email}
              maxLength={254}
              onChange={(e) => setEmail(e.target.value)}
              helper="Почта для входа. Публичные контакты настраиваются отдельно."
            />
            {mode !== 'reset' && (
              <Field
                label="Пароль"
                type="password"
                required
                autoComplete={mode === 'register' ? 'new-password' : 'current-password'}
                minLength={mode === 'register' ? 8 : undefined}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            )}{' '}
            {mode === 'register' && (
              <Field
                label="Подтверждение пароля"
                type="password"
                required
                autoComplete="new-password"
                value={confirmation}
                onChange={(e) => setConfirmation(e.target.value)}
              />
            )}
            {error && <Notice error>{error}</Notice>}
            {mode === 'login' && (
              <LinkButton variant="quiet" href="/reset-password">
                Забыли пароль?
              </LinkButton>
            )}
            {mode !== 'reset' && (
              <>
                <p className="muted">или</p>
                <Button
                  variant="secondary"
                  onClick={() => void submit(true)}
                  disabled={busy || session.loading || !!session.error}
                >
                  Продолжить с Google
                </Button>
                <LinkButton variant="quiet" href={mode === 'login' ? '/sign-up' : '/sign-in'}>
                  {mode === 'login' ? 'Создать аккаунт' : 'Уже есть аккаунт? Войти'}
                </LinkButton>
              </>
            )}
            <p className="muted">Публичные резюме и портфолио можно читать без входа.</p>
            {mode === 'login' && (
              <LinkButton variant="quiet" href="/account-deletion">
                Проверить начатое удаление аккаунта
              </LinkButton>
            )}
            <div className="row">
              <LinkButton href="/">Отмена</LinkButton>
              <Button type="submit" disabled={busy || session.loading || !!session.error}>
                {busy
                  ? 'Выполняем…'
                  : mode === 'login'
                    ? 'Войти'
                    : mode === 'register'
                      ? 'Создать аккаунт'
                      : 'Отправить письмо'}
              </Button>
            </div>
          </form>
        )}
      </main>
    </>
  );
}
