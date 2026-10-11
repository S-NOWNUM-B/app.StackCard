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
import Link from 'next/link';
import { firebaseServices } from '@/lib/firebase';
import { safeReturnPath } from '@/lib/model';
import {
  registrationPasswordIssues,
  registrationPasswordMaximumLength,
  registrationPasswordMinimumLength,
} from '@/lib/registration-password';
import { useSession } from './auth-session';
import { Button, Field, Header, LinkButton, Notice } from './ui';
export function PasswordField({
  label,
  value,
  onChange,
  autoComplete,
  minLength,
  invalid = false,
  disabled = false,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  autoComplete: string;
  minLength?: number;
  invalid?: boolean;
  disabled?: boolean;
}) {
  const [visible, setVisible] = useState(false);
  const name = label === 'Подтверждение пароля' ? 'подтверждение пароля' : 'пароль';
  return (
    <div className="password-field">
      <Field
        label={label}
        type={visible ? 'text' : 'password'}
        required
        autoComplete={autoComplete}
        minLength={minLength}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        disabled={disabled}
        aria-invalid={invalid}
      />
      <Button
        variant="quiet"
        className="password-toggle"
        disabled={disabled}
        aria-label={`${visible ? 'Скрыть' : 'Показать'} ${name}`}
        aria-pressed={visible}
        onClick={() => setVisible(!visible)}
      >
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7S2 12 2 12Z" />
          <circle cx="12" cy="12" r="3" />
          {visible && <path d="m3 3 18 18" />}
        </svg>
      </Button>
    </div>
  );
}
export function AuthForm({ mode }: { mode: 'login' | 'register' | 'reset' }) {
  const router = useRouter(),
    params = useSearchParams();
  const destination = safeReturnPath(params.get('returnTo'));
  const returnQuery = `?returnTo=${encodeURIComponent(destination)}`;
  const session = useSession();
  const [email, setEmail] = useState(''),
    [password, setPassword] = useState(''),
    [confirmation, setConfirmation] = useState(''),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [accepted, setAccepted] = useState(false);
  const issues = registrationPasswordIssues(password, email),
    edited = password.length > 0;
  useEffect(() => {
    if (session.user && mode !== 'reset') router.replace(destination);
  }, [session.user, mode, router, destination]);
  async function submit(google = false) {
    setError('');
    if (!google && mode === 'register' && (issues.size || password !== confirmation)) {
      setError(
        issues.size
          ? 'Пароль не соответствует правилам ниже.'
          : 'Подтверждение пароля должно совпадать.',
      );
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
                : ['auth/weak-password', 'auth/password-does-not-meet-requirements'].includes(
                      code ?? '',
                    )
                  ? 'Пароль не соответствует требованиям сервиса. Выберите другой пароль.'
                  : 'Не удалось выполнить действие. Проверьте данные и повторите попытку.',
        );
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="auth-screen">
      <Header context="auth" links={[]} />
      <main id="main" className="auth-container auth-card stack">
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
            <LinkButton href={`/sign-in${returnQuery}`}>Вернуться ко входу</LinkButton>
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
            />
            {mode !== 'reset' && (
              <PasswordField
                label="Пароль"
                autoComplete={mode === 'register' ? 'new-password' : 'current-password'}
                minLength={mode === 'register' ? registrationPasswordMinimumLength : undefined}
                value={password}
                onChange={setPassword}
                disabled={busy}
                invalid={mode === 'register' && edited && issues.size > 0}
              />
            )}
            {mode === 'register' && (
              <>
                <ul className="password-rules" aria-label="Требования к паролю">
                  {[
                    {
                      passed: !issues.has('tooShort') && !issues.has('tooLong'),
                      label: `От ${registrationPasswordMinimumLength} до ${registrationPasswordMaximumLength} символов`,
                    },
                    {
                      passed: !issues.has('tooCommon'),
                      label: 'Без очевидного пароля и повторений',
                    },
                    {
                      passed: !issues.has('matchesEmail'),
                      label: 'Отличается от почты и её имени',
                    },
                  ].map((rule) => (
                    <li
                      key={rule.label}
                      className={edited && !rule.passed ? 'text-danger' : 'muted'}
                      aria-label={
                        edited
                          ? `${rule.label}: ${rule.passed ? 'выполнено' : 'не выполнено'}`
                          : rule.label
                      }
                    >
                      <span aria-hidden="true">{edited ? (rule.passed ? '✓' : '×') : '○'}</span>
                      <span>{rule.label}</span>
                    </li>
                  ))}
                </ul>
                <PasswordField
                  label="Подтверждение пароля"
                  autoComplete="new-password"
                  value={confirmation}
                  onChange={setConfirmation}
                  disabled={busy}
                  invalid={confirmation.length > 0 && password !== confirmation}
                />
                {confirmation.length > 0 && password !== confirmation && (
                  <Notice error>Пароли не совпадают.</Notice>
                )}
              </>
            )}
            {error && <Notice error>{error}</Notice>}
            {mode === 'login' && (
              <Link className="auth-forgot" href={`/reset-password${returnQuery}`}>
                Забыли пароль?
              </Link>
            )}
            <Button type="submit" disabled={busy || session.loading || !!session.error}>
              {busy
                ? 'Выполняем…'
                : mode === 'login'
                  ? 'Войти'
                  : mode === 'register'
                    ? 'Создать аккаунт'
                    : 'Отправить письмо'}
            </Button>
            {mode !== 'reset' && (
              <>
                <div className="auth-divider">
                  <span>или</span>
                </div>
                <Button
                  variant="secondary"
                  onClick={() => void submit(true)}
                  disabled={busy || session.loading || !!session.error}
                >
                  Продолжить с Google
                </Button>
                <p className="auth-switch muted">
                  {mode === 'login' ? 'Нет аккаунта? ' : 'Уже есть аккаунт? '}
                  <Link href={`${mode === 'login' ? '/sign-up' : '/sign-in'}${returnQuery}`}>
                    {mode === 'login' ? 'Зарегистрироваться' : 'Войти'}
                  </Link>
                </p>
              </>
            )}
            {mode === 'reset' && (
              <LinkButton variant="quiet" href={`/sign-in${returnQuery}`}>
                Вернуться ко входу
              </LinkButton>
            )}
          </form>
        )}
      </main>
    </div>
  );
}
