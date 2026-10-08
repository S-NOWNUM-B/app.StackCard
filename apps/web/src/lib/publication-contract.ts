// Квитанции операций содержат только metadata, не credentials и не private draft.
export type Publication = {
  documentId: string;
  publicId: string;
  version: number;
  state: 'published' | 'unpublished' | 'deleted';
  url: string | null;
  sourceMutationId: string;
};
export type Inventory = {
  status: 'completed';
  publications: Publication[];
  lifecycleGeneration: number;
};
export type OperationResult = {
  status: 'completed' | 'pending' | 'unknown';
  operationId: string;
  action?: string;
  publication?: Publication;
  lifecycleGeneration?: number;
};
export type PublicationMutation = {
  action: 'publish' | 'unpublish' | 'deleteDocument';
  documentId: string;
  operationId: string;
  expectedMutationId: string;
  expectedVersion: number;
  expectedGeneration: number;
};
const integer = (value: unknown): value is number =>
  Number.isSafeInteger(value) && (value as number) >= 0;
const identifier = (value: unknown): value is string =>
  typeof value === 'string' &&
  value.trim().length > 0 &&
  value.length <= 200 &&
  !/[\x00-\x1f/]/.test(value);
const object = (value: unknown): Record<string, unknown> => {
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw new Error('Некорректный ответ сервиса публикации.');
  return value as Record<string, unknown>;
};
function publication(value: unknown): Publication {
  const p = object(value);
  if (
    !identifier(p.documentId) ||
    typeof p.publicId !== 'string' ||
    !/^[a-f0-9]{32}$/.test(p.publicId) ||
    !integer(p.version) ||
    !['published', 'unpublished', 'deleted'].includes(p.state as string) ||
    typeof p.sourceMutationId !== 'string'
  )
    throw new Error('Некорректная публикация в ответе сервиса.');
  if (p.state === 'published') {
    let url: URL;
    try {
      url = new URL(p.url as string);
    } catch {
      throw new Error('Некорректный публичный адрес.');
    }
    if (
      !['http:', 'https:'].includes(url.protocol) ||
      url.username ||
      url.password ||
      url.search ||
      url.hash ||
      url.pathname !== `/d/${p.publicId}` ||
      p.version < 1
    )
      throw new Error('Некорректный публичный адрес.');
  } else if (p.url !== null)
    throw new Error('Отозванная публикация не может иметь доступную ссылку.');
  return p as Publication;
}
export function parsePublicationMutation(value: unknown): PublicationMutation {
  const p = object(value);
  if (
    Object.keys(p).length !== 6 ||
    !['publish', 'unpublish', 'deleteDocument'].includes(p.action as string) ||
    !identifier(p.documentId) ||
    !identifier(p.operationId) ||
    !identifier(p.expectedMutationId) ||
    !integer(p.expectedVersion) ||
    !integer(p.expectedGeneration)
  )
    throw new Error('Квитанция публикации повреждена. Новые операции заблокированы.');
  return p as PublicationMutation;
}
export function checkPublicationResult(value: unknown, body: Record<string, unknown>): void {
  const r = object(value);
  if (body.action === 'inventory') {
    if (
      r.status !== 'completed' ||
      !Array.isArray(r.publications) ||
      !integer(r.lifecycleGeneration)
    )
      throw new Error('Некорректный inventory публикаций.');
    const parsed = r.publications.map(publication);
    if (
      new Set(parsed.map((p) => p.documentId)).size !== parsed.length ||
      new Set(parsed.map((p) => p.publicId)).size !== parsed.length
    )
      throw new Error('Повторяющаяся публикация в inventory.');
    return;
  }
  if (
    !['completed', 'pending', 'unknown'].includes(r.status as string) ||
    r.operationId !== body.operationId
  )
    throw new Error('Сервис не подтвердил запрошенную операцию.');
  if (r.status === 'unknown') return;
  const expected = body.action === 'deletionStatus' ? 'deleteAccount' : body.action;
  if (expected === 'status') {
    if (!['publish', 'unpublish', 'deleteDocument', 'deleteAccount'].includes(r.action as string))
      throw new Error('Неподтверждённый тип операции.');
  } else if (r.action !== expected) throw new Error('Сервис подтвердил другую операцию.');
  if (!integer(r.lifecycleGeneration))
    throw new Error('Сервис не подтвердил версию жизненного цикла.');
  if (r.status === 'completed' && r.action !== 'deleteAccount') {
    const p = publication(r.publication);
    if (body.documentId !== undefined && p.documentId !== body.documentId)
      throw new Error('Сервис подтвердил другой документ.');
    // Квитанция доказывает завершённое действие; metadata отражает уже текущее состояние.
    // После потерянного Publish ACK другой клиент мог успеть снять публикацию.
    if (r.action === 'deleteDocument' && p.state !== 'deleted')
      throw new Error('Сервис не подтвердил удаление документа.');
  }
}
export type ReceiptStorage = Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>;
export function readPublicationReceipt(
  store: ReceiptStorage,
  key: string,
): PublicationMutation | null {
  const raw = store.getItem(key);
  return raw === null ? null : parsePublicationMutation(JSON.parse(raw));
}
export function writePublicationReceipt(
  store: ReceiptStorage,
  key: string,
  operation: PublicationMutation,
): void {
  parsePublicationMutation(operation);
  const previous = readPublicationReceipt(store, key);
  if (previous && JSON.stringify(previous) !== JSON.stringify(operation))
    throw new Error('В другой вкладке уже начата операция. Сначала восстановите её результат.');
  const serialized = JSON.stringify(operation);
  store.setItem(key, serialized);
  if (store.getItem(key) !== serialized)
    throw new Error('Не удалось сохранить квитанцию. Запрос не отправлен.');
}
export function clearPublicationReceipt(
  store: ReceiptStorage,
  key: string,
  completedOperationId: string,
): PublicationMutation | null {
  const previous = readPublicationReceipt(store, key);
  if (!previous || previous.operationId !== completedOperationId) return previous;
  store.removeItem(key);
  const remaining = readPublicationReceipt(store, key);
  if (remaining?.operationId === completedOperationId)
    throw new Error('Не удалось удалить завершённую квитанцию.');
  return remaining;
}
