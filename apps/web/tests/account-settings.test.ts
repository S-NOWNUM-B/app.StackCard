import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  accountErrorMessage,
  canUnlinkProvider,
  clearDeletionJournal,
  continueAccountDeletion,
  deletionJournalKey,
  linkedProviderIds,
  parseDeletionJournal,
  persistDeletionJournal,
  readDeletionJournal,
  type AccountDeletionJournal,
} from '../src/components/account-settings';
import type { OperationResult } from '../src/lib/publication';

const journal: AccountDeletionJournal = {
  version: 1,
  uid: 'owner',
  operationId: 'delete-operation',
  expectedGeneration: 4,
  recoveryKey: 'a'.repeat(64),
};
const receipt = {
  ownerUid: journal.uid,
  operationId: journal.operationId,
  recoveryKey: journal.recoveryKey,
};
const result = (status: OperationResult['status']): OperationResult => ({
  action: 'deleteAccount',
  status,
  operationId: journal.operationId,
  ...(status === 'unknown' ? {} : { lifecycleGeneration: 5 }),
});
function storage() {
  const values = new Map<string, string>();
  return {
    values,
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => {
      values.set(key, value);
    },
    removeItem: (key: string) => {
      values.delete(key);
    },
  };
}
const code = (value: string) => (error: unknown) =>
  typeof error === 'object' && error !== null && 'code' in error && error.code === value;

test('last-provider guard counts distinct attached login methods', () => {
  for (const providers of [
    [],
    [{ providerId: 'google.com' }],
    [{ providerId: 'password' }, { providerId: 'password' }],
  ]) {
    assert.equal(canUnlinkProvider(providers, 'password'), false);
    assert.equal(canUnlinkProvider(providers, 'google.com'), false);
  }
  const both = [{ providerId: 'password' }, { providerId: 'google.com' }];
  assert.equal(canUnlinkProvider(both, 'google.com'), true);
  assert.equal(canUnlinkProvider(both, 'password'), true);
  assert.equal(canUnlinkProvider(both, 'unknown.com'), false);
  assert.deepEqual(linkedProviderIds([...both, ...both, { providerId: '' }]), [
    'password',
    'google.com',
  ]);
});

test('auth and service messages never surface passwords, tokens or raw errors', () => {
  const privateMessage = 'password=private token=secret';
  for (const failure of [
    new Error(privateMessage),
    { code: privateMessage, message: privateMessage },
    { code: 'auth/invalid-credential', message: privateMessage },
    { code: 'reauthentication-required', message: privateMessage },
  ]) {
    const text = accountErrorMessage(failure);
    assert.equal(text.includes('private'), false);
    assert.equal(text.includes('secret'), false);
    assert.ok(text.length > 10);
  }
  assert.match(accountErrorMessage({ code: 'auth/popup-blocked' }), /Google/);
  assert.match(accountErrorMessage({ code: 'account/last-provider' }), /последний/);
});

test('durable deletion journal contains only the scoped receipt, not SDK credentials', () => {
  const local = storage();
  persistDeletionJournal(local, journal);
  assert.deepEqual(readDeletionJournal(local, 'owner'), journal);
  assert.equal(readDeletionJournal(local, 'other-owner'), null);
  assert.deepEqual(Object.keys(JSON.parse(local.getItem(deletionJournalKey('owner'))!)).sort(), [
    'expectedGeneration',
    'operationId',
    'recoveryKey',
    'uid',
    'version',
  ]);
});

test('malformed, foreign and extended journals block overwrite', () => {
  for (const raw of [
    '{broken',
    'null',
    JSON.stringify({ ...journal, uid: 'other-owner' }),
    JSON.stringify({ ...journal, operationId: '../wrong' }),
    JSON.stringify({ ...journal, expectedGeneration: -1 }),
    JSON.stringify({ ...journal, expectedGeneration: 1.5 }),
    JSON.stringify({ ...journal, recoveryKey: 'short' }),
    JSON.stringify({ ...journal, password: 'private' }),
    JSON.stringify({ ...journal, idToken: 'private' }),
  ])
    assert.throws(() => parseDeletionJournal(raw, 'owner'), code('account/journal-invalid'));
  const local = storage();
  local.setItem(deletionJournalKey('owner'), '{broken');
  assert.throws(() => persistDeletionJournal(local, journal), code('account/journal-invalid'));
  assert.equal(local.getItem(deletionJournalKey('owner')), '{broken');
});

test('storage rejection or silent write loss fails before a request can start', () => {
  for (const local of [
    {
      ...storage(),
      setItem: () => {
        throw new Error('unavailable');
      },
    },
    { ...storage(), setItem: () => {} },
  ])
    assert.throws(() => persistDeletionJournal(local, journal), code('account/storage'));
});

test('old completion cannot remove a later receipt for the same UID', () => {
  const local = storage();
  const newer = { ...journal, operationId: 'later-operation', recoveryKey: 'b'.repeat(64) };
  persistDeletionJournal(local, newer);
  clearDeletionJournal(local, journal);
  assert.deepEqual(readDeletionJournal(local, 'owner'), newer);
  clearDeletionJournal(local, newer);
  assert.equal(readDeletionJournal(local, 'owner'), null);
});

test('completed receipt is checked once and never repeats destructive cleanup', async () => {
  const calls: unknown[] = [];
  const response = await continueAccountDeletion(
    journal,
    async (body) => {
      calls.push(body);
      return result('completed');
    },
    {
      retry: true,
      create: async () => {
        assert.fail('completed receipt must not create another deletion');
      },
    },
  );
  assert.equal(response.status, 'completed');
  assert.deepEqual(calls, [receipt]);
});

test('pending receipt is resumed with the same scoped secret and operation', async () => {
  const calls: unknown[] = [];
  const response = await continueAccountDeletion(
    journal,
    async (body) => {
      calls.push(body);
      return result(body.retry ? 'completed' : 'pending');
    },
    { retry: true },
  );
  assert.equal(response.status, 'completed');
  assert.deepEqual(calls, [receipt, { ...receipt, retry: true }]);
});

test('read-only status check does not resume pending cleanup', async () => {
  let calls = 0;
  const response = await continueAccountDeletion(journal, async () => {
    calls++;
    return result('pending');
  });
  assert.equal(response.status, 'pending');
  assert.equal(calls, 1);
});

test('unknown receipt cannot start deletion without an authenticated captured request', async () => {
  const calls: unknown[] = [];
  const response = await continueAccountDeletion(
    journal,
    async (body) => {
      calls.push(body);
      return result('unknown');
    },
    { retry: true },
  );
  assert.equal(response.status, 'unknown');
  assert.deepEqual(calls, [receipt]);
});

test('authenticated recovery retries original request only after unknown status', async () => {
  const calls: string[] = [];
  const response = await continueAccountDeletion(
    journal,
    async () => {
      calls.push('status');
      return result('unknown');
    },
    {
      retry: true,
      create: async () => {
        calls.push('same authenticated request');
        return result('pending');
      },
    },
  );
  assert.equal(response.status, 'pending');
  assert.deepEqual(calls, ['status', 'same authenticated request']);
});

test('foreign operation, wrong action and stale generation are not deletion success', async () => {
  for (const response of [
    { ...result('completed'), operationId: 'other-operation' },
    { ...result('completed'), action: 'publish' },
    { ...result('completed'), lifecycleGeneration: journal.expectedGeneration },
    { ...result('completed'), lifecycleGeneration: undefined },
    { ...result('pending'), lifecycleGeneration: -1 },
  ])
    await assert.rejects(
      continueAccountDeletion(journal, async () => response),
      code('account/invalid-response'),
    );
});

test('UID/unmount guard after pending status prevents later cleanup retry', async () => {
  let active = true,
    calls = 0;
  await assert.rejects(
    continueAccountDeletion(
      journal,
      async () => {
        calls++;
        active = false;
        return result('pending');
      },
      {
        retry: true,
        assertActive: () => {
          if (!active) throw new Error('owner changed');
        },
      },
    ),
    /owner changed/,
  );
  assert.equal(calls, 1);
});

test('network failure preserves the journal and never creates a fresh operation', async () => {
  const local = storage();
  persistDeletionJournal(local, journal);
  let calls = 0;
  await assert.rejects(
    continueAccountDeletion(
      journal,
      async () => {
        calls++;
        throw new Error('network failure');
      },
      { retry: true },
    ),
    /network failure/,
  );
  assert.equal(calls, 1);
  assert.deepEqual(readDeletionJournal(local, 'owner'), journal);
});
