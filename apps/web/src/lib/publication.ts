'use client';
import type { User } from 'firebase/auth';
import { firebaseConfig, firebaseServices } from './firebase';
import { safeApiEndpoint } from './api-endpoint';
import {
  checkPublicationResult,
  readPublicationResponse,
  type Inventory,
  type OperationResult,
} from './publication-contract';
export {
  checkPublicationResult,
  isDefinitivePublicationError,
  parsePublicationMutation,
  PublicationError,
} from './publication-contract';
export type {
  Publication,
  Inventory,
  OperationResult,
  PublicationMutation,
} from './publication-contract';
export function publicationEndpoint() {
  const endpoint = process.env.NEXT_PUBLIC_PUBLICATION_API_URL;
  if (!endpoint) throw new Error('Публикация пока недоступна. Попробуйте позднее');
  const demo =
    process.env.NEXT_PUBLIC_USE_EMULATORS === 'true' &&
    !!firebaseConfig().projectId?.startsWith('demo-');
  const checked = safeApiEndpoint(endpoint, demo);
  if (!checked) throw new Error('Сервис публикации недоступен');
  return checked;
}
export async function publicationRequest<T>(user: User, body: Record<string, unknown>): Promise<T> {
  const endpoint = publicationEndpoint();
  if (firebaseServices().auth.currentUser?.uid !== user.uid) throw new Error('Аккаунт изменился');
  const token = await user.getIdToken(true);
  if (firebaseServices().auth.currentUser?.uid !== user.uid) throw new Error('Аккаунт изменился');
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
    cache: 'no-store',
    credentials: 'omit',
    redirect: 'error',
    signal: AbortSignal.timeout(20000),
  });
  const result = await readPublicationResponse(response);
  if (firebaseServices().auth.currentUser?.uid !== user.uid && body.action !== 'deleteAccount')
    throw new Error('Аккаунт изменился');
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
    throw new Error('Некорректная квитанция удаления');
  const body = { action: 'deletionStatus', ...receipt };
  const response = await fetch(publicationEndpoint(), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    cache: 'no-store',
    credentials: 'omit',
    redirect: 'error',
    signal: AbortSignal.timeout(20000),
  });
  const result = await readPublicationResponse(response);
  checkPublicationResult(result, body);
  return result as OperationResult;
}
