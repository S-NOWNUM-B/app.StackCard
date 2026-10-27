// Чистые правила кабинета: перевод ошибок, hash, подтверждения и ACK Save.
import type { DraftEnvelope } from './model';

const fallbackMessage = 'Действие не завершено. Повторите попытку';
const offlineMessage = 'Нет подключения к сети. Проверьте соединение и повторите попытку';
const timeoutMessage = 'Сервер не ответил вовремя. Проверьте соединение и повторите попытку';

const codeMessages: Record<string, string> = {
  unavailable: offlineMessage,
  'network-request-failed': offlineMessage,
  'deadline-exceeded': timeoutMessage,
  'permission-denied': 'Нет доступа к этим данным. Войдите снова и повторите попытку',
  unauthenticated: 'Сессия завершилась. Войдите снова и повторите попытку',
  'user-token-expired': 'Сессия завершилась. Войдите снова и повторите попытку',
  'resource-exhausted': 'Превышен лимит запросов. Повторите попытку позднее',
  'too-many-requests': 'Превышен лимит запросов. Повторите попытку позднее',
  aborted: 'Сервер прервал операцию. Повторите попытку',
  cancelled: 'Операция отменена. Повторите попытку',
  'quota-exceeded': 'Превышен лимит хранилища. Повторите попытку позднее',
};

// Свои ошибки приложения уже на русском; технические сообщения SDK/браузера не показываем.
export function userErrorMessage(error: unknown, fallback = fallbackMessage): string {
  if (typeof error !== 'object' || error === null) return fallback;
  if (error instanceof Error && /[а-яё]/i.test(error.message)) return error.message;
  const code =
    'code' in error && typeof error.code === 'string' ? error.code.split('/').at(-1)! : '';
  if (codeMessages[code]) return codeMessages[code];
  if (!(error instanceof Error)) return fallback;
  if (error.name === 'TimeoutError') return timeoutMessage;
  if (/client is offline/i.test(error.message)) return offlineMessage;
  if (error instanceof TypeError && /fetch|network|load failed/i.test(error.message))
    return offlineMessage;
  return fallback;
}

// Склеивает предложения UI: внутри — с точкой, в конце точки нет.
export function joinMessages(...parts: string[]): string {
  const items = parts.map((part) => part.trim()).filter(Boolean);
  return items
    .map((part, index) =>
      index === items.length - 1
        ? part.replace(/\.$/, '')
        : /[.!?…]$/.test(part)
          ? part
          : `${part}.`,
    )
    .join(' ');
}

// Битый percent-encoding в hash не должен ломать кабинет.
export function decodeWorkspaceHash(hash: string): string {
  try {
    return decodeURIComponent(hash.replace(/^#/, ''));
  } catch {
    return '';
  }
}

// Фоновое обновление inventory не отменяет подтверждение: версии публикации
// проверяет сервер, а здесь важны owner state и цель действия.
export function sameConfirmationContext(
  captured: Record<string, unknown>,
  current: Record<string, unknown>,
  equal: (a: unknown, b: unknown) => boolean,
): boolean {
  const significant = (value: Record<string, unknown>) =>
    Object.fromEntries(Object.entries(value).filter(([key]) => key !== 'publications'));
  return equal(significant(captured), significant(current));
}

// Успешная transaction уже подтверждена; более новая серверная версия становится basis
export function acknowledgedDraft(
  saved: DraftEnvelope | null,
  mutationId: string,
): { draft: DraftEnvelope; superseded: boolean } {
  if (!saved?.content)
    throw new Error(
      'Сохранение подтверждено, но серверная версия недоступна. Загрузите её перед следующим Save',
    );
  return { draft: saved, superseded: saved.mutationId !== mutationId };
}
