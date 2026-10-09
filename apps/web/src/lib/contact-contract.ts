import { isPublicId, safePublicHref, type PublicDocumentContent } from './public-document';

export type ContactInput = { name: string; email: string; message: string; website: string };
export type ContactSubmission = ContactInput & { publicId: string; requestId: string };
export type ContactRequest = {
  schemaVersion: 1;
  requestId: string;
  publicId: string;
  documentId: string;
  documentTitle: string;
  name: string;
  email: string;
  message: string;
  createdAt: Date;
  readAt: Date | null;
};
export class ContactError extends Error {
  constructor(
    message: string,
    readonly code = 'invalid-data',
  ) {
    super(message);
  }
}
export function canContact(content: PublicDocumentContent): boolean {
  return (
    content.blocks.some((b) => b.kind === 'links' && b.visible) &&
    content.links.some(
      (l) => ['email', 'phone', 'telegram'].includes(l.kind) && !!safePublicHref(l.url, l.kind),
    )
  );
}
export function validateContact(input: ContactInput): ContactInput {
  const name = input.name.trim(),
    email = input.email.trim().toLowerCase(),
    message = input.message.replace(/\r\n?/g, '\n').trim();
  if (!name || name.length > 100 || /[\x00-\x1f\x7f]/.test(name))
    throw new ContactError('Введите имя длиной до 100 символов.');
  if (!email || email.length > 254 || !safePublicHref(`mailto:${email}`, 'email'))
    throw new ContactError('Введите корректную почту.');
  if (!message || message.length > 4000 || /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(message))
    throw new ContactError('Введите сообщение длиной до 4000 символов.');
  if (input.website !== '') throw new ContactError('Не удалось отправить сообщение.');
  return { name, email, message, website: '' };
}
export function checkContactAccepted(value: unknown, requestId: string): void {
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw new ContactError('Не удалось подтвердить отправку.', 'unknown');
  const result = value as Record<string, unknown>;
  if (
    Object.keys(result).length !== 2 ||
    result.status !== 'accepted' ||
    result.requestId !== requestId
  )
    throw new ContactError('Не удалось подтвердить отправку.', 'unknown');
}
export function parseContactRequest(value: unknown, requestId: string): ContactRequest {
  const fail = (): never => {
    throw new ContactError('Формат обращения не поддерживается.');
  };
  if (!value || typeof value !== 'object' || Array.isArray(value)) return fail();
  const d = value as Record<string, unknown>;
  const keys = [
    'schemaVersion',
    'requestId',
    'publicId',
    'documentId',
    'documentTitle',
    'name',
    'email',
    'message',
    'createdAt',
    'readAt',
  ];
  if (
    Object.keys(d).length !== keys.length ||
    Object.keys(d).some((k) => !keys.includes(k)) ||
    d.schemaVersion !== 1 ||
    d.requestId !== requestId ||
    !isPublicId(requestId) ||
    typeof d.publicId !== 'string' ||
    !isPublicId(d.publicId) ||
    typeof d.documentId !== 'string' ||
    !d.documentId.trim() ||
    d.documentId.length > 200 ||
    /[\/\x00-\x1f\x7f]/.test(d.documentId) ||
    typeof d.documentTitle !== 'string' ||
    !d.documentTitle.trim() ||
    d.documentTitle.length > 120 ||
    typeof d.name !== 'string' ||
    typeof d.email !== 'string' ||
    typeof d.message !== 'string'
  )
    return fail();
  const input = validateContact({ name: d.name, email: d.email, message: d.message, website: '' });
  if (input.name !== d.name || input.email !== d.email || input.message !== d.message)
    return fail();
  function date(value: unknown): Date {
    if (
      !value ||
      typeof value !== 'object' ||
      !('toDate' in value) ||
      typeof value.toDate !== 'function'
    )
      return fail();
    const result = value.toDate();
    if (!(result instanceof Date) || !Number.isFinite(result.getTime())) return fail();
    return result;
  }
  const createdAt = date(d.createdAt),
    readAt = d.readAt === null ? null : date(d.readAt);
  if (readAt && readAt < createdAt) return fail();
  return {
    schemaVersion: 1,
    requestId,
    publicId: d.publicId,
    documentId: d.documentId,
    documentTitle: d.documentTitle,
    name: input.name,
    email: input.email,
    message: input.message,
    createdAt,
    readAt,
  };
}
