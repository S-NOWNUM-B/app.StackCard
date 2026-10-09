import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Timestamp } from 'firebase/firestore';
import {
  acceptBaseChanges,
  applyDocumentBaseReview,
  assertWriteBasis,
  baseChanges,
  baseData,
  clone,
  ContractError,
  createDocument,
  createDocumentBaseReview,
  decodeDraft,
  duplicateDocument,
  resolveDocument,
  safeContactUrl,
  safeHttpUrl,
  safeReturnPath,
  validateWorkspace,
  withProjectEdits,
  type GitHubSource,
  type PortfolioDocument,
  type WorkspaceContent,
} from '../src/lib/model';
import { documentPreview } from '../src/lib/preview';
const fixture = JSON.parse(
  readFileSync(new URL('../../../fixtures/workspace/schema6.json', import.meta.url), 'utf8'),
);
function raw() {
  return {
    ...structuredClone(fixture),
    updatedAt: Timestamp.fromDate(new Date(fixture.updatedAt)),
  };
}
function draft() {
  return decodeDraft(raw(), 'owner');
}
test('actual Dart encoded schema6 fixture roundtrips byte shape with independent document overrides', () => {
  const d = draft();
  assert.deepEqual(d.content, fixture.content);
  assert.deepEqual(validateWorkspace(d.content!, 'owner'), fixture.content);
  const content = resolveDocument(d.content!, d.content!.documents[0]);
  assert.equal(content.projects[0].title, 'Document title');
  assert.equal(content.projects[0].description, '');
  assert.equal(content.projects[0].contribution, 'Document contribution');
  assert.equal(d.content!.projects[0].title, 'Library title');
  assert.equal(d.content!.documents[1].projects[0].titleOverride, null);
});
test('unknown envelope, schema, nested keys and timestamp fail before any write', () => {
  for (const mutate of [
    (r: ReturnType<typeof raw>) => (r.schemaVersion = 7),
    (r: ReturnType<typeof raw>) => (r.content.future = true),
    (r: ReturnType<typeof raw>) => (r.content.documents[0].content.profile.future = true),
    (r: ReturnType<typeof raw>) => delete r.content,
    (r: ReturnType<typeof raw>) => (r.updatedAt = '2026-10-08T00:00:00Z'),
  ]) {
    const r = raw();
    mutate(r);
    assert.throws(() => decodeDraft(r, 'owner'));
  }
});
test('foreign owner and media path in last document block writer', () => {
  assert.throws(() => decodeDraft(raw(), 'foreign'));
  const r = raw();
  r.content.documents[1].content.profile.avatarPath = `accounts/foreign/media/${'a'.repeat(32)}.jpg`;
  assert.throws(() => decodeDraft(r, 'owner'));
});
test('legacy schema5 reads safe defaults and rejects backported privacy fields', () => {
  const r = raw();
  r.schemaVersion = 5;
  function strip(c: Record<string, any>) {
    delete c.profile.publishLocation;
    for (const l of c.links) {
      delete l.publishAllowed;
      delete l.visible;
    }
    for (const p of c.projects ?? []) delete p.contribution;
  }
  strip(r.content);
  r.content.links = [];
  for (const d of r.content.documents) {
    strip(d.content);
    d.content.links = [];
    if (d.baseSnapshot) {
      strip(d.baseSnapshot);
      d.baseSnapshot.links = [];
    }
    for (const a of d.projects) {
      delete a.titleOverride;
      delete a.descriptionOverride;
      delete a.contributionOverride;
    }
  }
  const d = decodeDraft(r, 'owner');
  assert.equal(d.content!.profile.publishLocation, false);
  assert.equal(d.content!.projects[0].contribution, '');
  assert.equal(d.content!.documents[0].projects[0].titleOverride, null);
  r.content.documents[1].content.profile.publishLocation = true;
  assert.throws(() => decodeDraft(r, 'owner'));
});
test('CAS rejects create race, changed revision/mutation/timestamp, while preserving caller data', () => {
  const d = draft();
  assert.doesNotThrow(() => assertWriteBasis(d, d));
  assert.throws(() => assertWriteBasis(d, null));
  assert.throws(() => assertWriteBasis(null, d));
  for (const changed of [
    { ...d, mutationId: 'remote' },
    { ...d, localRevision: 4 },
    { ...d, updatedAt: Timestamp.fromMillis(1) },
    { ...d, notes: 'remote' },
  ])
    assert.throws(() => assertWriteBasis(changed, d));
  assert.equal(d.notes, fixture.notes);
});
test('base review preserves local profile and hidden contact unless explicitly chosen', () => {
  const w = draft().content!;
  w.profile.name = 'New base';
  w.links[0].label = 'New label';
  const d = w.documents[0];
  d.content.profile.name = 'Local name';
  const changes = baseChanges(w, d);
  assert.equal(changes.find((c) => c.id === 'profile.name')?.localOverride, true);
  const applied = acceptBaseChanges(w, d, new Set(['links.email']));
  assert.equal(applied.content.profile.name, 'Local name');
  assert.equal(applied.content.links[0].label, 'New label');
  assert.equal(applied.content.links[0].visible, false);
  assert.equal(d.content.links[0].label, 'Work email');
});
test('stale baseline review can remove a base item but does not affect sibling document', () => {
  const w = draft().content!;
  w.links = [];
  const d = w.documents[0];
  const applied = acceptBaseChanges(w, d, new Set(['links.email']));
  assert.equal(applied.content.links.length, 0);
  assert.equal(w.documents[1].content.links.length, 1);
});
test('base review replaces external avatar and private media path as one atomic choice', () => {
  const w = draft().content!;
  const d = w.documents[0];
  d.baseSnapshot!.profile.avatarUrl = 'https://example.com/old.jpg';
  d.content.profile.avatarUrl = 'https://example.com/old.jpg';
  w.profile.avatarPath = `accounts/owner/media/${'a'.repeat(32)}.jpg`;
  const changes = baseChanges(baseData(w), d);
  const avatars = changes.filter((c) => c.id.startsWith('profile.avatar'));
  assert.deepEqual(
    avatars.map((c) => c.id),
    ['profile.avatarPath'],
  );
  assert.deepEqual(avatars[0].before, { avatarUrl: 'https://example.com/old.jpg', avatarPath: '' });
  assert.deepEqual(avatars[0].current, avatars[0].before);
  assert.deepEqual(avatars[0].incoming, { avatarUrl: '', avatarPath: w.profile.avatarPath });
  assert.equal(avatars[0].localOverride, false);
  const applied = acceptBaseChanges(baseData(w), d, new Set(['profile.avatarPath']));
  assert.equal(applied.content.profile.avatarUrl, '');
  assert.equal(applied.content.profile.avatarPath, w.profile.avatarPath);
  assert.equal(d.content.profile.avatarUrl, 'https://example.com/old.jpg');
});
test('avatar local override is detected when only one member of the pair was edited', () => {
  for (const field of ['avatarUrl', 'avatarPath'] as const) {
    const w = draft().content!;
    const d = w.documents[0];
    w.profile.avatarPath = `accounts/owner/media/${'a'.repeat(32)}.jpg`;
    d.content.profile[field] =
      field === 'avatarUrl'
        ? 'https://example.com/local.jpg'
        : `accounts/owner/media/${'b'.repeat(32)}.jpg`;
    const avatar = baseChanges(baseData(w), d).find((c) => c.id === 'profile.avatarPath')!;
    assert.equal(avatar.localOverride, true, field);
    assert.deepEqual(avatar.current, {
      avatarUrl: d.content.profile.avatarUrl,
      avatarPath: d.content.profile.avatarPath,
    });
  }
});
test('base change values and closures retain the compared snapshot after caller mutations', () => {
  const w = draft().content!;
  const d = w.documents[0];
  w.links[0].label = 'Captured label';
  const comparedBase = baseData(w);
  const changes = baseChanges(comparedBase, d);
  const link = changes.find((c) => c.id === 'links.email')!;
  const capturedCurrent = clone(link.current);
  const capturedDocument = clone(d);
  comparedBase.links[0].label = 'Later base label';
  d.content.links[0].visible = true;
  d.baseSnapshot!.links[0].label = 'Mutated baseline';
  assert.deepEqual(link.current, capturedCurrent);
  assert.equal((link.before as { label: string }).label, 'Work email');
  const applied = link.apply(capturedDocument);
  assert.equal(applied.content.links[0].label, 'Captured label');
  assert.equal(applied.content.links[0].visible, false);
});
test('captured review applies only selected changes to its buffer and never writes saved workspace', () => {
  const saved = draft().content!;
  saved.profile.name = 'Changed base name';
  saved.links[0].label = 'Captured contact';
  const buffer = clone(saved.documents[0]);
  buffer.content.profile.name = 'Local buffer name';
  const review = createDocumentBaseReview('owner', saved, buffer);
  const expectedBase = baseData(saved);
  const expectedSavedDocument = clone(saved.documents[0]);
  const expectedBuffer = clone(buffer);
  assert.notEqual(review.base, saved);
  assert.notEqual(review.document, buffer);
  assert.notEqual(review.savedDocument, saved.documents[0]);
  saved.profile.name = 'Later base name';
  saved.links[0].label = 'Later contact';
  saved.documents[0].title = 'Later saved title';
  buffer.content.profile.name = 'Later buffer name';
  assert.deepEqual(review.base, expectedBase);
  assert.deepEqual(review.document, expectedBuffer);
  assert.deepEqual(review.savedDocument, expectedSavedDocument);
  const currentSaved = {
    ...saved,
    ...expectedBase,
    documents: [expectedSavedDocument, saved.documents[1]],
  };
  const beforeApply = clone(currentSaved);
  const applied = applyDocumentBaseReview(
    review,
    'owner',
    currentSaved,
    expectedBuffer,
    new Set(['links.email']),
  );
  assert.equal(applied.content.profile.name, 'Local buffer name');
  assert.equal(applied.content.links[0].label, 'Captured contact');
  assert.equal(applied.content.links[0].visible, false);
  assert.deepEqual(applied.projects, expectedBuffer.projects);
  assert.deepEqual(applied.content.blocks, expectedBuffer.content.blocks);
  assert.deepEqual(applied.baseSnapshot, expectedBase);
  assert.deepEqual(currentSaved, beforeApply);
  assert.deepEqual(review.document, expectedBuffer);
});
const staleReviewCases: {
  name: string;
  owner?: string;
  mutate?: (saved: WorkspaceContent, buffer: PortfolioDocument) => void;
}[] = [
  { name: 'owner transition', owner: 'other' },
  {
    name: 'saved profile update',
    mutate: (saved) => {
      saved.profile.bio = 'Later base bio';
    },
  },
  {
    name: 'saved stable-ID collection update',
    mutate: (saved) => {
      saved.links[0].url = 'mailto:later@example.com';
    },
  },
  {
    name: 'saved selected document update',
    mutate: (saved) => {
      saved.documents[0].title = 'Concurrent saved title';
    },
  },
  {
    name: 'saved selected document deletion',
    mutate: (saved) => {
      saved.documents.shift();
    },
  },
  {
    name: 'new buffer input',
    mutate: (_, buffer) => {
      buffer.content.profile.headline = 'New input';
    },
  },
  {
    name: 'buffer attachment update',
    mutate: (_, buffer) => {
      buffer.projects[0].titleOverride = 'New presentation';
    },
  },
  {
    name: 'different buffer document',
    mutate: (_, buffer) => {
      buffer.id = 'another-document';
    },
  },
];
for (const { name, owner, mutate } of staleReviewCases) {
  test(`captured base review rejects ${name} without changing caller data`, () => {
    const saved = draft().content!;
    saved.profile.name = 'Incoming name';
    const buffer = clone(saved.documents[0]);
    const review = createDocumentBaseReview('owner', saved, buffer);
    mutate?.(saved, buffer);
    const beforeApply = clone({ saved, buffer });
    assert.throws(
      () =>
        applyDocumentBaseReview(review, owner ?? 'owner', saved, buffer, new Set(['profile.name'])),
      ContractError,
    );
    assert.deepEqual({ saved, buffer }, beforeApply);
  });
}
test('Library and sibling changes do not invalidate a base review of the selected document', () => {
  const saved = draft().content!;
  saved.profile.name = 'Incoming name';
  const buffer = clone(saved.documents[0]);
  const review = createDocumentBaseReview('owner', saved, buffer);
  saved.projects[0].title = 'New Library title';
  saved.documents[1].title = 'New sibling title';
  saved.theme = 'light';
  const applied = applyDocumentBaseReview(
    review,
    'owner',
    saved,
    buffer,
    new Set(['profile.name']),
  );
  assert.equal(applied.content.profile.name, 'Incoming name');
  assert.equal(saved.projects[0].title, 'New Library title');
  assert.equal(saved.documents[1].title, 'New sibling title');
  assert.equal(saved.documents[0].content.profile.name, 'Owner');
});
test('declining all base changes acknowledges the captured baseline without replacing buffer content', () => {
  const saved = draft().content!;
  saved.profile.name = 'Incoming name';
  const buffer = clone(saved.documents[0]);
  const review = createDocumentBaseReview('owner', saved, buffer);
  const applied = applyDocumentBaseReview(review, 'owner', saved, buffer, new Set());
  assert.deepEqual(applied.content, buffer.content);
  assert.deepEqual(applied.baseSnapshot, baseData(saved));
});
test('a new document review rejects a concurrent document appearing with the captured ID', () => {
  const saved = draft().content!;
  const buffer = createDocument(saved, 'resume', 'New Resume');
  const review = createDocumentBaseReview('owner', saved, buffer);
  assert.equal(review.savedDocument, undefined);
  assert.doesNotThrow(() => applyDocumentBaseReview(review, 'owner', saved, buffer, new Set()));
  saved.documents.push(clone(buffer));
  assert.throws(
    () => applyDocumentBaseReview(review, 'owner', saved, buffer, new Set()),
    ContractError,
  );
});
test('duplicate gets new identity and dates and never inherits a public metadata field', () => {
  const d = draft().content!.documents[0];
  const copy = duplicateDocument(d);
  assert.notEqual(copy.id, d.id);
  assert.equal(copy.projects[0].descriptionOverride, '');
  assert.equal('publicId' in copy, false);
  assert.notEqual(copy.content, d.content);
});
test('Dart microsecond UTC timestamps survive JS writer validation in order', () => {
  const r = raw();
  r.content.documents[0].createdAt = '2026-10-08T00:00:00.000Z';
  r.content.documents[0].updatedAt = '2026-10-08T00:00:00.000001Z';
  assert.doesNotThrow(() => decodeDraft(r, 'owner'));
  r.content.documents[0].createdAt = '2026-10-08T00:00:00.000002Z';
  assert.throws(() => decodeDraft(r, 'owner'));
});
test('contact URL grammar matches mobile and blocks header/query/control injection', () => {
  for (const [value, kind] of [
    ['tel:+77011234567', 'phone'],
    ['mailto:hello@example.com', 'email'],
    ['https://t.me/a', 'telegram'],
  ] as const)
    assert.equal(safeContactUrl(value, kind), true);
  for (const [value, kind] of [
    ['tel:77011234567', 'phone'],
    ['mailto:a%0d%0a@example.com', 'email'],
    ['mailto:a?x@example.com', 'email'],
    ['mailto:hello@example.com?subject=x', 'email'],
    ['https://t.me/a#x', 'telegram'],
    ['https://t.me/a\n', 'telegram'],
  ] as const)
    assert.equal(safeContactUrl(value, kind), false);
});
test('auth return path only permits owner workspace and never open redirect', () => {
  assert.equal(safeReturnPath('/workspace/document/a'), '/workspace/document/a');
  for (const path of [
    'https://evil.example',
    '//evil.example',
    '/workspace/../../d/x',
    '/workspace%2f%2fevil',
    '/d/x',
  ])
    assert.equal(safeReturnPath(path), '/workspace');
});
test('invalid Library references, cycles and nested documents fail safely', () => {
  for (const mutate of [
    (r: ReturnType<typeof raw>) => (r.content.documents[0].projects[0].projectId = 'missing'),
    (r: ReturnType<typeof raw>) => (r.content.documents[0].content.documents = []),
    (r: ReturnType<typeof raw>) => (r.content.documents[0].attachedResumeId = 'second'),
  ]) {
    const r = raw();
    mutate(r);
    assert.throws(() => decodeDraft(r, 'owner'));
  }
});

test('GitHub local edits track four source overrides and reset when accepted source is restored', () => {
  const p = draft().content!.projects[0];
  const source: GitHubSource = {
    repositoryId: 2,
    name: 'source',
    fullName: 'owner/source',
    htmlUrl: 'https://github.com/owner/source',
    description: 'source description',
    language: 'Dart',
    stars: 0,
    forks: 0,
    isFork: false,
    archived: false,
    updatedAt: '2026-10-08T00:00:00Z',
  };
  const imported = {
    ...p,
    source: 'github' as const,
    githubMetadata: {
      acceptedSource: source,
      lastGitHubSyncAt: null,
      overrideFields: ['description'],
    },
  };
  const edited = withProjectEdits(imported, {
    title: 'Local title',
    technologies: ['React'],
    repositoryUrl: 'https://github.com/owner/fork',
    contribution: 'My role',
    liveUrl: 'https://stackcard.dev',
  });
  assert.deepEqual(edited.githubMetadata!.overrideFields, [
    'title',
    'description',
    'technologies',
    'repositoryUrl',
  ]);
  const restored = withProjectEdits(edited, {
    title: source.name,
    description: source.description!,
    technologies: [source.language!],
    repositoryUrl: source.htmlUrl,
  });
  assert.deepEqual(restored.githubMetadata!.overrideFields, []);
  assert.equal(restored.contribution, 'My role');
  assert.equal(restored.liveUrl, 'https://stackcard.dev');
});
test('owner preview honors both base and document contact/location/project consent and block visibility', () => {
  const w = draft().content!,
    d = w.documents[0];
  const hidden = documentPreview(w, d);
  assert.equal(hidden.links.length, 0);
  assert.equal(hidden.projects.length, 1);
  d.content.links[0].visible = true;
  d.content.links[0].publishAllowed = true;
  w.links[0].publishAllowed = true;
  assert.equal(documentPreview(w, d).links.length, 1);
  w.links[0].visible = false;
  assert.equal(documentPreview(w, d).links.length, 0);
  w.links[0].visible = true;
  w.projects[0].visible = false;
  assert.equal(documentPreview(w, d).projects.length, 0);
  w.projects[0].visible = true;
  w.profile.publishLocation = true;
  d.content.profile.publishLocation = true;
  d.content.profile.locationText = 'Almaty';
  assert.equal(documentPreview(w, d).profile.locationText, 'Almaty');
  w.profile.publishLocation = false;
  assert.equal(documentPreview(w, d).profile.locationText, '');
  d.content.blocks = d.content.blocks.map((b) => ({ ...b, visible: false }));
  const privateProjection = documentPreview(w, d);
  assert.equal(privateProjection.profile.name, '');
  assert.equal(privateProjection.profile.avatarUrl, '');
  assert.equal(privateProjection.projects.length, 0);
  assert.equal(privateProjection.links.length, 0);
  assert.equal('notes' in privateProjection, false);
  assert.equal('avatarPath' in privateProjection.profile, false);
});

test('nullable mobile base snapshot is read as an absent baseline and safely establishes one on review', () => {
  const r = raw();
  r.content.documents[0].baseSnapshot = null;
  const d = decodeDraft(r, 'owner');
  assert.equal(d.content!.documents[0].baseSnapshot, undefined);
  const reviewed = acceptBaseChanges(
    d.content!,
    d.content!.documents[0],
    new Set(['profile.name']),
  );
  assert.equal(reviewed.baseSnapshot!.profile.name, d.content!.profile.name);
});
test('common project/avatar URL validation rejects WHATWG implicit authority and control characters', () => {
  assert.equal(safeHttpUrl('https://example.com/a'), true);
  for (const value of [
    'https:example.com',
    'https://example.com/\u0000unsafe',
    'https://example.com/\u007funsafe',
  ]) {
    assert.equal(safeHttpUrl(value), false);
    const r = raw();
    r.content.profile.avatarUrl = value;
    assert.throws(() => decodeDraft(r, 'owner'));
  }
});
