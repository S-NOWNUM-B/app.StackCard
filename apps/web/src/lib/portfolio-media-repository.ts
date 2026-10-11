'use client';
import type { User } from 'firebase/auth';
import { doc, getDocFromServer, runTransaction } from 'firebase/firestore';
import { getBytes, ref } from 'firebase/storage';
import { firebaseServices } from './firebase';
import { safeHttpUrl } from './model';

export const avatarMaxBytes = 256 * 1024;
export const avatarMaxDimension = 512;
export const legacyAvatarMaxBytes = 2 * 1024 * 1024;
const originalMaxBytes = 10 * 1024 * 1024;
export type AvatarDocument = { schemaVersion: 1; contentType: 'image/jpeg'; base64: string };

export function isOwnerMediaPath(path: string, uid: string): boolean {
  if (!uid || uid.includes('/')) return false;
  const prefix = `accounts/${uid}/media/`;
  return path.startsWith(prefix) && /^[a-f0-9]{32}\.jpg$/.test(path.slice(prefix.length));
}

function imageFailure(): Error {
  return new Error('Не удалось прочитать фотографию. Выберите другой файл.');
}

function mediaFailure(error: unknown): Error {
  if (error && typeof error === 'object' && 'code' in error) {
    const code = String(error.code);
    if (code.includes('permission-denied') || code.includes('unauthorized'))
      return new Error('Нет доступа к фотографии. Откройте редактор своего аккаунта.');
    if (code.includes('unauthenticated'))
      return new Error('Войдите в аккаунт, чтобы добавить фотографию.');
    return new Error('Фотография недоступна. Повторите попытку.');
  }
  return error instanceof Error ? error : imageFailure();
}

/** Bounded JPEG marker validation before image allocation; canvas removes metadata. */
export function validateAvatarJpeg(bytes: Uint8Array): void {
  if (!bytes.length || bytes.length > avatarMaxBytes) throw imageFailure();
  if (
    bytes[0] !== 0xff ||
    bytes[1] !== 0xd8 ||
    bytes[bytes.length - 2] !== 0xff ||
    bytes[bytes.length - 1] !== 0xd9
  )
    throw imageFailure();
  let offset = 2,
    dimensions = false;
  while (offset < bytes.length - 2) {
    if (bytes[offset++] !== 0xff) throw imageFailure();
    while (bytes[offset] === 0xff) offset++;
    const marker = bytes[offset++];
    if (marker === 0xda) break;
    const length = bytes[offset] * 256 + bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) throw imageFailure();
    // EXIF/XMP (APP1), Photoshop/IPTC (APP13), comments are never accepted.
    if (marker === 0xe1 || marker === 0xed || marker === 0xfe) throw imageFailure();
    if ([0xc0, 0xc1, 0xc2].includes(marker)) {
      if (length < 8) throw imageFailure();
      const height = bytes[offset + 3] * 256 + bytes[offset + 4];
      const width = bytes[offset + 5] * 256 + bytes[offset + 6];
      if (width < 1 || height < 1 || width > avatarMaxDimension || height > avatarMaxDimension)
        throw imageFailure();
      dimensions = true;
    }
    offset += length;
  }
  if (!dimensions) throw imageFailure();
}

export function encodeAvatarDocument(bytes: Uint8Array): AvatarDocument {
  validateAvatarJpeg(bytes);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return { schemaVersion: 1, contentType: 'image/jpeg', base64: btoa(binary) };
}

export function decodeAvatarDocument(value: unknown): Uint8Array {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw imageFailure();
  const data = value as Record<string, unknown>,
    encoded = data.base64;
  if (
    Object.keys(data).sort().join(',') !== 'base64,contentType,schemaVersion' ||
    data.schemaVersion !== 1 ||
    data.contentType !== 'image/jpeg' ||
    typeof encoded !== 'string' ||
    !encoded.length ||
    encoded.length > Math.ceil(avatarMaxBytes / 3) * 4 ||
    !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encoded)
  )
    throw imageFailure();
  let binary: string;
  try {
    binary = atob(encoded);
  } catch {
    throw imageFailure();
  }
  if (btoa(binary) !== encoded) throw imageFailure();
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  validateAvatarJpeg(bytes);
  return bytes;
}

export async function prepareAvatar(file: File): Promise<Uint8Array> {
  if (
    !file.size ||
    file.size > originalMaxBytes ||
    !['image/jpeg', 'image/png', 'image/webp'].includes(file.type)
  )
    throw new Error('Выберите фотографию JPEG, PNG или WebP размером до 10 МБ.');
  const original = new Uint8Array(await file.arrayBuffer());
  validateOriginalImage(original, file.type);
  const bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
  try {
    if (
      bitmap.width < 1 ||
      bitmap.height < 1 ||
      bitmap.width > 8192 ||
      bitmap.height > 8192 ||
      bitmap.width * bitmap.height > 24_000_000
    )
      throw imageFailure();
    const ratio = Math.min(1, avatarMaxDimension / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(bitmap.width * ratio));
    canvas.height = Math.max(1, Math.round(bitmap.height * ratio));
    const context = canvas.getContext('2d');
    if (!context) throw imageFailure();
    context.fillStyle = '#ffffff';
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    const jpeg = await new Promise<Blob>((resolve, reject) =>
      canvas.toBlob((blob) => (blob ? resolve(blob) : reject(imageFailure())), 'image/jpeg', 0.85),
    );
    const bytes = new Uint8Array(await jpeg.arrayBuffer());
    validateAvatarJpeg(bytes);
    return bytes;
  } finally {
    bitmap.close();
  }
}

/** MIME/magic and original dimensions are checked before browser pixel decode. */
export function validateOriginalImage(bytes: Uint8Array, mime: string): void {
  if (!bytes.length || bytes.length > originalMaxBytes) throw imageFailure();
  let width = 0,
    height = 0;
  const text = (start: number, end: number) => String.fromCharCode(...bytes.subarray(start, end));
  if (
    mime === 'image/png' &&
    bytes.length >= 24 &&
    [137, 80, 78, 71, 13, 10, 26, 10].every((value, index) => bytes[index] === value)
  ) {
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    width = view.getUint32(16);
    height = view.getUint32(20);
  } else if (mime === 'image/jpeg' && bytes[0] === 255 && bytes[1] === 216) {
    let offset = 2;
    while (offset < bytes.length - 2) {
      if (bytes[offset++] !== 255) throw imageFailure();
      while (bytes[offset] === 255) offset++;
      const marker = bytes[offset++],
        length = bytes[offset] * 256 + bytes[offset + 1];
      if (marker === 0xda || length < 2 || offset + length > bytes.length) break;
      if ([0xc0, 0xc1, 0xc2].includes(marker) && length >= 8) {
        height = bytes[offset + 3] * 256 + bytes[offset + 4];
        width = bytes[offset + 5] * 256 + bytes[offset + 6];
        break;
      }
      offset += length;
    }
  } else if (mime === 'image/webp' && text(0, 4) === 'RIFF' && text(8, 12) === 'WEBP') {
    const chunk = text(12, 16);
    if (chunk === 'VP8X' && bytes.length >= 30 && (bytes[20] & 2) === 0) {
      width = 1 + bytes[24] + bytes[25] * 256 + bytes[26] * 65536;
      height = 1 + bytes[27] + bytes[28] * 256 + bytes[29] * 65536;
    } else if (
      chunk === 'VP8 ' &&
      bytes.length >= 30 &&
      bytes[23] === 157 &&
      bytes[24] === 1 &&
      bytes[25] === 42
    ) {
      width = (bytes[26] + bytes[27] * 256) & 0x3fff;
      height = (bytes[28] + bytes[29] * 256) & 0x3fff;
    } else if (chunk === 'VP8L' && bytes.length >= 25 && bytes[20] === 47) {
      width = 1 + ((bytes[21] + bytes[22] * 256) & 0x3fff);
      height = 1 + ((bytes[22] >> 6) | (bytes[23] << 2) | ((bytes[24] & 15) << 10));
    }
  }
  if (width < 1 || height < 1 || width > 8192 || height > 8192 || width * height > 24_000_000)
    throw imageFailure();
}

export interface PortfolioMediaTransport {
  read(path: string): Promise<unknown | null>;
  create(path: string, data: AvatarDocument): Promise<void>;
  remove(path: string): Promise<void>;
  legacyRead?(path: string): Promise<Uint8Array>;
}

/** Captured UID survives awaits; only a missing Firestore doc allows legacy read. */
export class FirestorePortfolioMediaRepository {
  constructor(
    readonly ownerUid: string,
    private readonly transport: PortfolioMediaTransport,
    private readonly active: () => boolean,
    private readonly timeoutMs = 40_000,
  ) {
    if (!ownerUid || ownerUid.includes('/')) throw new Error('Некорректный аккаунт.');
  }
  private async wait<T>(promise: Promise<T>): Promise<T> {
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      return await Promise.race([
        promise,
        new Promise<never>((_, reject) => {
          timer = setTimeout(
            () => reject(new Error('Загрузка фотографии недоступна. Повторите попытку.')),
            this.timeoutMs,
          );
        }),
      ]);
    } catch (error) {
      throw mediaFailure(error);
    } finally {
      clearTimeout(timer);
    }
  }
  private guard(path?: string) {
    if (!this.active()) throw new Error('Аккаунт изменился. Откройте редактор заново.');
    if (path !== undefined && !isOwnerMediaPath(path, this.ownerUid)) throw imageFailure();
  }
  async upload(bytes: Uint8Array): Promise<string> {
    this.guard();
    const data = encodeAvatarDocument(bytes),
      random = new Uint8Array(16);
    crypto.getRandomValues(random);
    const id = Array.from(random, (byte) => byte.toString(16).padStart(2, '0')).join('');
    const path = `accounts/${this.ownerUid}/media/${id}.jpg`;
    await this.wait(this.transport.create(path, data));
    this.guard(path);
    return path;
  }
  async read(path: string): Promise<Uint8Array> {
    this.guard(path);
    const document = await this.wait(this.transport.read(path));
    this.guard(path);
    if (document === null) {
      if (!this.transport.legacyRead) throw new Error('Фотография недоступна.');
      const bytes = await this.wait(this.transport.legacyRead(path));
      this.guard(path);
      return bytes.slice();
    }
    return decodeAvatarDocument(document);
  }
  async delete(path: string): Promise<void> {
    this.guard(path);
    // Never delete an older Storage object through new-avatar cleanup.
    await this.wait(this.transport.remove(path));
    this.guard(path);
  }
}

export function portfolioMediaRepository(user: User): FirestorePortfolioMediaRepository {
  const { auth, firestore, storage } = firebaseServices(),
    ownerUid = user.uid;
  const active = () => auth.currentUser?.uid === ownerUid;
  const guard = () => {
    if (!active()) throw new Error('Аккаунт изменился.');
  };
  const account = doc(firestore, 'accounts', ownerUid);
  const assertAccount = (data: Record<string, unknown> | undefined) => {
    guard();
    if (data && (data.lifecycleState ?? 'active') !== 'active')
      throw new Error('Аккаунт недоступен.');
  };
  return new FirestorePortfolioMediaRepository(
    ownerUid,
    {
      read: async (path) => {
        guard();
        const snapshot = await getDocFromServer(doc(firestore, path));
        guard();
        return snapshot.exists() ? snapshot.data() : null;
      },
      create: async (path, data) => {
        await runTransaction(firestore, async (transaction) => {
          assertAccount((await transaction.get(account)).data());
          const reference = doc(firestore, path),
            previous = await transaction.get(reference);
          guard();
          if (previous.exists()) throw new Error('Фотография уже существует.');
          transaction.set(reference, data);
        });
      },
      remove: async (path) => {
        await runTransaction(firestore, async (transaction) => {
          assertAccount((await transaction.get(account)).data());
          const reference = doc(firestore, path),
            previous = await transaction.get(reference);
          guard();
          if (previous.exists()) {
            decodeAvatarDocument(previous.data());
            transaction.delete(reference);
          }
        });
      },
      legacyRead: async (path) =>
        new Uint8Array(await getBytes(ref(storage, path), 2 * 1024 * 1024)),
    },
    active,
  );
}

export async function readAvatarBytes(user: User, path: string): Promise<Uint8Array> {
  return portfolioMediaRepository(user).read(path);
}

export function isSafeLegacyAvatarUrl(value: string): boolean {
  if (!safeHttpUrl(value) || /[\\#]/.test(value)) return false;
  const url = new URL(value),
    authority = /^https?:\/\/([^/?#]+)/.exec(value)?.[1] ?? '',
    hostname = url.hostname.toLowerCase(),
    labels = hostname.split('.');
  return (
    !url.hash &&
    !authority.includes(':') &&
    !authority.includes('@') &&
    !authority.includes('%') &&
    labels.length >= 2 &&
    hostname.length <= 253 &&
    labels.every((label) => /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(label)) &&
    /^[a-z]{2,63}$/.test(labels.at(-1)!) &&
    !/\.(?:localhost|local|localdomain|internal|lan|home|test|invalid|example|onion|arpa)$/.test(
      hostname,
    )
  );
}

/** Только browser fetch: без cookies, redirects, proxy и необработанного image decode. */
export async function fetchLegacyAvatarFile(
  url: string,
  {
    fetcher = fetch,
    active = () => true,
    timeoutMs = 10_000,
  }: { fetcher?: typeof fetch; active?: () => boolean; timeoutMs?: number } = {},
): Promise<File> {
  const failure = () =>
    new Error(
      'Не удалось получить старую фотографию для PDF. Проверьте её доступность или выберите фотографию заново.',
    );
  if (!isSafeLegacyAvatarUrl(url)) throw failure();
  const controller = new AbortController();
  let reader: ReadableStreamDefaultReader<Uint8Array> | undefined,
    timer: ReturnType<typeof setTimeout> | undefined;
  const guard = () => {
    if (!active()) throw new Error('Аккаунт изменился. Откройте редактор заново.');
    if (controller.signal.aborted) throw failure();
  };
  async function read() {
    guard();
    const response = await fetcher(url, {
      signal: controller.signal,
      mode: 'cors',
      credentials: 'omit',
      redirect: 'error',
      referrerPolicy: 'no-referrer',
      cache: 'no-store',
    });
    guard();
    const mime = response.headers.get('content-type')?.split(';')[0].trim().toLowerCase() ?? '',
      length = response.headers.get('content-length');
    if (
      !response.ok ||
      response.redirected ||
      !response.body ||
      !['image/jpeg', 'image/png', 'image/webp'].includes(mime) ||
      (length !== null && (!/^\d+$/.test(length) || Number(length) > legacyAvatarMaxBytes))
    )
      throw failure();
    reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (true) {
      const result = await reader.read();
      guard();
      if (result.done) break;
      size += result.value.byteLength;
      if (size > legacyAvatarMaxBytes) throw failure();
      chunks.push(result.value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    validateOriginalImage(bytes, mime);
    return new File([bytes.buffer], 'legacy-avatar', { type: mime });
  }
  try {
    return await Promise.race([
      read(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          reject(failure());
        }, timeoutMs);
      }),
    ]);
  } catch {
    guard();
    throw failure();
  } finally {
    clearTimeout(timer);
    controller.abort();
    if (reader) void reader.cancel().catch(() => {});
  }
}

export async function readLegacyAvatarBytes(user: User, url: string): Promise<Uint8Array> {
  const owner = user.uid,
    active = () => firebaseServices().auth.currentUser?.uid === owner;
  const file = await fetchLegacyAvatarFile(url, { active });
  if (!active()) throw new Error('Аккаунт изменился. Откройте редактор заново.');
  const bytes = await prepareAvatar(file);
  if (!active()) throw new Error('Аккаунт изменился. Откройте редактор заново.');
  return bytes;
}
