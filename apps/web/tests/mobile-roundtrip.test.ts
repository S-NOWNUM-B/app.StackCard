import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { test } from 'node:test';
import { Timestamp } from 'firebase/firestore';
import {
  acceptBaseChanges,
  attachment,
  clone,
  createDocument,
  decodeDraft,
  resolveDocument,
  validateWorkspace,
  withProjectEdits,
  type DraftEnvelope,
} from '../src/lib/model';

function readEnvelope(path: string | URL): DraftEnvelope {
  const raw = JSON.parse(readFileSync(path, 'utf8'));
  return decodeDraft({ ...raw, updatedAt: Timestamp.fromDate(new Date(raw.updatedAt)) }, 'owner');
}

function webEnvelope(): DraftEnvelope {
  const basis = readEnvelope(new URL('../../../fixtures/workspace/schema6.json', import.meta.url));
  const workspace = clone(basis.content!);
  workspace.documents = [];
  workspace.profile.headline = 'Shared role';
  workspace.skills = [{ id: 'typescript', name: 'TypeScript' }];

  const now = new Date();
  const frontend = createDocument(workspace, 'resume', 'Frontend Resume', now);
  frontend.id = 'web-frontend';
  frontend.content.profile.headline = 'Frontend role from web';
  frontend.content.resumeText = '  Frontend résumé\nТочный текст\n';
  frontend.content.links[0].visible = false;
  frontend.content.skills.push({ id: 'local', name: 'Frontend-only skill' });
  frontend.projects = [
    {
      ...attachment('project'),
      featured: true,
      titleOverride: 'Frontend case study',
      descriptionOverride: '',
      contributionOverride: 'Frontend implementation',
    },
  ];

  const backend = createDocument(workspace, 'resume', 'Backend Resume', now);
  backend.id = 'web-backend';
  backend.content.profile.headline = 'Backend role from web';
  backend.content.theme = 'light';
  backend.projects = [
    {
      ...attachment('project'),
      visible: false,
      contributionOverride: 'Backend implementation',
    },
  ];
  const portfolio = createDocument(workspace, 'portfolio', 'Portfolio from web', now);
  portfolio.id = 'web-portfolio';
  portfolio.attachedResumeId = frontend.id;
  portfolio.projects = [attachment('project')];

  workspace.profile.headline = 'Updated shared role';
  workspace.profile.locationText = 'Astana';
  workspace.profile.publishLocation = false;
  workspace.skills[0].name = 'TypeScript / React';
  workspace.links[0].label = 'Updated work email';
  workspace.links[0].publishAllowed = false;
  workspace.projects = [
    withProjectEdits(workspace.projects[0], {
      title: 'Library from web',
      contribution: 'Shared contribution from web',
      technologies: ['TypeScript', 'Dart'],
    }),
  ];
  workspace.documents = [
    acceptBaseChanges(workspace, frontend, new Set(['skills.typescript', 'links.email'])),
    backend,
    portfolio,
  ];
  return {
    ...basis,
    schemaVersion: 6,
    mutationId: 'web-cross-client',
    localRevision: basis.localRevision + 1,
    notes: '  Private web notes\nЛичные заметки — не содержимое документа\n',
    content: validateWorkspace(workspace, basis.ownerUid),
    updatedAt: Timestamp.fromDate(now),
  };
}

function assertWebEdits(draft: DraftEnvelope) {
  const workspace = draft.content!;
  const [frontend, backend, portfolio] = workspace.documents;
  assert.equal(workspace.projects.length, 1);
  assert.deepEqual(
    workspace.documents.map((d) => d.projects[0].projectId),
    ['project', 'project', 'project'],
  );
  assert.equal(frontend.content.profile.headline, 'Frontend role from web');
  assert.equal(backend.content.profile.headline, 'Backend role from web');
  assert.equal(frontend.content.resumeText, '  Frontend résumé\nТочный текст\n');
  assert.equal(frontend.content.skills[0].name, 'TypeScript / React');
  assert.equal(frontend.content.skills[1].name, 'Frontend-only skill');
  assert.equal(backend.content.skills[0].name, 'TypeScript');
  assert.equal(frontend.baseSnapshot!.profile.headline, 'Updated shared role');
  assert.equal(backend.baseSnapshot!.profile.headline, 'Shared role');
  assert.equal(frontend.content.links[0].visible, false);
  assert.equal(frontend.content.links[0].publishAllowed, false);
  assert.equal(backend.content.links[0].visible, true);
  assert.equal(backend.content.links[0].publishAllowed, true);
  assert.equal(workspace.links[0].publishAllowed, false);
  assert.equal(workspace.profile.publishLocation, false);
  assert.equal(frontend.content.profile.publishLocation, true);
  assert.equal(portfolio.attachedResumeId, frontend.id);
  assert.equal(resolveDocument(workspace, frontend).projects[0].title, 'Frontend case study');
  assert.equal(resolveDocument(workspace, frontend).projects[0].description, '');
  assert.equal(resolveDocument(workspace, backend).projects[0].title, 'Library from web');
  assert.equal(resolveDocument(workspace, backend).projects[0].visible, false);
  assert.equal(
    resolveDocument(workspace, portfolio).projects[0].contribution,
    'Shared contribution from web',
  );
  assert.equal('notes' in frontend.content, false);
}

// Test-only bridge: Flutter передаёт файлы из своего временного каталога.
// JSON заменяет только SDK Timestamp; оба клиента используют свои реальные codecs.
const [mode, path, originalPath] = process.argv.slice(2);
if (mode === '--write-web-envelope') {
  const draft = webEnvelope();
  assertWebEdits(draft);
  writeFileSync(
    path,
    JSON.stringify({
      ...draft,
      updatedAt: (draft.updatedAt as Timestamp).toDate().toISOString(),
    }),
  );
} else if (mode === '--check-mobile-envelope') {
  const original = readEnvelope(originalPath);
  assertWebEdits(original);
  const expected = clone(original.content!);
  expected.documents[0].content.profile.headline = 'Frontend role edited on mobile';
  const mobile = readEnvelope(path);
  assert.equal(mobile.schemaVersion, 6);
  assert.equal(mobile.mutationId, 'mobile-cross-client');
  assert.equal(mobile.localRevision, original.localRevision + 1);
  assert.equal(mobile.notes, original.notes);
  assert.deepEqual(mobile.content, expected);
  assert.deepEqual(validateWorkspace(mobile.content!, 'owner'), expected);
  assert.equal(
    resolveDocument(mobile.content!, mobile.content!.documents[0]).projects[0].title,
    'Frontend case study',
  );
  assert.equal(
    resolveDocument(mobile.content!, mobile.content!.documents[1]).projects[0].contribution,
    'Backend implementation',
  );
} else {
  test('web helpers produce independent cloud6 documents with selective base review and shared Library relations', () => {
    assertWebEdits(webEnvelope());
  });
}
