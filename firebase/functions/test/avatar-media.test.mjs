import assert from 'node:assert/strict';
import { test } from 'node:test';
import sharp from 'sharp';
import { avatarMaxBytes, preparePublicAvatar } from '../src/avatar-media.mjs';

const jpeg = async (width = 128, height = 128) => sharp({ create: { width, height, channels: 3, background: '#fff' } }).jpeg().toBuffer();
const record = (bytes) => ({ schemaVersion: 1, contentType: 'image/jpeg', base64: bytes.toString('base64') });
const invalid = (error) => error.code === 'invalid-media';

test('Firestore avatar becomes bounded JPEG data URI without private path or EXIF metadata', async () => {
  const original = await sharp(await jpeg()).withMetadata({ orientation: 6, exif: { IFD0: { Artist: 'private author' } } }).jpeg().toBuffer();
  const result = await preparePublicAvatar(record(original));
  assert.match(result, /^data:image\/jpeg;base64,/);
  const bytes = Buffer.from(result.split(',')[1], 'base64');
  const metadata = await sharp(bytes).metadata();
  assert.equal(metadata.format, 'jpeg');
  assert.equal(metadata.width, 128);
  assert.equal(metadata.exif, undefined);
  assert.ok(bytes.length <= avatarMaxBytes);
});

test('avatar rejects forged MIME, extra fields, corrupt base64, unsafe size and oversized dimensions', async () => {
  const image = await jpeg();
  for (const value of [
    { ...record(image), schemaVersion: 2 }, { ...record(image), contentType: 'image/svg+xml' },
    { ...record(image), ownerUid: 'other' }, { ...record(image), base64: image.toString('base64') + '\n' },
    { ...record(image), base64: '/9j/invalid' }, record(Buffer.alloc(avatarMaxBytes + 1)),
    record(await jpeg(513, 128)), record(await sharp(image).png().toBuffer()),
  ]) await assert.rejects(preparePublicAvatar(value), invalid);
});
