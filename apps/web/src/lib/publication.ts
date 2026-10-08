'use client';
import type { User } from 'firebase/auth';
import { firebaseServices } from './firebase';
import {
  checkPublicationResult,
  type Inventory,
  type OperationResult,
} from './publication-contract';
export { checkPublicationResult, parsePublicationMutation } from './publication-contract';
export type {
  Publication,
  Inventory,
  OperationResult,
  PublicationMutation,
} from './publication-contract';
export class PublicationError extends Error {
  constructor(
    message: string,
    readonly code: string,
  ) {
    super(message);
  }
}
export function isDefinitivePublicationError(error: unknown) {
  return (
    error instanceof PublicationError &&
    [
      'invalid-data',
      'invalid-media',
      'conflict',
      'deleted',
      'resource-exhausted',
      'configuration-required',
    ].includes(error.code)
  );
}
function failureMessage(code: string): string {
  return (
    (
      {
        'invalid-data': 'Проверьте поля сохранённого документа.',
        'invalid-media':
          'Не удалось подготовить изображения. Загрузите фото заново или выберите другой источник.',
        conflict: 'Данные изменились на другом устройстве. Сверьте серверную версию.',
        deleted: 'Документ уже удалён.',
        unauthenticated: 'Войдите снова и проверьте результат операции.',
        'account-deleting': 'Аккаунт удаляется. Новые действия временно недоступны.',
        'configuration-required': 'Публикация пока недоступна. Попробуйте позднее.',
        'reauthentication-required': 'Подтвердите вход повторно перед этим действием.',
        'resource-exhausted': 'Достигнут лимит документов или операций.',
      } as Record<string, string>
    )[code] ?? 'Действие не завершено. Проверьте результат перед повтором.'
  );
}
function endpointUrl() {
  const endpoint = process.env.NEXT_PUBLIC_PUBLICATION_API_URL;
  if (!endpoint) throw new Error('Публикация пока недоступна. Попробуйте позднее.');
  const url = new URL(endpoint);
  if (
    url.protocol !== 'https:' &&
    !(
      process.env.NEXT_PUBLIC_USE_EMULATORS === 'true' &&
      ['localhost', '127.0.0.1'].includes(url.hostname)
    )
  )
    throw new Error('Сервис публикации недоступен.');
  return endpoint;
}
export async function publicationRequest<T>(user: User, body: Record<string, unknown>): Promise<T> {
  const endpoint = endpointUrl();
  if (firebaseServices().auth.currentUser?.uid !== user.uid) throw new Error('Аккаунт изменился.');
  const token = await user.getIdToken(true);
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
    cache: 'no-store',
    signal: AbortSignal.timeout(20000),
  });
  const result = await response.json();
  if (!response.ok) {
    const code = result.error?.code ?? 'unavailable';
    throw new PublicationError(failureMessage(code), code);
  }
  if (firebaseServices().auth.currentUser?.uid !== user.uid && body.action !== 'deleteAccount')
    throw new Error('Аккаунт изменился.');
  checkPublicationResult(result, body);
  return result as T;
}
export const inventory = (user: User) =>
  publicationRequest<Inventory>(user, { action: 'inventory' });
export async function recoverAccountDeletion(receipt: {
  ownerUid: string;
  operationId: string;
  recoveryKey: string;
  retry?: boolean;
}): Promise<OperationResult> {
  if (
    !receipt.ownerUid ||
    receipt.ownerUid.includes('/') ||
    !receipt.operationId ||
    receipt.operationId.length > 200 ||
    !/^[a-f0-9]{64}$/.test(receipt.recoveryKey)
  )
    throw new Error('Некорректная квитанция удаления.');
  const body = { action: 'deletionStatus', ...receipt };
  const response = await fetch(endpointUrl(), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    cache: 'no-store',
    signal: AbortSignal.timeout(20000),
  });
  const result = await response.json();
  if (!response.ok) {
    const code = result.error?.code ?? 'unavailable';
    throw new PublicationError(failureMessage(code), code);
  }
  checkPublicationResult(result, body);
  return result as OperationResult;
}
