import assert from 'node:assert/strict';
import test from 'node:test';
import { Timestamp } from 'firebase/firestore';
import {
  canContact,
  checkContactAccepted,
  parseContactRequest,
  validateContact,
} from '../src/lib/contact-contract';
import type { PublicDocumentContent } from '../src/lib/public-document';

const requestId = 'a'.repeat(32),
  publicId = 'b'.repeat(32);
const input = {
  name: 'Reader',
  email: 'reader@example.com',
  message: 'Hello\nA second line',
  website: '',
};
function fixture() {
  return {
    schemaVersion: 1,
    requestId,
    publicId,
    documentId: 'resume-1',
    documentTitle: 'My resume',
    name: input.name,
    email: input.email,
    message: input.message,
    createdAt: Timestamp.fromMillis(1000),
    readAt: null,
  };
}
function content(visible = true, kind = 'email', url = 'mailto:owner@example.com') {
  return {
    blocks: [{ kind: 'links', visible }],
    links: [{ id: 'contact', label: 'Contact', kind, url }],
  } as PublicDocumentContent;
}
test('contact gate uses visible projected typed contacts, not generic links', () => {
  assert.equal(canContact(content()), true);
  assert.equal(canContact(content(false)), false);
  assert.equal(canContact(content(true, 'github', 'https://github.com/owner')), false);
  assert.equal(canContact(content(true, 'email', 'javascript:alert(1)')), false);
  assert.equal(canContact(content(true, 'phone', 'tel:+77001234567')), true);
  assert.equal(canContact(content(true, 'telegram', 'https://t.me/owner')), true);
});
test('contact validation normalizes outer whitespace and preserves multiline message', () => {
  assert.deepEqual(
    validateContact({
      ...input,
      name: ' Reader ',
      email: ' reader@example.com ',
      message: ' Hello\nA second line ',
    }),
    input,
  );
  assert.deepEqual(
    validateContact({ ...input, email: 'READER@EXAMPLE.COM', message: 'Hello\r\nA second line' }),
    input,
  );
});
test('contact validation rejects bots, injected email, controls and oversized fields', () => {
  for (const invalid of [
    { website: 'bot' },
    { name: '\u0000name' },
    { name: 'x'.repeat(101) },
    { email: 'a@example.com?subject=secret' },
    { email: 'reader example.com' },
    { message: '\u0007bad' },
    { message: 'x'.repeat(4001) },
    { message: '   ' },
  ])
    assert.throws(() => validateContact({ ...input, ...invalid }));
});
test('anonymous receipt accepts only the exact captured request, without owner metadata', () => {
  assert.doesNotThrow(() => checkContactAccepted({ status: 'accepted', requestId }, requestId));
  for (const invalid of [
    null,
    { status: 'accepted', requestId: publicId },
    { status: 'accepted', requestId, ownerUid: 'private' },
    { status: 'completed', requestId },
  ])
    assert.throws(() => checkContactAccepted(invalid, requestId), /подтвердить/);
});
test('owner request parser returns exact contract fields and real timestamp values', () => {
  const result = parseContactRequest(fixture(), requestId);
  assert.equal(Object.keys(result).length, 10);
  assert.equal('website' in result, false);
  assert.equal(result.createdAt.getTime(), 1000);
  assert.equal(result.readAt, null);
  assert.equal(
    parseContactRequest({ ...fixture(), documentTitle: ' My resume ' }, requestId).documentTitle,
    ' My resume ',
  );
  assert.equal(
    parseContactRequest(
      { ...fixture(), readAt: Timestamp.fromMillis(2000) },
      requestId,
    ).readAt?.getTime(),
    2000,
  );
});
test('request parser blocks unknown schema, fields, identity, malformed dates and unnormalized data', () => {
  for (const invalid of [
    { schemaVersion: 2 },
    { ownerUid: 'foreign' },
    { requestId: publicId },
    { documentId: 'bad/path' },
    { publicId: 'invalid' },
    { createdAt: '2026-10-09' },
    { readAt: undefined },
    { createdAt: { toDate: () => new Date(NaN) } },
    { name: ' Reader ' },
    { email: 'READER@EXAMPLE.COM' },
    { readAt: Timestamp.fromMillis(0) },
    { message: '   ' },
  ])
    assert.throws(() => parseContactRequest({ ...fixture(), ...invalid }, requestId));
});
