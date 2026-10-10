'use client';
import {
  getLimitedUseToken,
  initializeAppCheck,
  ReCaptchaEnterpriseProvider,
  type AppCheck,
} from 'firebase/app-check';
import type { User } from 'firebase/auth';
import {
  collection,
  doc,
  documentId,
  getDocFromServer,
  getDocsFromServer,
  limit,
  orderBy,
  query,
  serverTimestamp,
  startAfter,
  runTransaction,
  type QueryDocumentSnapshot,
} from 'firebase/firestore';
import { firebaseConfig, firebaseServices } from './firebase';
import {
  ContactError,
  checkContactAccepted,
  parseContactRequest,
  type ContactSubmission,
} from './contact-contract';

let appCheck: AppCheck | undefined;
export function contactEndpoint(): string {
  const endpoint = process.env.NEXT_PUBLIC_CONTACT_INBOX_API_URL;
  if (!endpoint)
    throw new ContactError('Форма связи временно недоступна.', 'configuration-required');
  const url = new URL(endpoint);
  const demo =
    process.env.NEXT_PUBLIC_USE_EMULATORS === 'true' &&
    firebaseConfig().projectId?.startsWith('demo-');
  if (
    url.username ||
    url.password ||
    (url.protocol !== 'https:' &&
      !(demo && url.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(url.hostname)))
  )
    throw new ContactError('Форма связи временно недоступна.', 'configuration-required');
  return endpoint;
}
export function contactConfigured(): boolean {
  try {
    contactEndpoint();
    const config = firebaseConfig();
    return !!(
      config.apiKey &&
      config.authDomain &&
      config.projectId &&
      config.appId &&
      ((process.env.NEXT_PUBLIC_USE_EMULATORS === 'true' && config.projectId.startsWith('demo-')) ||
        process.env.NEXT_PUBLIC_APP_CHECK_SITE_KEY)
    );
  } catch {
    return false;
  }
}
export async function submitContact(submission: ContactSubmission): Promise<void> {
  const endpoint = contactEndpoint();
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const demo =
    process.env.NEXT_PUBLIC_USE_EMULATORS === 'true' &&
    firebaseConfig().projectId?.startsWith('demo-');
  if (!demo) {
    const siteKey = process.env.NEXT_PUBLIC_APP_CHECK_SITE_KEY;
    if (!siteKey)
      throw new ContactError('Форма связи временно недоступна.', 'configuration-required');
    appCheck ??= initializeAppCheck(firebaseServices().app, {
      provider: new ReCaptchaEnterpriseProvider(siteKey),
      isTokenAutoRefreshEnabled: false,
    });
    headers['X-Firebase-AppCheck'] = (await getLimitedUseToken(appCheck)).token;
  }
  const response = await fetch(endpoint, {
    method: 'POST',
    headers,
    body: JSON.stringify({ action: 'submit', ...submission }),
    cache: 'no-store',
    signal: AbortSignal.timeout(20000),
  });
  const result = await response.json();
  if (!response.ok) {
    const code = typeof result.error?.code === 'string' ? result.error.code : 'unavailable';
    const messages: Record<string, string> = {
      'invalid-data': 'Проверьте имя, почту и сообщение.',
      'rate-limited': 'Лимит обращений достигнут. Попробуйте позднее.',
      'document-unavailable': 'Документ больше не принимает обращения.',
      'contact-unavailable': 'Документ больше не принимает обращения.',
      'not-found': 'Документ больше не принимает обращения.',
      'app-check-required': 'Не удалось проверить отправку. Попробуйте ещё раз.',
      'configuration-required': 'Форма связи временно недоступна.',
      conflict: 'Изменился результат отправки. Повторите прежнюю попытку.',
    };
    throw new ContactError(
      messages[code] ?? 'Ответ не подтверждён. Повторите отправку с этой страницы.',
      code,
    );
  }
  checkContactAccepted(result, submission.requestId);
}
function owner(user: User) {
  const services = firebaseServices();
  if (services.auth.currentUser?.uid !== user.uid)
    throw new ContactError('Аккаунт изменился.', 'owner-changed');
  return collection(services.firestore, 'accounts', user.uid, 'contactRequests');
}
export async function loadInbox(user: User, after?: QueryDocumentSnapshot) {
  const base = [orderBy('createdAt', 'desc'), orderBy(documentId(), 'desc'), limit(50)];
  const snapshot = await getDocsFromServer(
    query(owner(user), ...base, ...(after ? [startAfter(after)] : [])),
  );
  owner(user);
  const requests = snapshot.docs.map((d) => parseContactRequest(d.data(), d.id));
  return { requests, cursor: snapshot.docs.at(-1), hasMore: snapshot.size === 50 };
}
export async function loadContactRequest(user: User, requestId: string) {
  if (!/^[a-f0-9]{32}$/.test(requestId)) throw new ContactError('Обращение не найдено.');
  const snapshot = await getDocFromServer(doc(owner(user), requestId));
  owner(user);
  return snapshot.exists() ? parseContactRequest(snapshot.data(), snapshot.id) : null;
}
export async function markContactRead(user: User, requestId: string) {
  if (!/^[a-f0-9]{32}$/.test(requestId)) throw new ContactError('Обращение не найдено.');
  const reference = doc(owner(user), requestId);
  await runTransaction(firebaseServices().firestore, async (transaction) => {
    owner(user);
    const snapshot = await transaction.get(reference);
    owner(user);
    if (!snapshot.exists()) throw new ContactError('Обращение не найдено.');
    const request = parseContactRequest(snapshot.data(), snapshot.id);
    if (!request.readAt) transaction.update(reference, { readAt: serverTimestamp() });
  });
  return loadContactRequest(user, requestId);
}
