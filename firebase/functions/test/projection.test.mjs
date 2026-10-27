import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { PublicationError, permanentPublicId, projectPublicDocument, publicOrigin, validateRequest, validateWorkspace, validatePublicDocumentSize, publicDocumentMaxBytes } from '../src/projection.mjs';

const fixture = JSON.parse(await readFile(new URL('../../../fixtures/workspace/schema6.json', import.meta.url), 'utf8'));
const workspace = () => structuredClone(fixture.content);
const projection = (value = workspace(), documentId = 'first') => projectPublicDocument(value, documentId, 'owner', 'a'.repeat(32), 1, 'operation');

test('actual Dart schema6 fixture resolves document overrides and preserves Library', () => {
  const value = workspace();
  const result = projection(value).publicDocument;
  assert.equal(result.content.projects[0].title, 'Document title');
  assert.equal(result.content.projects[0].description, '');
  assert.equal(result.content.projects[0].contribution, 'Document contribution');
  assert.equal(value.projects[0].title, 'Library title');
  assert.equal(projection(value, 'second').publicDocument.content.projects[0].title, 'Library title');
  const serialized = JSON.stringify(result);
  for (const forbidden of ['ownerUid', 'notes', 'baseSnapshot', 'githubMetadata', 'sourceMutationId', 'publishAllowed', 'visible":false', 'documents', 'avatarPath', 'imagePaths', 'Override', 'ignoredGitHub']) assert.equal(serialized.includes(forbidden), false, forbidden);
});

test('large private base accepts 201 items while the selected small document publishes', () => {
  const value = workspace();
  value.skills = Array.from({ length: 201 }, (_, index) => ({ id: `base-skill-${index}`, name: `Base skill ${index}` }));
  assert.equal(validateWorkspace(value, 'owner'), value);
  const result = projection(value).publicDocument;
  assert.deepEqual(result.content.skills, value.documents[0].content.skills);
  assert.equal(value.skills.length, 201);
});

test('public collection cap applies after selection and hidden content removal', () => {
  const value = workspace();
  value.documents[0].content.skills = Array.from({ length: 201 }, (_, index) => ({ id: `document-skill-${index}`, name: `Document skill ${index}` }));
  assert.equal(validateWorkspace(value, 'owner'), value);
  assert.throws(() => projection(value), (error) => error instanceof PublicationError
    && error.code === 'invalid-data' && error.httpStatus === 400);
  value.documents[0].content.blocks.find((block) => block.kind === 'skills').visible = false;
  assert.deepEqual(projection(value).publicDocument.content.skills, []);
  value.documents[0].content.blocks.find((block) => block.kind === 'skills').visible = true;
  value.documents[0].content.skills.pop();
  assert.equal(projection(value).publicDocument.content.skills.length, 200);
});

test('contact eligibility requires base AND document consent and selection by stable ID', () => {
  const value = workspace();
  assert.deepEqual(projection(value).publicDocument.content.links, []);
  assert.equal(projection(value, 'second').publicDocument.content.links.length, 1);
  value.links[0].publishAllowed = false;
  assert.deepEqual(projection(value, 'second').publicDocument.content.links, []);
  value.links[0].publishAllowed = true;
  value.documents[1].content.links[0].publishAllowed = false;
  assert.deepEqual(projection(value, 'second').publicDocument.content.links, []);
  value.documents[1].content.links[0].publishAllowed = true;
  value.documents[1].content.links[0].id = 'unapproved-email';
  assert.deepEqual(projection(value, 'second').publicDocument.content.links, []);
});

test('location requires two privacy agreements and a visible Location block', () => {
  const value = workspace();
  assert.equal(projection(value).publicDocument.content.profile.locationText, 'Almaty');
  for (const change of [
    (w) => { w.profile.publishLocation = false; },
    (w) => { w.documents[0].content.profile.publishLocation = false; },
    (w) => { w.documents[0].content.blocks.find((b) => b.kind === 'location').visible = false; },
  ]) {
    const changed = workspace(); change(changed);
    assert.equal(projection(changed).publicDocument.content.profile.locationText, '');
  }
});

test('hidden sections and globally or locally hidden projects never enter public JSON', () => {
  const value = workspace();
  value.documents[0].content.profile.bio = 'hidden bio';
  value.documents[0].content.blocks.find((b) => b.kind === 'about').visible = false;
  value.documents[0].projects[0].visible = false;
  assert.deepEqual(projection(value).publicDocument.content.projects, []);
  assert.equal(JSON.stringify(projection(value).publicDocument).includes('hidden bio'), false);
  value.documents[0].projects[0].visible = true; value.projects[0].visible = false;
  assert.deepEqual(projection(value).publicDocument.content.projects, []);
});

test('explicit modern attachment can include an archived hidden library project', () => {
  const value = workspace();
  value.projects[0].visible = false;
  assert.deepEqual(projection(value).publicDocument.content.projects, []);
  value.mainPortfolioId = 'first';
  assert.equal(projection(value).publicDocument.content.projects.length, 1);
  value.documents[0].projects[0].visible = false;
  assert.deepEqual(projection(value).publicDocument.content.projects, []);
});

test('new public writer omits all legacy attached resumes regardless of the old block', () => {
  const value = workspace();
  const portfolio = value.documents[1];
  portfolio.attachedResumeId = value.documents[0].id;
  portfolio.content.blocks.find((block) => block.kind === 'resume').visible = true;
  assert.equal(projection(value, portfolio.id).attachedResumeId, null);
  portfolio.content.blocks.find((block) => block.kind === 'resume').visible = false;
  const hidden = projection(value, portfolio.id);
  assert.equal(hidden.attachedResumeId, null);
  assert.equal(hidden.publicDocument.attachedResumePublicId, null);
  assert.equal(hidden.publicDocument.content.blocks.some((block) => block.kind === 'resume'), false);
  assert.equal(portfolio.attachedResumeId, value.documents[0].id);
  portfolio.content.blocks = portfolio.content.blocks.filter((block) => block.kind !== 'resume');
  assert.equal(projection(value, portfolio.id).attachedResumeId, null);
});

test('main schema7 preserves private resume identity but publishes one portfolio without project images', () => {
  const value = workspace();
  value.mainPortfolioId = 'first';
  value.githubUsername = 'snow-numb';
  value.personalization = { status: 'completed', step: 3 };
  value.legacyMainSnapshot = structuredClone(value.documents[0]);
  value.projects[0].iconId = 'camera';
  value.projects[0].imagePaths = ['accounts/owner/media/' + 'b'.repeat(32) + '.jpg'];
  value.documents[0].content.profile.avatarPath = '';
  value.profile.publishLocation = false;
  value.documents[0].content.profile.publishLocation = false;
  value.documents[0].content.links[0].publishAllowed = true;
  value.documents[0].content.links[0].visible = true;
  value.links[0].publishAllowed = false;
  const result = projection(value);
  assert.equal(result.publicDocument.schemaVersion, 2);
  assert.equal(result.publicDocument.kind, 'portfolio');
  assert.equal(value.documents[0].kind, 'resume');
  assert.equal(result.publicDocument.content.profile.locationText, 'Almaty');
  assert.equal(result.publicDocument.content.links.length, 1);
  assert.equal(result.publicDocument.content.projects[0].iconId, 'camera');
  assert.equal(Object.hasOwn(result.publicDocument.content.projects[0], 'imageUrls'), false);
  assert.deepEqual(result.media, []);
  for (const secret of ['mainPortfolioId', 'githubUsername', 'personalization', 'legacyMainSnapshot']) {
    assert.equal(JSON.stringify(result.publicDocument).includes(secret), false);
  }
});

test('modern metadata and stock icons reject unknown IDs, foreign backup media and nested metadata', () => {
  for (const mutate of [
    (w) => { w.mainPortfolioId = 'missing'; },
    (w) => { w.githubUsername = 'https://github.com/owner'; },
    (w) => { w.githubUsername = 'owner--test'; },
    (w) => { w.personalization = { status: 'completed', step: 4 }; },
    (w) => { w.projects[0].iconId = '<svg>'; },
    (w) => { w.documents[0].content.mainPortfolioId = null; },
    (w) => { w.legacyMainSnapshot = structuredClone(w.documents[0]); w.legacyMainSnapshot.content.profile.avatarPath = 'accounts/other/media/' + 'b'.repeat(32) + '.jpg'; },
  ]) {
    const value = workspace(); mutate(value);
    assert.throws(() => validateWorkspace(value, 'owner'), PublicationError);
  }
});

test('schema7 supports twenty legacy documents and a main while archive links remain recoverable', () => {
  const value = workspace();
  value.documents = Array.from({ length: 21 }, (_, index) => ({ ...structuredClone(value.documents[0]), id: `document-${index}` }));
  assert.throws(() => validateWorkspace(value, 'owner'), PublicationError);
  value.mainPortfolioId = 'document-20';
  value.legacyMainSnapshot = structuredClone(value.documents[0]);
  value.legacyMainSnapshot.projects[0].projectId = 'deleted-library-project';
  assert.equal(validateWorkspace(value, 'owner'), value);
  value.documents.push({ ...structuredClone(value.documents[0]), id: 'overflow' });
  assert.throws(() => validateWorkspace(value, 'owner'), PublicationError);
});

test('public payload byte budget rejects oversized Unicode data before Firestore writes', () => {
  assert.doesNotThrow(() => validatePublicDocumentSize({ text: 'x'.repeat(publicDocumentMaxBytes - 20) }));
  assert.throws(() => validatePublicDocumentSize({ text: 'я'.repeat(publicDocumentMaxBytes / 2) }),
    (error) => error.code === 'resource-exhausted' && error.httpStatus === 413);
});

test('empty main portfolio publishes no empty section descriptors or artificial profile values', () => {
  const value = workspace(); value.mainPortfolioId = 'first';
  const snapshot = value.documents[0]; snapshot.projects = [];
  for (const key of ['name', 'username', 'headline', 'bio', 'locationText', 'avatarUrl', 'avatarPath']) snapshot.content.profile[key] = '';
  for (const key of ['skills', 'experience', 'education', 'links']) snapshot.content[key] = [];
  const result = projection(value).publicDocument.content;
  assert.deepEqual(result.blocks, []);
  assert.deepEqual(result.projects, []);
  assert.equal(result.profile.name, '');
});

test('public media plan never includes private paths in public payload', () => {
  const value = workspace();
  const path = 'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg';
  value.documents[0].content.profile.avatarPath = path;
  value.projects[0].imagePaths = [path];
  const result = projection(value);
  assert.equal(result.media.length, 1);
  assert.equal(result.media[0].source, path);
  assert.match(result.publicDocument.content.profile.avatarUrl, /^publicMedia\/[a-f0-9]{32}\/1\/[a-f0-9]{32}\.jpg$/);
  assert.equal(JSON.stringify(result.publicDocument).includes('accounts/'), false);
});

test('recursive unknown keys and malicious nested types fail before projection', () => {
  const mutations = [
    (w) => { w.documents[0].content.profile.loginEmail = 'secret@example.com'; },
    (w) => { w.documents[0].content.links[0].notes = 'private'; },
    (w) => { w.documents[0].projects[0].source = { secret: 'private' }; },
    (w) => { w.projects[0].imagePaths = ['accounts/other/media/' + '0'.repeat(32) + '.jpg']; },
    (w) => { w.documents[0].content.skills = [{ id: 'x', name: { privateNotes: 'secret' } }]; },
    (w) => { w.documents[0].baseSnapshot.profile.notes = 'private'; },
    (w) => { w.documents[0].content.documents = []; },
    (w) => { w.documents[0].content.projects = [structuredClone(w.projects[0])]; },
    (w) => { w.documents[0].content.profile.avatarUrl = 'javascript:alert(1)'; },
    (w) => { w.documents[0].content.profile.publishLocation = 'true'; },
    (w) => { w.documents[0].projects[0].titleOverride = ''; },
  ];
  for (const mutate of mutations) {
    const value = workspace(); mutate(value);
    assert.throws(() => projection(value), (error) => error instanceof PublicationError && error.code === 'invalid-data');
  }
});

test('contact URLs reject active schemes, mail headers, encoding tricks and Telegram ports', () => {
  for (const [kind, url] of [
    ['email', 'mailto:a@example.com?subject=private'], ['email', 'mailto:a%0d%0a@example.com'],
    ['email', 'mailto:a@example.com#fragment'], ['phone', 'tel:+1234567?x=private'],
    ['telegram', 'https://t.me:443/user'], ['telegram', 'https://t.me/user?start=private'],
    ['website', 'javascript:alert(1)'], ['website', 'https://owner:password@example.com'],
  ]) {
    const value = workspace(); Object.assign(value.links[0], { kind, url });
    assert.throws(() => validateWorkspace(value, 'owner'), PublicationError);
  }
});

test('legacy missing consent defaults to private instead of broad publication', () => {
  const value = workspace();
  delete value.profile.publishLocation;
  delete value.links[0].publishAllowed;
  assert.equal(projection(value, 'second').publicDocument.content.profile.locationText, '');
  assert.deepEqual(projection(value, 'second').publicDocument.content.links, []);
});

test('permanent IDs remain stable across rename and differ for duplicates/accounts', () => {
  assert.equal(permanentPublicId('uid', 'doc'), permanentPublicId('uid', 'doc'));
  assert.notEqual(permanentPublicId('uid', 'doc'), permanentPublicId('uid', 'copy'));
  assert.notEqual(permanentPublicId('uid', 'doc'), permanentPublicId('other', 'doc'));
  assert.notEqual(permanentPublicId('ab', 'c'), permanentPublicId('a', 'bc'));
});

test('public origin is explicit and localhost is allowed only in emulator', () => {
  assert.equal(publicOrigin('https://stackcard.example'), 'https://stackcard.example');
  assert.equal(publicOrigin('http://localhost:3000', true), 'http://localhost:3000');
  for (const value of [undefined, '', 'http://localhost:3000', 'https://stackcard.example/', 'https://user:password@stackcard.example', 'https://stackcard.example/d/x']) assert.throws(() => publicOrigin(value), PublicationError);
});

test('operation input rejects arbitrary client content and unsafe identifiers', () => {
  const request = { action: 'publish', documentId: 'first', operationId: 'op', expectedMutationId: 'mutation', expectedVersion: 0, expectedGeneration: 0 };
  assert.deepEqual(validateRequest(request), request);
  for (const changed of [
    { ...request, content: workspace() }, { ...request, documentId: '../other' },
    { ...request, operationId: '/foreign' }, { ...request, expectedVersion: -1 },
    { ...request, expectedGeneration: 0.1 }, { action: 'status' },
    { action: 'inventory', uid: 'other' },
  ]) assert.throws(() => validateRequest(changed), PublicationError);
});

test('operation input rejects reserved Firestore document IDs before any database path is built', () => {
  const publish = { action: 'publish', documentId: 'first', operationId: 'op', expectedMutationId: 'mutation', expectedVersion: 0, expectedGeneration: 0 };
  const receipt = { action: 'deletionStatus', ownerUid: 'owner', operationId: 'op', recoveryKey: 'a'.repeat(64) };
  for (const reserved of ['.', '..', '__x__', '____']) {
    for (const changed of [
      { ...publish, documentId: reserved }, { ...publish, operationId: reserved },
      { action: 'status', operationId: reserved }, { ...receipt, ownerUid: reserved }, { ...receipt, operationId: reserved },
    ]) {
      assert.throws(() => validateRequest(changed), (error) => error instanceof PublicationError && error.httpStatus === 400);
    }
  }
  // Похожие, но допустимые Firestore ID и mutation ID не ломаются.
  for (const allowed of ['.first', 'a..b', '__x', 'x__', '_x_']) {
    assert.doesNotThrow(() => validateRequest({ ...publish, documentId: allowed, operationId: allowed }));
  }
  assert.doesNotThrow(() => validateRequest({ ...publish, expectedMutationId: '__mutation__' }));
});
