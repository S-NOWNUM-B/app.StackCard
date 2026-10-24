import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lost journal clear after Publish ACK keeps recovery and status retry never republishes', () async {
    final repository = _Repository();
    final store = _Store()..failClear = true;
    final fixture = await _Fixture.create(repository, store: store);
    expect(
      await fixture.controller.perform(
        action: DocumentPublicationAction.publish,
        documentId: 'document',
      ),
      isFalse,
    );
    final mutation = store.pending!;
    expect(fixture.state.pending, same(mutation));
    expect(fixture.state.failure?.kind, DocumentPublicationFailureKind.storage);
    expect(fixture.state.canMutate, isFalse);
    expect(repository.mutations, [mutation]);
    store.failClear = false;
    repository.statusResult = DocumentPublicationOperation(
      outcome: DocumentPublicationOutcome.completed,
      operationId: mutation.operationId,
      action: mutation.action.name,
      publication: repository.publication,
    );
    expect(await fixture.controller.checkOperation(), isTrue);
    expect(repository.mutations, [mutation]);
    expect(store.pending, isNull);
    expect(fixture.state.pending, isNull);
    expect(fixture.state.forDocument('document')!.shareableUrl, isNotNull);
  });

  for (final wrongProof in ['operationId', 'documentId']) {
    test(
      'foreign $wrongProof in completed ACK never confirms Publish or clears recovery',
      () async {
        final repository = _Repository();
        final fixture = await _Fixture.create(repository);
        repository.send = (mutation) async => DocumentPublicationOperation(
          outcome: DocumentPublicationOutcome.completed,
          operationId: wrongProof == 'operationId'
              ? 'foreign-operation'
              : mutation.operationId,
          action: mutation.action.name,
          publication: _publication(
            DocumentPublicationVisibility.published,
            documentId: wrongProof == 'documentId'
                ? 'foreign-document'
                : 'document',
          ),
        );
        expect(
          await fixture.controller.perform(
            action: DocumentPublicationAction.publish,
            documentId: 'document',
          ),
          isFalse,
        );
        expect(fixture.store.pending, same(repository.mutations.single));
        expect(fixture.state.pending, same(fixture.store.pending));
        expect(
          fixture.state.failure?.kind,
          DocumentPublicationFailureKind.unknown,
        );
        expect(fixture.state.canMutate, isFalse);
      },
    );
  }

  test(
    'Delete ACK without a tombstone never removes private document',
    () async {
      final repository = _Repository();
      final fixture = await _Fixture.create(repository);
      repository.send = (mutation) async => DocumentPublicationOperation(
        outcome: DocumentPublicationOutcome.completed,
        operationId: mutation.operationId,
        action: mutation.action.name,
        publication: repository.publication,
      );
      expect(
        await fixture.controller.perform(
          action: DocumentPublicationAction.deleteDocument,
          documentId: 'document',
        ),
        isFalse,
      );
      expect(fixture.store.pending, same(repository.mutations.single));
      expect(
        fixture.state.failure?.kind,
        DocumentPublicationFailureKind.unknown,
      );
      expect(
        fixture.container
            .read(portfolioDraftControllerProvider)
            .content!
            .documents
            .map((item) => item.id),
        contains('document'),
      );
      expect(fixture.draftRepository.saveCalls, 0);
    },
  );

  test('owner switch while journal is writing prevents POST and preserves only old owner recovery', () async {
    final repository = _Repository();
    final store = _Store();
    final fixture = await _Fixture.create(repository, store: store);
    final release = Completer<void>();
    store.beforeWrite = () => release.future;
    final publishing = fixture.controller.perform(
      action: DocumentPublicationAction.publish,
      documentId: 'document',
    );
    await _flush(fixture.container);
    expect(fixture.state.busy, isTrue);
    expect(repository.mutations, isEmpty);
    final nextRepository = _Repository();
    final nextStore = _Store();
    await _replaceOwner(fixture, nextRepository, nextStore);
    release.complete();
    expect(await publishing, isFalse);
    expect(store.pending, isNotNull);
    expect(nextStore.pending, isNull);
    expect(repository.mutations, isEmpty);
    expect(nextRepository.mutations, isEmpty);
    expect(fixture.state.pending, isNull);
  });

  test('old owner inventory cannot restore a revoked public URL after account switch', () async {
    final repository = _Repository();
    final fixture = await _Fixture.create(repository);
    final delayed = Completer<DocumentPublicationInventory>();
    repository.readInventory = () => delayed.future;
    final loading = fixture.controller.load();
    await _flush(fixture.container);
    final nextRepository = _Repository()
      ..publication = _publication(DocumentPublicationVisibility.unpublished);
    await _replaceOwner(fixture, nextRepository, _Store());
    expect(fixture.state.forDocument('document')!.shareableUrl, isNull);
    delayed.complete(
      DocumentPublicationInventory(
        publications: [repository.publication],
        lifecycleGeneration: 3,
      ),
    );
    await loading;
    expect(fixture.state.loading, isFalse);
    expect(
      fixture.state.forDocument('document')!.visibility,
      DocumentPublicationVisibility.unpublished,
    );
    expect(fixture.state.forDocument('document')!.shareableUrl, isNull);
    expect(fixture.state.failure, isNull);
    expect(repository.mutations, isEmpty);
    expect(nextRepository.mutations, isEmpty);
  });

  test('automatic and explicit loads share one inventory and refresh after mutation', () async {
    final repository = _Repository();
    final delayed = Completer<DocumentPublicationInventory>();
    repository.readInventory = () => delayed.future;
    final fixture = await _Fixture.create(repository);
    expect(repository.inventoryCalls, 1);
    final first = fixture.controller.load();
    final second = fixture.controller.load();
    expect(second, same(first));
    await _flush(fixture.container);
    expect(repository.inventoryCalls, 1);
    expect(fixture.state.loading, isTrue);
    delayed.complete(
      DocumentPublicationInventory(
        publications: [repository.publication],
        lifecycleGeneration: 3,
      ),
    );
    await Future.wait([first, second]);
    expect(fixture.state.loading, isFalse);
    repository.readInventory = null;
    expect(
      await fixture.controller.perform(
        action: DocumentPublicationAction.unpublish,
        documentId: 'document',
      ),
      isTrue,
    );
    expect(repository.inventoryCalls, 2);
    expect(fixture.state.forDocument('document')!.shareableUrl, isNull);
    await fixture.controller.load();
    expect(repository.inventoryCalls, 3);
    expect(
      fixture.state.forDocument('document')!.visibility,
      DocumentPublicationVisibility.unpublished,
    );
  });

  for (final replyWhileBusy in [true, false]) {
    test(
      'late inventory preserves recovery when busy=$replyWhileBusy',
      () async {
        final repository = _Repository();
        final fixture = await _Fixture.create(
          repository,
          store: _Store()..pending = _pending,
        );
        final delayed = Completer<DocumentPublicationInventory>();
        final stale = DocumentPublicationInventory(
          publications: [repository.publication],
          lifecycleGeneration: 3,
        );
        repository.readInventory = () => delayed.future;
        final loading = fixture.controller.load();
        await _flush(fixture.container);
        final status = Completer<DocumentPublicationOperation>();
        repository.readStatus = (_) => status.future;
        final checking = fixture.controller.checkOperation();
        await _flush(fixture.container);
        if (replyWhileBusy) {
          delayed.complete(stale);
          await loading;
          expect(fixture.state.busy, isTrue);
          expect(fixture.state.pending, same(_pending));
        }
        repository.readInventory = null;
        repository.publication = _publication(
          DocumentPublicationVisibility.unpublished,
        );
        status.complete(
          DocumentPublicationOperation(
            outcome: DocumentPublicationOutcome.completed,
            operationId: _pending.operationId,
            action: _pending.action.name,
            publication: repository.publication,
          ),
        );
        expect(await checking, isTrue);
        expect(fixture.state.busy, isFalse);
        expect(fixture.state.pending, isNull);
        expect(fixture.store.pending, isNull);
        expect(
          fixture.state.forDocument('document')!.visibility,
          DocumentPublicationVisibility.unpublished,
        );
        await fixture.controller.load();
        if (!replyWhileBusy) {
          delayed.complete(stale);
          await loading;
        }
        expect(fixture.state.pending, isNull);
        expect(fixture.state.forDocument('document')!.shareableUrl, isNull);
      },
    );
  }

  test(
    'Publish requires exact ACK; withdrawal works with unsaved local changes',
    () async {
      final repository = _Repository();
      final fixture = await _Fixture.create(repository, confirmed: false);
      fixture.container
          .read(portfolioDraftControllerProvider.notifier)
          .updateNotes('unsaved private notes');
      expect(
        await fixture.controller.perform(
          action: DocumentPublicationAction.publish,
          documentId: 'document',
        ),
        isFalse,
      );
      expect(repository.mutations, isEmpty);
      expect(
        await fixture.controller.perform(
          action: DocumentPublicationAction.unpublish,
          documentId: 'document',
        ),
        isTrue,
      );
      expect(repository.mutations.single.expectedMutationId, isNull);
      expect(
        repository.mutations.single.toJson().containsKey('expectedMutationId'),
        isFalse,
      );
      expect(
        fixture.container.read(portfolioDraftControllerProvider).notes,
        'unsaved private notes',
      );
    },
  );

  test('unknown result keeps durable operation and retry reuses identical CAS request', () async {
    final repository = _Repository();
    final fixture = await _Fixture.create(repository);
    repository.send = (mutation) async {
      expect(fixture.store.pending, same(mutation));
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.unknown,
      );
    };
    expect(
      await fixture.controller.perform(
        action: DocumentPublicationAction.publish,
        documentId: 'document',
      ),
      isFalse,
    );
    final pending = fixture.store.pending!;
    expect(fixture.state.pending, same(pending));
    expect(fixture.state.canMutate, isFalse);
    repository.send = repository.complete;
    expect(await fixture.controller.retryOperation(), isTrue);
    expect(repository.mutations, [pending, pending]);
    expect(fixture.store.pending, isNull);
    expect(fixture.state.forDocument('document')!.shareableUrl, isNotNull);
  });

  test('lost Publish ACK followed by another device Unpublish adopts current state', () async {
    final repository = _Repository();
    final store = _Store()..pending = _pending;
    repository.publication = _publication(
      DocumentPublicationVisibility.unpublished,
    );
    repository.statusResult = DocumentPublicationOperation(
      outcome: DocumentPublicationOutcome.completed,
      operationId: _pending.operationId,
      action: 'publish',
      publication: repository.publication,
      lifecycleGeneration: 4,
    );
    final fixture = await _Fixture.create(repository, store: store);
    expect(fixture.state.pending, same(_pending));
    expect(await fixture.controller.checkOperation(), isTrue);
    expect(store.pending, isNull);
    expect(fixture.state.pending, isNull);
    expect(fixture.state.canMutate, isTrue);
    expect(
      fixture.state.forDocument('document')!.visibility,
      DocumentPublicationVisibility.unpublished,
    );
    expect(fixture.state.forDocument('document')!.shareableUrl, isNull);
  });

  test(
    'failed operation keeps journal until authoritative inventory can refresh',
    () async {
      final repository = _Repository();
      final fixture = await _Fixture.create(
        repository,
        store: _Store()..pending = _pending,
      );
      repository.statusFailure = const DocumentPublicationFailure(
        DocumentPublicationFailureKind.conflict,
      );
      repository.inventoryFailure = const DocumentPublicationFailure(
        DocumentPublicationFailureKind.unavailable,
      );
      expect(await fixture.controller.checkOperation(), isFalse);
      expect(fixture.store.pending, same(_pending));
      expect(fixture.state.canMutate, isFalse);
      repository.inventoryFailure = null;
      expect(await fixture.controller.checkOperation(), isFalse);
      expect(fixture.store.pending, isNull);
      expect(
        fixture.state.failure!.kind,
        DocumentPublicationFailureKind.conflict,
      );
      expect(fixture.state.canMutate, isTrue);
    },
  );

  test(
    'completed response with wrong action proof never clears journal',
    () async {
      final repository = _Repository();
      final fixture = await _Fixture.create(
        repository,
        store: _Store()..pending = _pending,
      );
      repository.statusResult = DocumentPublicationOperation(
        outcome: DocumentPublicationOutcome.completed,
        operationId: _pending.operationId,
        action: 'deleteAccount',
        publication: repository.publication,
      );
      expect(await fixture.controller.checkOperation(), isFalse);
      expect(fixture.store.pending, same(_pending));
      expect(fixture.state.pending, same(_pending));
    },
  );

  test(
    'owner transition ignores previous delayed publication response',
    () async {
      final repository = _Repository();
      final fixture = await _Fixture.create(repository);
      final pending = Completer<DocumentPublicationOperation>();
      repository.send = (_) => pending.future;
      final operation = fixture.controller.perform(
        action: DocumentPublicationAction.publish,
        documentId: 'document',
      );
      await _flush(fixture.container);
      final firstOperation = repository.mutations.single;
      final secondRepository = _Repository();
      final secondStore = _Store();
      fixture.container.updateOverrides([
        documentPublicationRepositoryProvider.overrideWithValue(
          secondRepository,
        ),
        documentPublicationOperationStoreFactoryProvider.overrideWithValue(
          (_) => secondStore,
        ),
        accountSessionProvider.overrideWithValue(
          const AsyncData(AuthUser(uid: 'second-owner')),
        ),
        portfolioDraftRepositoryProvider.overrideWithValue(
          fixture.draftRepository,
        ),
        portfolioSyncStateProvider.overrideWithValue(
          const PortfolioSyncState(
            status: PortfolioSyncStatus.synced,
            confirmedMutationId: 'saved-mutation',
          ),
        ),
      ]);
      await _flush(fixture.container);
      pending.complete(await repository.complete(firstOperation));
      expect(await operation, isFalse);
      expect(fixture.store.pending, same(firstOperation));
      expect(secondStore.pending, isNull);
      expect(secondRepository.mutations, isEmpty);
      expect(fixture.state.pending, isNull);
    },
  );

  test('delete receipt reconciles relations and retains unrelated private input without Save', () async {
    final repository = _Repository();
    final fixture = await _Fixture.create(repository);
    fixture.container
        .read(portfolioDraftControllerProvider.notifier)
        .updateNotes('new unsaved note');
    expect(
      await fixture.controller.perform(
        action: DocumentPublicationAction.deleteDocument,
        documentId: 'document',
      ),
      isTrue,
    );
    final state = fixture.container.read(portfolioDraftControllerProvider);
    expect(state.notes, 'new unsaved note');
    expect(state.content!.documents.map((document) => document.id), [
      'neighbour',
    ]);
    expect(state.content!.documents.single.attachedResumeId, isNull);
    expect(state.remoteUpdateAvailable, isTrue);
    expect(fixture.draftRepository.saveCalls, 0);
    expect(fixture.state.forDocument('document')!.shareableUrl, isNull);
  });

  test(
    'failed journal write prevents POST and corrupt recovery blocks mutation',
    () async {
      final repository = _Repository();
      final fixture = await _Fixture.create(repository);
      fixture.store.failWrite = true;
      expect(
        await fixture.controller.perform(
          action: DocumentPublicationAction.publish,
          documentId: 'document',
        ),
        isFalse,
      );
      expect(repository.mutations, isEmpty);
      expect(
        fixture.state.failure!.kind,
        DocumentPublicationFailureKind.storage,
      );
      fixture.store.failRead = true;
      await fixture.controller.load();
      expect(fixture.state.canMutate, isFalse);
      expect(
        await fixture.controller.perform(
          action: DocumentPublicationAction.publish,
          documentId: 'document',
        ),
        isFalse,
      );
      expect(repository.mutations, isEmpty);
    },
  );

  test(
    'in-flight Save blocks deletion POST and allows public withdrawal',
    () async {
      final repository = _Repository();
      final fixture = await _Fixture.create(repository);
      final pending = Completer<PortfolioDraft>();
      fixture.draftRepository.savePending = pending;
      final save = fixture.container
          .read(portfolioDraftControllerProvider.notifier)
          .saveDeveloperProfile(expectedRepository: fixture.draftRepository);
      await _flush(fixture.container);
      expect(
        fixture.container.read(portfolioDraftControllerProvider).saving,
        isTrue,
      );
      expect(
        await fixture.controller.perform(
          action: DocumentPublicationAction.deleteDocument,
          documentId: 'document',
        ),
        isFalse,
      );
      expect(repository.mutations, isEmpty);
      expect(
        await fixture.controller.perform(
          action: DocumentPublicationAction.unpublish,
          documentId: 'document',
        ),
        isTrue,
      );
      pending.complete(await fixture.draftRepository.read());
      expect(await save, isTrue);
      expect(
        repository.mutations.single.action,
        DocumentPublicationAction.unpublish,
      );
    },
  );
}

const _pending = DocumentPublicationMutation(
  action: DocumentPublicationAction.publish,
  operationId: 'pending-operation',
  documentId: 'document',
  expectedMutationId: 'saved-mutation',
  expectedVersion: 1,
  expectedGeneration: 2,
);

DocumentPublication _publication(
  DocumentPublicationVisibility visibility, {
  String documentId = 'document',
}) => DocumentPublication(
  documentId: documentId,
  publicId: 'public-document',
  version: 2,
  visibility: visibility,
  sourceMutationId: 'saved-mutation',
  url: visibility == DocumentPublicationVisibility.published
      ? Uri.parse('https://public.example/p/public-document')
      : null,
);

class _Fixture {
  _Fixture(this.container, this.store, this.draftRepository);
  final ProviderContainer container;
  final _Store store;
  final _DraftRepository draftRepository;
  DocumentPublicationController get controller =>
      container.read(documentPublicationControllerProvider.notifier);
  DocumentPublicationState get state =>
      container.read(documentPublicationControllerProvider);
  static Future<_Fixture> create(
    _Repository repository, {
    bool confirmed = true,
    _Store? store,
  }) async {
    final operationStore = store ?? _Store();
    final draft = _DraftRepository();
    final container = ProviderContainer(
      overrides: [
        documentPublicationRepositoryProvider.overrideWithValue(repository),
        documentPublicationOperationStoreFactoryProvider.overrideWithValue(
          (_) => operationStore,
        ),
        accountSessionProvider.overrideWithValue(
          const AsyncData(AuthUser(uid: 'owner')),
        ),
        portfolioDraftRepositoryProvider.overrideWithValue(draft),
        portfolioSyncStateProvider.overrideWithValue(
          PortfolioSyncState(
            status: PortfolioSyncStatus.synced,
            confirmedMutationId: confirmed ? 'saved-mutation' : null,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(portfolioDraftControllerProvider, (_, _) {});
    await container
        .read(portfolioDraftControllerProvider.notifier)
        .ensureLoaded();
    container.listen(documentPublicationControllerProvider, (_, _) {});
    await _flush(container);
    return _Fixture(container, operationStore, draft);
  }
}

Future<void> _flush(ProviderContainer container) async {
  for (var tick = 0; tick < 3; tick++) {
    await Future<void>.delayed(Duration.zero);
    await container.pump();
  }
}

Future<void> _replaceOwner(
  _Fixture fixture,
  _Repository repository,
  _Store store,
) async {
  fixture.container.updateOverrides([
    documentPublicationRepositoryProvider.overrideWithValue(repository),
    documentPublicationOperationStoreFactoryProvider.overrideWithValue(
      (_) => store,
    ),
    accountSessionProvider.overrideWithValue(
      const AsyncData(AuthUser(uid: 'second-owner')),
    ),
    portfolioDraftRepositoryProvider.overrideWithValue(fixture.draftRepository),
    portfolioSyncStateProvider.overrideWithValue(
      const PortfolioSyncState(
        status: PortfolioSyncStatus.synced,
        confirmedMutationId: 'saved-mutation',
      ),
    ),
  ]);
  await _flush(fixture.container);
}

class _Store implements DocumentPublicationOperationStore {
  DocumentPublicationMutation? pending;
  bool failWrite = false;
  bool failRead = false;
  bool failClear = false;
  Future<void> Function()? beforeWrite;
  @override
  Future<DocumentPublicationMutation?> read() async {
    if (failRead) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.storage,
      );
    }
    return pending;
  }

  @override
  Future<void> write(DocumentPublicationMutation mutation) async {
    await beforeWrite?.call();
    if (failWrite) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.storage,
      );
    }
    pending = mutation;
  }

  @override
  Future<void> clear() async {
    if (failClear) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.storage,
      );
    }
    pending = null;
  }
}

class _Repository implements DocumentPublicationRepository {
  DocumentPublication publication = _publication(
    DocumentPublicationVisibility.published,
  );
  final mutations = <DocumentPublicationMutation>[];
  Future<DocumentPublicationOperation> Function(DocumentPublicationMutation)?
  send;
  DocumentPublicationOperation? statusResult;
  DocumentPublicationFailure? statusFailure;
  DocumentPublicationFailure? inventoryFailure;
  int inventoryCalls = 0;
  Future<DocumentPublicationInventory> Function()? readInventory;
  Future<DocumentPublicationOperation> Function(String operationId)? readStatus;
  @override
  Future<DocumentPublicationInventory> inventory() async {
    inventoryCalls++;
    if (inventoryFailure case final failure?) throw failure;
    if (readInventory case final read?) return read();
    return DocumentPublicationInventory(
      publications: [publication],
      lifecycleGeneration: 3,
    );
  }

  @override
  Future<DocumentPublicationOperation> mutate(
    DocumentPublicationMutation mutation,
  ) async {
    mutations.add(mutation);
    return (send ?? complete)(mutation);
  }

  Future<DocumentPublicationOperation> complete(
    DocumentPublicationMutation mutation,
  ) async {
    publication = _publication(switch (mutation.action) {
      DocumentPublicationAction.publish =>
        DocumentPublicationVisibility.published,
      DocumentPublicationAction.unpublish =>
        DocumentPublicationVisibility.unpublished,
      DocumentPublicationAction.deleteDocument =>
        DocumentPublicationVisibility.deleted,
    });
    return DocumentPublicationOperation(
      outcome: DocumentPublicationOutcome.completed,
      operationId: mutation.operationId,
      action: mutation.action.name,
      publication: publication,
      lifecycleGeneration: 4,
    );
  }

  @override
  Future<DocumentPublicationOperation> status(String operationId) async {
    if (statusFailure case final failure?) throw failure;
    if (readStatus case final read?) return read(operationId);
    return statusResult ??
        DocumentPublicationOperation(
          outcome: DocumentPublicationOutcome.unknown,
          operationId: operationId,
        );
  }

  @override
  Future<DocumentPublicationOperation> deleteAccount({
    required String operationId,
    required int expectedGeneration,
    required String recoveryKey,
  }) async => throw UnimplementedError();
  @override
  Future<DocumentPublicationOperation> recoverAccountDeletion({
    required String ownerUid,
    required String operationId,
    required String recoveryKey,
    bool retry = false,
  }) async => throw UnimplementedError();
}

class _DraftRepository implements PortfolioDraftRepository {
  int saveCalls = 0;
  Completer<PortfolioDraft>? savePending;
  @override
  Future<PortfolioDraft> read() async {
    final date = DateTime.utc(2026, 10, 8);
    return PortfolioDraft(
      notes: '',
      revision: 1,
      updatedAt: date,
      pendingSync: false,
      content: PortfolioContent(
        documents: [
          PortfolioDocument(
            id: 'document',
            title: 'Resume',
            kind: PortfolioDocumentKind.resume,
            createdAt: date,
            updatedAt: date,
            content: PortfolioContent(),
          ),
          PortfolioDocument(
            id: 'neighbour',
            title: 'Portfolio',
            kind: PortfolioDocumentKind.portfolio,
            createdAt: date,
            updatedAt: date,
            content: PortfolioContent(),
            attachedResumeId: 'document',
          ),
        ],
      ),
    );
  }

  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    saveCalls++;
    if (savePending case final pending?) return pending.future;
    throw UnimplementedError();
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) async {
    saveCalls++;
    throw UnimplementedError();
  }
}
