import assert from 'node:assert/strict';
import { test } from 'node:test';
import { isFirestoreOnlyAccount, readMediaCutover, workspaceAvatarPaths } from '../src/media-lifecycle.mjs';

const fixture = () => ({ cutoff: Date.parse('2026-01-01T00:00:00.000Z'), creationTime: '2026-01-02T00:00:00.000Z',
  draft: { schemaVersion: 7, content: { mainPortfolioId: 'main', profile: {}, projects: [], documents: [{ id: 'main', content: { profile: {} } }] } } });

test('cutover is explicit and defaults to disabled, rejecting malformed dates', () => {
  assert.equal(readMediaCutover(undefined), null);
  assert.equal(readMediaCutover(''), null);
  assert.equal(readMediaCutover('2026-01-01T00:00:00.000Z'), Date.parse('2026-01-01T00:00:00.000Z'));
  for (const value of ['today', '2026-02-30T00:00:00.000Z', '2026-01-01', 123]) assert.throws(() => readMediaCutover(value));
});

test('Firestore-only lifecycle rejects old accounts, legacy archives, project images and unfinished storage cleanup', () => {
  assert.equal(isFirestoreOnlyAccount(fixture()), true);
  for (const alter of [
    (v) => { v.cutoff = null; }, (v) => { v.creationTime = '2025-01-01T00:00:00.000Z'; },
    (v) => { v.draft.schemaVersion = 6; }, (v) => { v.account = { username: 'legacy' }; },
    (v) => { v.draft.content.legacyMainSnapshot = {}; },
    (v) => { v.draft.content.projects = [{ imagePaths: ['old'] }]; },
    (v) => { v.draft.content.documents.push({ id: 'legacy' }); },
    (v) => { v.publications = [{ mediaPaths: ['publicMedia/old'] }]; },
    (v) => { v.operations = [{ status: 'completed', cleanupPaths: ['orphan'] }]; },
    (v) => { v.operations = [{ status: 'pending', action: 'publish', media: [{ source: 'a', destination: 'b' }] }]; },
    (v) => { v.operations = [{ status: 'pending', action: 'unpublish', cleanupPaths: ['orphan'] }]; },
  ]) { const value = fixture(); alter(value); assert.equal(isFirestoreOnlyAccount(value), false); }
});

test('stale pending operation without media or cleanup does not block bucketless deletion', () => {
  for (const action of ['publish', 'unpublish', 'deleteDocument']) {
    const value = fixture();
    value.operations = [{ status: 'pending', action, media: [], cleanupPaths: [] }, { status: 'pending', action: 'publish' }];
    assert.equal(isFirestoreOnlyAccount(value), true);
  }
});

test('avatar references include baseline and omit duplicate/empty values', () => {
  const value = fixture().draft.content;
  value.profile.avatarPath = 'one';
  value.documents[0].content.profile.avatarPath = 'one';
  value.documents[0].baseSnapshot = { profile: { avatarPath: 'two' } };
  assert.deepEqual(workspaceAvatarPaths(value), ['one', 'two']);
});
