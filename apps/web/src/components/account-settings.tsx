'use client';

import {
  EmailAuthProvider,
  GoogleAuthProvider,
  linkWithCredential,
  linkWithPopup,
  reauthenticateWithCredential,
  reauthenticateWithPopup,
  reload,
  sendEmailVerification,
  signOut,
  unlink,
  updatePassword,
  verifyBeforeUpdateEmail,
  type User,
} from 'firebase/auth';
import { useEffect, useRef, useState } from 'react';
import { firebaseServices } from '@/lib/firebase';
import {
  inventory,
  publicationRequest,
  recoverAccountDeletion,
  type OperationResult,
} from '@/lib/publication';
import { Button, Field, Icon, LinkButton, Notice } from './ui';

export function linkedProviderIds(providers: readonly { providerId: string }[]): string[] {
  return [...new Set(providers.map((item) => item.providerId).filter(Boolean))];
}

export function canUnlinkProvider(
  providers: readonly { providerId: string }[],
  providerId: string,
): boolean {
  const ids = linkedProviderIds(providers);
  return ids.includes(providerId) && ids.length > 1;
}

export function accountErrorMessage(error: unknown): string {
  const code =
    typeof error === 'object' && error !== null && 'code' in error ? String(error.code) : '';
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
      return 'Не удалось подтвердить вход. Проверьте текущий пароль.';
    case 'auth/requires-recent-login':
    case 'auth/user-token-expired':
    case 'reauthentication-required':
      return 'Подтвердите вход ещё раз перед этим действием.';
    case 'auth/email-already-in-use':
    case 'auth/credential-already-in-use':
      return 'Этот способ входа уже используется другим аккаунтом.';
    case 'auth/provider-already-linked':
      return 'Этот способ входа уже подключён. Обновите список.';
    case 'auth/no-such-provider':
      return 'Способ входа уже отключён. Обновите список.';
    case 'auth/invalid-email':
      return 'Введите корректную почту.';
    case 'auth/weak-password':
    case 'auth/password-does-not-meet-requirements':
      return 'Пароль не соответствует требованиям Firebase. Выберите более надёжный пароль.';
    case 'auth/too-many-requests':
      return 'Слишком много попыток. Повторите позднее.';
    case 'auth/network-request-failed':
      return 'Нет подключения. Проверьте сеть и повторите.';
    case 'auth/popup-closed-by-user':
    case 'auth/cancelled-popup-request':
      return 'Подтверждение входа отменено.';
    case 'auth/popup-blocked':
      return 'Браузер заблокировал окно Google. Разрешите всплывающее окно и повторите.';
    case 'auth/operation-not-allowed':
    case 'auth/unauthorized-domain':
      return 'Этот способ входа недоступен в настройках Firebase.';
    case 'account/last-provider':
      return 'Нельзя отключить последний способ входа. Сначала подключите другой.';
    case 'account/password-required':
      return 'Введите текущий пароль для подтверждения входа.';
    case 'account/unsupported-provider':
      return 'Повторный вход через этот провайдер здесь недоступен.';
    case 'account/storage':
      return 'Не удалось сохранить запрос удаления на этом устройстве. Удаление не начато.';
    case 'account/journal-invalid':
      return 'Локальная запись удаления повреждена. Новый запрос не создан; требуется восстановление записи.';
    case 'account/stale-owner':
      return 'Аккаунт изменился. Действие остановлено.';
    case 'account/invalid-response':
      return 'Сервис не подтвердил результат удаления. Проверьте статус перед повтором.';
    default:
      return 'Не удалось выполнить действие. Проверьте подключение и настройки сервиса, затем повторите.';
  }
}

function accountFailure(code: string): Error & { code: string } {
  return Object.assign(new Error(code), { code });
}

export type AccountDeletionJournal = {
  version: 1;
  uid: string;
  operationId: string;
  expectedGeneration: number;
  recoveryKey: string;
};
type JournalStorage = Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>;
type DeletionReceiptRequest = {
  ownerUid: string;
  operationId: string;
  recoveryKey: string;
  retry?: boolean;
};
type DeletionGateway = (request: DeletionReceiptRequest) => Promise<OperationResult>;
const deletionPrefix = 'stackcard.delete-account.';
export const deletionJournalKey = (uid: string): string => deletionPrefix + encodeURIComponent(uid);

export function parseDeletionJournal(raw: string, uid: string): AccountDeletionJournal {
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    throw accountFailure('account/journal-invalid');
  }
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw accountFailure('account/journal-invalid');
  const item = value as Record<string, unknown>;
  if (
    Object.keys(item).length !== 5 ||
    item.version !== 1 ||
    item.uid !== uid ||
    typeof item.operationId !== 'string' ||
    !/^[a-zA-Z0-9_-]{1,200}$/.test(item.operationId) ||
    !Number.isSafeInteger(item.expectedGeneration) ||
    (item.expectedGeneration as number) < 0 ||
    typeof item.recoveryKey !== 'string' ||
    !/^[0-9a-f]{64}$/.test(item.recoveryKey)
  ) {
    throw accountFailure('account/journal-invalid');
  }
  return item as AccountDeletionJournal;
}

export function readDeletionJournal(
  storage: JournalStorage,
  uid: string,
): AccountDeletionJournal | null {
  const raw = storage.getItem(deletionJournalKey(uid));
  return raw === null ? null : parseDeletionJournal(raw, uid);
}

export function persistDeletionJournal(
  storage: JournalStorage,
  journal: AccountDeletionJournal,
): void {
  const key = deletionJournalKey(journal.uid);
  parseDeletionJournal(JSON.stringify(journal), journal.uid);
  const existing = readDeletionJournal(storage, journal.uid);
  if (existing && JSON.stringify(existing) !== JSON.stringify(journal))
    throw accountFailure('account/journal-invalid');
  const raw = JSON.stringify(journal);
  try {
    storage.setItem(key, raw);
    if (storage.getItem(key) !== raw) throw accountFailure('account/storage');
  } catch {
    throw accountFailure('account/storage');
  }
}

export function clearDeletionJournal(
  storage: JournalStorage,
  journal: AccountDeletionJournal,
): void {
  const current = readDeletionJournal(storage, journal.uid);
  if (current?.operationId === journal.operationId && current.recoveryKey === journal.recoveryKey) {
    storage.removeItem(deletionJournalKey(journal.uid));
  }
}

function checkedDeletionResult(
  value: OperationResult,
  journal: AccountDeletionJournal,
): OperationResult {
  if (
    !value ||
    value.operationId !== journal.operationId ||
    !['completed', 'pending', 'unknown'].includes(value.status) ||
    (value.status !== 'unknown' &&
      (value.action !== 'deleteAccount' ||
        !Number.isSafeInteger(value.lifecycleGeneration) ||
        value.lifecycleGeneration! <= journal.expectedGeneration))
  ) {
    throw accountFailure('account/invalid-response');
  }
  return value;
}

// Проверка receipt предшествует повтору; unknown требует прежнего авторизованного запроса.
export async function continueAccountDeletion(
  journal: AccountDeletionJournal,
  gateway: DeletionGateway,
  options: {
    retry?: boolean;
    create?: () => Promise<OperationResult>;
    assertActive?: () => void;
  } = {},
): Promise<OperationResult> {
  const guard = options.assertActive ?? (() => {});
  const receipt = {
    ownerUid: journal.uid,
    operationId: journal.operationId,
    recoveryKey: journal.recoveryKey,
  };
  guard();
  const status = checkedDeletionResult(await gateway(receipt), journal);
  guard();
  if (!options.retry || status.status === 'completed') return status;
  if (status.status === 'unknown') {
    if (!options.create) return status;
    const created = checkedDeletionResult(await options.create(), journal);
    guard();
    return created;
  }
  const result = checkedDeletionResult(await gateway({ ...receipt, retry: true }), journal);
  guard();
  return result;
}

function recoveryKey(): string {
  return [...crypto.getRandomValues(new Uint8Array(32))]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export function AccountSettings({ user, onSignedOut }: { user: User; onSignedOut?: () => void }) {
  return <AccountSettingsForUser key={user.uid} user={user} onSignedOut={onSignedOut} />;
}

function AccountSettingsForUser({ user, onSignedOut }: { user: User; onSignedOut?: () => void }) {
  const active = useRef(true),
    running = useRef(false);
  const [providers, setProviders] = useState(() => linkedProviderIds(user.providerData));
  const [email, setEmail] = useState(user.email ?? ''),
    [verified, setVerified] = useState(user.emailVerified);
  const [newEmail, setNewEmail] = useState(''),
    [currentPassword, setCurrentPassword] = useState('');
  const [password, setPassword] = useState(''),
    [confirmation, setConfirmation] = useState('');
  const [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [message, setMessage] = useState('');
  const [deletion, setDeletion] = useState<AccountDeletionJournal | null>(null);
  const [deletionStatus, setDeletionStatus] = useState<'pending' | 'unknown' | null>(null);
  const [deleteConfirmation, setDeleteConfirmation] = useState('');
  const [theme, setTheme] = useState<'dark' | 'light'>('dark');
  const [reduceMotion, setReduceMotion] = useState(false),
    [systemReduced, setSystemReduced] = useState(false);

  useEffect(() => {
    active.current = true;
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    const updateMotion = () => setSystemReduced(media.matches);
    updateMotion();
    media.addEventListener('change', updateMotion);
    try {
      setDeletion(readDeletionJournal(localStorage, user.uid));
      setTheme(localStorage.getItem('stackcard.theme') === 'light' ? 'light' : 'dark');
      setReduceMotion(localStorage.getItem('stackcard.reducedMotion') === 'true');
    } catch (failure) {
      setError(accountErrorMessage(failure));
    }
    return () => {
      active.current = false;
      media.removeEventListener('change', updateMotion);
    };
  }, [user.uid]);

  function assertActive() {
    if (!active.current || firebaseServices().auth.currentUser?.uid !== user.uid)
      throw accountFailure('account/stale-owner');
  }
  async function refreshAccount() {
    await reload(user);
    assertActive();
    setProviders(linkedProviderIds(user.providerData));
    setEmail(user.email ?? '');
    setVerified(user.emailVerified);
  }
  async function reauthenticate() {
    assertActive();
    const ids = linkedProviderIds(user.providerData);
    if (ids.includes('password') && user.email && currentPassword) {
      await reauthenticateWithCredential(
        user,
        EmailAuthProvider.credential(user.email, currentPassword),
      );
    } else if (ids.includes('google.com')) {
      await reauthenticateWithPopup(user, new GoogleAuthProvider());
    } else if (ids.includes('password')) {
      throw accountFailure('account/password-required');
    } else throw accountFailure('account/unsupported-provider');
    assertActive();
  }
  async function run(task: () => Promise<void>) {
    if (running.current) return;
    running.current = true;
    setBusy(true);
    setError('');
    setMessage('');
    try {
      assertActive();
      await task();
    } catch (failure) {
      if (active.current) setError(accountErrorMessage(failure));
    } finally {
      running.current = false;
      if (active.current) {
        setBusy(false);
        setCurrentPassword('');
        setPassword('');
        setConfirmation('');
      }
    }
  }
  async function finishDeletion(journal: AccountDeletionJournal, result: OperationResult) {
    assertActive();
    if (result.status !== 'completed') {
      setDeletionStatus(result.status);
      setMessage(
        result.status === 'pending'
          ? 'Удаление ещё выполняется. Сохранён тот же запрос для продолжения.'
          : 'Результат удаления не подтверждён. Сохранён прежний запрос; проверьте статус.',
      );
      return;
    }
    clearDeletionJournal(localStorage, journal);
    setMessage('Сервис подтвердил удаление аккаунта и снятие документов с публикации.');
    await signOut(firebaseServices().auth);
    if (active.current) onSignedOut?.();
  }
  function deletionRequest(journal: AccountDeletionJournal) {
    assertActive();
    return publicationRequest<OperationResult>(user, {
      action: 'deleteAccount',
      operationId: journal.operationId,
      expectedGeneration: journal.expectedGeneration,
      recoveryKey: journal.recoveryKey,
    });
  }
  async function deleteAccount() {
    if (deleteConfirmation !== 'УДАЛИТЬ') {
      setError('Введите УДАЛИТЬ для подтверждения.');
      return;
    }
    await run(async () => {
      await reauthenticate();
      const existing = readDeletionJournal(localStorage, user.uid);
      if (existing) {
        setDeletion(existing);
        const result = await continueAccountDeletion(existing, recoverAccountDeletion, {
          retry: true,
          create: () => deletionRequest(existing),
          assertActive,
        });
        await finishDeletion(existing, result);
        return;
      }
      const current = await inventory(user);
      assertActive();
      if (!Number.isSafeInteger(current.lifecycleGeneration) || current.lifecycleGeneration < 0)
        throw accountFailure('account/invalid-response');
      const journal: AccountDeletionJournal = {
        version: 1,
        uid: user.uid,
        operationId: crypto.randomUUID(),
        expectedGeneration: current.lifecycleGeneration,
        recoveryKey: recoveryKey(),
      };
      persistDeletionJournal(localStorage, journal);
      setDeletion(journal);
      assertActive();
      await finishDeletion(journal, checkedDeletionResult(await deletionRequest(journal), journal));
    });
  }
  function preference(kind: 'theme' | 'motion', value: string) {
    if (kind === 'theme') {
      setTheme(value === 'light' ? 'light' : 'dark');
      document.documentElement.dataset.theme = value;
    } else {
      setReduceMotion(value === 'true');
      document.documentElement.dataset.reducedMotion = value;
    }
    try {
      localStorage.setItem(kind === 'theme' ? 'stackcard.theme' : 'stackcard.reducedMotion', value);
    } catch {
      setError('Выбор применён, но не сохранён в браузере.');
    }
  }
  const passwordLinked = providers.includes('password');
  return (
    <div className="stack">
      <h2>Аккаунт</h2>
      {error && <Notice error>{error}</Notice>}
      {message && <Notice>{message}</Notice>}
      <section className="section stack" aria-labelledby="account-login">
        <h3 id="account-login">Вход в аккаунт</h3>
        <div className="list-row">
          <Icon name="user-round" />
          <div>
            <p>Почта для входа</p>
            <small className="muted">{email || 'Не указана'}</small>
          </div>
        </div>
        <p className="muted">
          {verified ? 'Адрес подтверждён.' : 'Адрес ещё не подтверждён.'} Эта почта не публикуется в
          документах.
        </p>
        <div className="row">
          {!verified && email && (
            <Button
              variant="secondary"
              disabled={busy || !!deletion}
              onClick={() =>
                void run(async () => {
                  await sendEmailVerification(user);
                  assertActive();
                  setMessage('Письмо отправлено. Подтвердите адрес и обновите статус.');
                })
              }
            >
              Подтвердить почту
            </Button>
          )}
          <Button variant="quiet" disabled={busy} onClick={() => void run(refreshAccount)}>
            Обновить статус
          </Button>
        </div>
        <Field
          label="Текущий пароль для подтверждения действий"
          type="password"
          autoComplete="current-password"
          value={currentPassword}
          maxLength={128}
          disabled={busy || !passwordLinked}
          onChange={(e) => setCurrentPassword(e.target.value)}
          helper={
            passwordLinked
              ? 'Пароль хранится только в этой форме и очищается после действия.'
              : 'Для подтверждения откроется Google.'
          }
        />
        <details className="editor-section">
          <summary className="row">
            <Icon name="user-round" />
            <span>Изменить почту для входа</span>
            <Icon name="chevron-down" />
          </summary>
          <form
            className="stack"
            onSubmit={(e) => {
              e.preventDefault();
              void run(async () => {
                await reauthenticate();
                await verifyBeforeUpdateEmail(user, newEmail.trim());
                assertActive();
                setNewEmail('');
                setMessage(
                  'Письмо отправлено на новый адрес. Почта для входа изменится после подтверждения.',
                );
              });
            }}
          >
            <Field
              label="Новая почта для входа"
              type="email"
              required
              autoComplete="email"
              maxLength={254}
              value={newEmail}
              disabled={busy || !!deletion}
              onChange={(e) => setNewEmail(e.target.value)}
            />
            <Button type="submit" disabled={busy || !!deletion}>
              Отправить подтверждение
            </Button>
          </form>
        </details>
        <details className="editor-section">
          <summary className="row">
            <Icon name="user-round" />
            <span>{passwordLinked ? 'Изменить пароль' : 'Подключить вход по паролю'}</span>
            <Icon name="chevron-down" />
          </summary>
          <form
            className="stack"
            onSubmit={(e) => {
              e.preventDefault();
              if (password.length < 8 || password !== confirmation) {
                setError(
                  'Пароль должен содержать минимум 8 символов; подтверждение должно совпадать.',
                );
                return;
              }
              void run(async () => {
                await reauthenticate();
                if (passwordLinked) await updatePassword(user, password);
                else {
                  if (!user.email) throw accountFailure('auth/invalid-email');
                  await linkWithCredential(
                    user,
                    EmailAuthProvider.credential(user.email, password),
                  );
                }
                assertActive();
                await refreshAccount();
                setMessage(passwordLinked ? 'Пароль изменён.' : 'Вход по паролю подключён.');
              });
            }}
          >
            <Field
              label="Новый пароль"
              type="password"
              required
              minLength={8}
              maxLength={128}
              autoComplete="new-password"
              value={password}
              disabled={busy || !!deletion}
              onChange={(e) => setPassword(e.target.value)}
            />
            <Field
              label="Подтверждение нового пароля"
              type="password"
              required
              maxLength={128}
              autoComplete="new-password"
              value={confirmation}
              disabled={busy || !!deletion}
              onChange={(e) => setConfirmation(e.target.value)}
            />
            <Button type="submit" disabled={busy || !!deletion || (!passwordLinked && !email)}>
              Сохранить пароль
            </Button>
          </form>
        </details>
      </section>
      <section className="section stack" aria-labelledby="account-providers">
        <h3 id="account-providers">Способы входа</h3>
        {providers.map((id) => (
          <div className="list-row" key={id}>
            <Icon name="user-round" />
            <div>
              <p>{id === 'password' ? 'Почта и пароль' : id === 'google.com' ? 'Google' : id}</p>
              <small className="muted">Подключено</small>
            </div>
            <Button
              variant="quiet"
              disabled={busy || !!deletion || !canUnlinkProvider(user.providerData, id)}
              onClick={() => {
                if (!window.confirm('Отключить этот способ входа?')) return;
                void run(async () => {
                  await reauthenticate();
                  await reload(user);
                  assertActive();
                  if (!canUnlinkProvider(user.providerData, id))
                    throw accountFailure('account/last-provider');
                  await unlink(user, id);
                  assertActive();
                  await refreshAccount();
                  setMessage('Способ входа отключён.');
                });
              }}
            >
              Отключить
            </Button>
          </div>
        ))}
        {providers.length <= 1 && <p className="muted">Последний способ входа нельзя отключить.</p>}
        {!providers.includes('google.com') && (
          <Button
            variant="secondary"
            disabled={busy || !!deletion}
            onClick={() =>
              void run(async () => {
                await linkWithPopup(user, new GoogleAuthProvider());
                assertActive();
                await refreshAccount();
                setMessage('Google подключён к этому аккаунту.');
              })
            }
          >
            Подключить Google
          </Button>
        )}
      </section>
      <section className="section stack" aria-labelledby="app-preferences">
        <h3 id="app-preferences">Приложение</h3>
        <label className="field">
          <span>Тема</span>
          <select value={theme} onChange={(e) => preference('theme', e.target.value)}>
            <option value="dark">Тёмная</option>
            <option value="light">Светлая</option>
          </select>
        </label>
        <label className="list-row">
          <span>Сократить анимации</span>
          <input
            type="checkbox"
            checked={reduceMotion || systemReduced}
            disabled={systemReduced}
            onChange={(e) => preference('motion', String(e.target.checked))}
          />
        </label>
        {systemReduced && <p className="muted">Анимации сокращены по настройке системы.</p>}
        <p className="muted">Уведомления и Inbox пока недоступны.</p>
      </section>
      <section className="section stack" aria-labelledby="account-session">
        <h3 id="account-session">Сеанс</h3>
        <Button
          variant="quiet"
          disabled={busy}
          onClick={() =>
            void run(async () => {
              await signOut(firebaseServices().auth);
              if (active.current) onSignedOut?.();
            })
          }
        >
          Выйти из аккаунта
        </Button>
      </section>
      <section className="section stack" aria-labelledby="account-delete">
        <h3 id="account-delete">Удаление аккаунта</h3>
        <p>
          Удаление навсегда уберёт данные аккаунта и закроет доступ к опубликованным документам.
        </p>
        {deletion && (
          <>
            <Notice>
              Запрос удаления сохранён.{' '}
              {deletionStatus === 'pending'
                ? 'Очистка ещё выполняется.'
                : 'Новый запрос не создаётся до проверки прежнего.'}
            </Notice>
            <Button
              variant="secondary"
              disabled={busy}
              onClick={() =>
                void run(async () => {
                  const result = await continueAccountDeletion(deletion, recoverAccountDeletion, {
                    assertActive,
                  });
                  await finishDeletion(deletion, result);
                })
              }
            >
              Проверить статус удаления
            </Button>
            <LinkButton href="/account-deletion">Восстановить удаление после выхода</LinkButton>
          </>
        )}
        <form
          className="stack"
          onSubmit={(e) => {
            e.preventDefault();
            void deleteAccount();
          }}
        >
          <Field
            label="Введите УДАЛИТЬ для подтверждения"
            value={deleteConfirmation}
            autoComplete="off"
            disabled={busy}
            onChange={(e) => setDeleteConfirmation(e.target.value)}
          />
          <Button
            variant="danger"
            type="submit"
            disabled={busy || deleteConfirmation !== 'УДАЛИТЬ'}
          >
            {busy ? 'Выполняем…' : deletion ? 'Продолжить удаление' : 'Удалить аккаунт'}
          </Button>
        </form>
      </section>
    </div>
  );
}

export function AccountDeletionRecovery() {
  const [journals, setJournals] = useState<AccountDeletionJournal[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(''),
    [message, setMessage] = useState(''),
    [busy, setBusy] = useState(false);
  const active = useRef(true),
    running = useRef(false);
  useEffect(() => {
    active.current = true;
    try {
      const found: AccountDeletionJournal[] = [];
      for (let index = 0; index < localStorage.length; index++) {
        const key = localStorage.key(index);
        if (!key?.startsWith(deletionPrefix)) continue;
        const uid = decodeURIComponent(key.slice(deletionPrefix.length));
        const journal = readDeletionJournal(localStorage, uid);
        if (journal) found.push(journal);
      }
      setJournals(found);
    } catch (failure) {
      setError(accountErrorMessage(failure));
    } finally {
      setLoading(false);
    }
    return () => {
      active.current = false;
    };
  }, []);
  async function check(journal: AccountDeletionJournal, retry: boolean) {
    if (running.current) return;
    running.current = true;
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const result = await continueAccountDeletion(journal, recoverAccountDeletion, {
        retry,
        assertActive: () => {
          if (!active.current) throw accountFailure('account/stale-owner');
        },
      });
      if (result.status === 'completed') {
        clearDeletionJournal(localStorage, journal);
        setJournals((current) =>
          current.filter(
            (item) => item.operationId !== journal.operationId || item.uid !== journal.uid,
          ),
        );
        setMessage('Сервис подтвердил удаление аккаунта и снятие документов с публикации.');
      } else
        setMessage(
          result.status === 'pending'
            ? 'Удаление ещё выполняется. Можно продолжить тот же запрос.'
            : 'Сервис ещё не подтвердил начало удаления. Войдите в тот же аккаунт для повтора сохранённого запроса.',
        );
    } catch (failure) {
      if (active.current) setError(accountErrorMessage(failure));
    } finally {
      running.current = false;
      if (active.current) setBusy(false);
    }
  }
  return (
    <div className="stack">
      <h1>Статус удаления аккаунта</h1>
      <p>
        Здесь можно проверить ранее подтверждённое удаление с этого браузера. Вход и создание нового
        запроса не выполняются автоматически.
      </p>
      {error && <Notice error>{error}</Notice>}
      {message && <Notice>{message}</Notice>}
      {journals.map((journal, index) => (
        <section className="section stack" key={journal.uid + journal.operationId}>
          <h2>Сохранённый запрос {index + 1}</h2>
          <div className="row">
            <Button variant="secondary" disabled={busy} onClick={() => void check(journal, false)}>
              Проверить статус
            </Button>
            <Button
              variant="danger"
              disabled={busy}
              onClick={() => {
                if (window.confirm('Продолжить ранее подтверждённое удаление?'))
                  void check(journal, true);
              }}
            >
              Продолжить удаление
            </Button>
          </div>
        </section>
      ))}
      {loading && <Notice>Проверяем сохранённые запросы…</Notice>}
      {!loading && !journals.length && !error && (
        <Notice>В этом браузере нет сохранённого запроса удаления.</Notice>
      )}
      <LinkButton href="/sign-in">Перейти ко входу</LinkButton>
    </div>
  );
}
