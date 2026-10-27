import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase/firestore';
import {
  assertWriteBasis,
  attachment,
  BasisConflictError,
  ContractError,
  emptyContent,
  equal,
  mainDocument,
  migrateMainPortfolio,
  seedDocument,
  type DraftEnvelope,
} from '../src/lib/model';
import {
  acknowledgedDraft,
  decodeWorkspaceHash,
  joinMessages,
  sameConfirmationContext,
  userErrorMessage,
} from '../src/lib/workspace-state';
import {
  isDefinitivePublicationError,
  PublicationError,
  readPublicationResponse,
} from '../src/lib/publication-contract';
import { pdfAvatarSource } from '../src/lib/portfolio-pdf';
import { emptyProject, moveAttachment } from '../src/components/project-editor';
import { passwordChangeIssue } from '../src/components/account-settings';
import { metadata as accountDeletionMetadata } from '../src/app/account-deletion/page';

const envelope = (mutationId: string): DraftEnvelope => {
  const content = migrateMainPortfolio(emptyContent(), null);
  return {
    schemaVersion: 7,
    ownerUid: 'owner',
    mutationId,
    localRevision: 1,
    notes: '',
    content,
    updatedAt: Timestamp.fromMillis(1000),
  };
};

test('bug 1: basis conflict is a definitive ContractError subtype without misleading retry tail', () => {
  const basis = envelope('saved');
  const remote = { ...envelope('remote'), updatedAt: Timestamp.fromMillis(2000) };
  assert.throws(
    () => assertWriteBasis(remote, basis),
    (error) =>
      error instanceof BasisConflictError &&
      error instanceof ContractError &&
      !/Повтор Save/.test(error.message) &&
      !error.message.endsWith('.'),
  );
});

test('bug 3: technical SDK/browser errors are translated, own Russian messages are kept', () => {
  const offline = Object.assign(
    new Error('Failed to get document because the client is offline.'),
    { code: 'unavailable', name: 'FirebaseError' },
  );
  assert.match(userErrorMessage(offline), /Нет подключения/);
  assert.match(userErrorMessage(new TypeError('Failed to fetch')), /Нет подключения/);
  assert.match(
    userErrorMessage(new DOMException('signal timed out', 'TimeoutError')),
    /не ответил вовремя/,
  );
  assert.match(
    userErrorMessage(
      Object.assign(new Error('Missing or insufficient permissions.'), {
        code: 'permission-denied',
      }),
    ),
    /Нет доступа/,
  );
  assert.equal(
    userErrorMessage(new SyntaxError("Unexpected token '<'")),
    'Действие не завершено. Повторите попытку',
  );
  assert.equal(userErrorMessage('x', 'Свой fallback'), 'Свой fallback');
  const own = new PublicationError(
    'Достигнут лимит документов или операций.',
    'resource-exhausted',
  );
  assert.equal(userErrorMessage(own), own.message);
  for (const message of [
    userErrorMessage(offline),
    userErrorMessage(new Error('boom')),
    joinMessages('Первое.', 'Второе'),
    joinMessages('Первое', 'Второе.'),
  ])
    assert.ok(!message.endsWith('.'), message);
  assert.equal(joinMessages('Первое', 'Второе.'), 'Первое. Второе');
});

test('bug 3: publication response parser handles HTML, empty and null bodies', async () => {
  const html = new Response('<html>Bad gateway</html>', { status: 502 });
  await assert.rejects(
    readPublicationResponse(html),
    (error) =>
      error instanceof PublicationError &&
      error.code === 'unavailable' &&
      !isDefinitivePublicationError(error),
  );
  await assert.rejects(
    readPublicationResponse(new Response('null', { status: 200 })),
    (error) => error instanceof PublicationError && error.code === 'unavailable',
  );
  await assert.rejects(
    readPublicationResponse(new Response('', { status: 200 })),
    (error) => error instanceof PublicationError && /некорректный ответ/.test(error.message),
  );
  await assert.rejects(
    readPublicationResponse(
      new Response(JSON.stringify({ error: { code: 'conflict' } }), { status: 409 }),
    ),
    (error) => isDefinitivePublicationError(error),
  );
  await assert.rejects(
    readPublicationResponse(new Response('null', { status: 500 })),
    (error) => error instanceof PublicationError && error.code === 'unavailable',
  );
  assert.deepEqual(
    await readPublicationResponse(new Response(JSON.stringify({ status: 'completed' }))),
    { status: 'completed' },
  );
});

test('bug 4: malformed workspace hash is ignored instead of throwing', () => {
  assert.equal(decodeWorkspaceHash('#%E0'), '');
  assert.equal(decodeWorkspaceHash('#%'), '');
  assert.equal(decodeWorkspaceHash('#project%2Fabc'), 'project/abc');
  assert.equal(decodeWorkspaceHash(''), '');
});

test('bug 8: committed Save followed by a newer server version is a success, not a conflict', () => {
  const newer = envelope('other-device');
  const ack = acknowledgedDraft(newer, 'mine');
  assert.equal(ack.superseded, true);
  assert.equal(ack.draft, newer);
  assert.doesNotThrow(() => assertWriteBasis(newer, ack.draft));
  assert.equal(acknowledgedDraft(envelope('mine'), 'mine').superseded, false);
  assert.throws(() => acknowledgedDraft(null, 'mine'));
});

test('bug 9: background inventory refresh does not cancel confirmation', () => {
  const captured = { basis: envelope('saved'), view: 'home', publications: null };
  assert.ok(
    sameConfirmationContext(
      captured,
      { ...captured, publications: { status: 'completed', publications: [] } },
      equal,
    ),
  );
  assert.ok(!sameConfirmationContext(captured, { ...captured, view: 'projects' }, equal));
  assert.ok(!sameConfirmationContext(captured, { ...captured, basis: envelope('remote') }, equal));
});

test('bug 10: hidden profile never reads avatar, visible prefers private path', () => {
  const content = seedDocument(emptyContent());
  content.profile.avatarUrl = 'https://example.com/a.jpg';
  content.profile.avatarPath = 'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg';
  assert.deepEqual(pdfAvatarSource(content), { path: content.profile.avatarPath });
  content.profile.avatarPath = '';
  assert.deepEqual(pdfAvatarSource(content), { url: content.profile.avatarUrl });
  content.blocks = content.blocks.map((b) => (b.kind === 'profile' ? { ...b, visible: false } : b));
  assert.equal(pdfAvatarSource(content), null);
});

test('bug 11: password change uses registration policy', () => {
  assert.match(passwordChangeIssue('short', 'short', 'a@b.c')!, /от 8 до 128/);
  assert.match(passwordChangeIssue('password123', 'password123', 'a@b.c')!, /слишком простой/);
  assert.match(passwordChangeIssue('ivan.petrov', 'ivan.petrov', 'ivan.petrov@mail.ru')!, /почты/);
  assert.match(passwordChangeIssue('Sv3t-Lana-91', 'other', 'a@b.c')!, /совпадать/);
  assert.equal(passwordChangeIssue('Sv3t-Lana-91', 'Sv3t-Lana-91', 'a@b.c'), null);
});

test('bug 12: account deletion title is not duplicated by layout template', () => {
  assert.equal(accountDeletionMetadata.title, 'Удаление аккаунта');
});

test('bug 13: Up/Down order skips attachments without a Library project', () => {
  const workspace = migrateMainPortfolio(emptyContent(), null);
  const a = emptyProject(),
    b = emptyProject();
  workspace.projects = [a, b];
  const document = mainDocument(workspace)!;
  document.projects = [attachment(a.id), attachment('missing'), attachment(b.id)];
  const down = moveAttachment(workspace, document, a.id, 1).map((x) => x.projectId);
  assert.deepEqual(down, [b.id, 'missing', a.id]);
  const up = moveAttachment(workspace, document, b.id, -1).map((x) => x.projectId);
  assert.deepEqual(up, [b.id, 'missing', a.id]);
  assert.equal(moveAttachment(workspace, document, b.id, 1), document.projects);
});
