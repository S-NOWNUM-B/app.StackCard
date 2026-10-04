import 'dart:io';
import 'dart:convert';

import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late LocalDraftAccounts accounts;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'stackcard-cloud-transfer-',
    );
    box = await Hive.openBox<dynamic>('cloud_transfer', path: directory.path);
    accounts = LocalDraftAccounts(box);
    await accounts.guestRepository.saveNotes('Private guest snapshot');
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  PortfolioSyncRecord acknowledged(PortfolioDraft source, String mutation) =>
      PortfolioSyncRecord(
        mutationId: mutation,
        pending: false,
        draft: PortfolioDraft(
          notes: source.notes,
          revision: source.revision,
          updatedAt: source.updatedAt,
          pendingSync: false,
          content: source.content,
        ),
      );

  test(
    'occupied cloud claim retains source and releases fresh reservation',
    () async {
      await expectLater(
        accounts.transferGuestToUser(
          'owner',
          beforeCommit: (_, _) async {
            throw const PortfolioDraftFailure(
              PortfolioDraftFailureKind.conflict,
            );
          },
        ),
        throwsA(
          isA<PortfolioDraftFailure>().having(
            (failure) => failure.kind,
            'kind',
            PortfolioDraftFailureKind.conflict,
          ),
        ),
      );
      expect(await accounts.hasPendingTransferForUser('owner'), isFalse);
      expect(
        (await accounts.guestRepository.read())?.notes,
        'Private guest snapshot',
      );
      expect(await accounts.repositoryForUser('owner').read(), isNull);
    },
  );

  test(
    'lost remote acknowledgement reserves source for same owner after restart',
    () async {
      String? firstMutation;
      await expectLater(
        accounts.transferGuestToUser(
          'owner',
          beforeCommit: (_, mutation) async {
            firstMutation = mutation;
            throw const PortfolioDraftFailure(
              PortfolioDraftFailureKind.unavailable,
            );
          },
        ),
        throwsA(isA<PortfolioDraftFailure>()),
      );
      await box.close();
      box = await Hive.openBox<dynamic>('cloud_transfer', path: directory.path);
      accounts = LocalDraftAccounts(box);
      expect(await accounts.hasPendingTransferForUser('owner'), isTrue);
      await expectLater(
        accounts.transferGuestToUser('foreign'),
        throwsA(isA<PortfolioDraftFailure>()),
      );
      await accounts.transferGuestToUser(
        'owner',
        beforeCommit: (source, mutation) async {
          expect(mutation, firstMutation);
          return acknowledged(source, mutation);
        },
      );
      expect(await accounts.hasPendingTransferForUser('owner'), isFalse);
      expect(await accounts.hasGuestDraft(), isFalse);
      expect(
        (await accounts.repositoryForUser('owner').read())?.notes,
        'Private guest snapshot',
      );
    },
  );

  test(
    'ACK metadata is durable before source cleanup without nesting Box queue',
    () async {
      await accounts
          .transferGuestToUser(
            'owner',
            beforeCommit: (source, mutation) async {
              expect(box.containsKey('draft'), isTrue);
              return acknowledged(source, mutation);
            },
          )
          .timeout(const Duration(seconds: 3));
      final record = await HivePortfolioSyncMetadataStore(
        box,
        ownerUid: 'owner',
      ).read();
      expect(record?.pending, isFalse);
      expect(record?.draft.notes, 'Private guest snapshot');
      expect(record?.draft.revision, 1);
      expect(record?.mutationId, 'guest-transfer-0-1');
      expect(await accounts.hasGuestDraft(), isFalse);
    },
  );

  test(
    'newer cloud winner releases an unfinished lost-ACK transfer safely',
    () async {
      PortfolioSyncRecord? savedAck;
      await expectLater(
        accounts.transferGuestToUser(
          'owner',
          beforeCommit: (source, mutation) async {
            savedAck = acknowledged(source, mutation);
            throw const PortfolioDraftFailure(
              PortfolioDraftFailureKind.unavailable,
            );
          },
        ),
        throwsA(isA<PortfolioDraftFailure>()),
      );
      // The ACK write may have succeeded immediately before journal persistence failed.
      await HivePortfolioSyncMetadataStore(
        box,
        ownerUid: 'owner',
      ).write(savedAck!);
      await box.close();
      box = await Hive.openBox<dynamic>('cloud_transfer', path: directory.path);
      accounts = LocalDraftAccounts(box);
      await expectLater(
        accounts.transferGuestToUser(
          'owner',
          beforeCommit: (_, _) async {
            throw const PortfolioDraftFailure(
              PortfolioDraftFailureKind.conflict,
            );
          },
        ),
        throwsA(isA<PortfolioDraftFailure>()),
      );
      expect(await accounts.hasPendingTransferForUser('owner'), isFalse);
      expect(
        (await accounts.guestRepository.read())?.notes,
        'Private guest snapshot',
      );
      expect(await accounts.repositoryForUser('owner').read(), isNull);
      expect(
        await HivePortfolioSyncMetadataStore(box, ownerUid: 'owner').read(),
        isNull,
      );
    },
  );

  test(
    'Phase 7 already-copied destination finishes cleanup after upgrade',
    () async {
      final source = box.get('draft') as String;
      const ownerKey = 'draft.user.b3duZXI';
      await box.put(ownerKey, source);
      await box.put(
        'draft.guest.transfer',
        jsonEncode({
          'schemaVersion': 1,
          'owner': ownerKey,
          'raw': source,
          'backup': null,
          'generation': 0,
          'committed': false,
        }),
      );
      await accounts.transferGuestToUser(
        'owner',
        beforeCommit: (_, _) async {
          fail(
            'An already committed Phase 7 local transfer is not a fresh cloud claim',
          );
        },
      );
      expect(await accounts.hasPendingTransferForUser('owner'), isFalse);
      expect(await accounts.hasGuestDraft(), isFalse);
      final original = await accounts.repositoryForUser('owner').read();
      expect(original?.notes, 'Private guest snapshot');
      expect(original?.pendingSync, isTrue);
    },
  );

  test('mismatched ACK retains original and does not create target', () async {
    await expectLater(
      accounts.transferGuestToUser(
        'owner',
        beforeCommit: (source, mutation) async {
          return PortfolioSyncRecord(
            mutationId: mutation,
            pending: false,
            draft: PortfolioDraft(
              notes: 'Different snapshot',
              revision: source.revision,
              updatedAt: source.updatedAt,
              pendingSync: false,
            ),
          );
        },
      ),
      throwsA(
        isA<PortfolioDraftFailure>().having(
          (failure) => failure.kind,
          'kind',
          PortfolioDraftFailureKind.corrupted,
        ),
      ),
    );
    expect(box.containsKey('draft'), isTrue);
    expect(await accounts.hasPendingTransferForUser('owner'), isTrue);
  });
}
