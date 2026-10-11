import sharp from 'sharp';
import { PublicationError } from './projection.mjs';

export const avatarMaxBytes = 256 * 1024;
export const avatarMaxDimension = 512;
const maxBase64Length = Math.ceil(avatarMaxBytes / 3) * 4;
const invalid = () => { throw new PublicationError('invalid-media', 'Photo is unavailable', 400); };

// Firestore metadata и canonical base64 проверяются до декодирования JPEG.
export async function preparePublicAvatar(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)
      || Object.keys(value).length !== 3
      || !Object.hasOwn(value, 'schemaVersion') || !Object.hasOwn(value, 'contentType') || !Object.hasOwn(value, 'base64')
      || value.schemaVersion !== 1 || value.contentType !== 'image/jpeg'
      || typeof value.base64 !== 'string' || value.base64.length === 0 || value.base64.length > maxBase64Length
      || !/^[A-Za-z0-9+/]+={0,2}$/.test(value.base64)) invalid();
  const bytes = Buffer.from(value.base64, 'base64');
  if (bytes.length === 0 || bytes.length > avatarMaxBytes || bytes.toString('base64') !== value.base64
      || bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) invalid();
  try {
    const input = sharp(bytes, { limitInputPixels: avatarMaxDimension * avatarMaxDimension, failOn: 'error' });
    const info = await input.metadata();
    if (info.format !== 'jpeg' || !info.width || !info.height
        || info.width > avatarMaxDimension || info.height > avatarMaxDimension || (info.pages ?? 1) !== 1) invalid();
    // Повторная кодировка не переносит EXIF/GPS или иные client metadata.
    const cleaned = await input.rotate().jpeg({ quality: 85 }).toBuffer();
    if (!cleaned.length || cleaned.length > avatarMaxBytes) invalid();
    return `data:image/jpeg;base64,${cleaned.toString('base64')}`;
  } catch (error) {
    if (error instanceof PublicationError) throw error;
    invalid();
  }
}
