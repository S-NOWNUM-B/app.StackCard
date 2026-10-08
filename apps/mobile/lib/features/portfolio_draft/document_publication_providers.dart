import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import 'domain/document_publication.dart';
import 'domain/portfolio_sync.dart';
import 'portfolio_draft_providers.dart';
import 'presentation/portfolio_draft_controller.dart';

final documentPublicationRepositoryFactoryProvider =
    Provider<DocumentPublicationRepository? Function(String uid)>(
      (ref) =>
          (_) => null,
    );

final documentPublicationRepositoryProvider =
    Provider<DocumentPublicationRepository?>((ref) {
      if (ref.watch(accountAuthRepositoryProvider) == null) return null;
      final session = ref.watch(accountSessionProvider);
      if (session.isLoading || session.hasError || !session.hasValue) {
        return null;
      }
      final uid = session.value?.uid;
      return uid == null
          ? null
          : ref.watch(documentPublicationRepositoryFactoryProvider)(uid);
    });

final documentPublicationOperationStoreFactoryProvider =
    Provider<DocumentPublicationOperationStore Function(String uid)>((ref) {
      final stores = <String, DocumentPublicationOperationStore>{};
      return (uid) => stores.putIfAbsent(uid, _MemoryOperationStore.new);
    });

final documentLinkActionsProvider = Provider<DocumentLinkActions?>(
  (ref) => null,
);

final documentPublicationControllerProvider =
    NotifierProvider<DocumentPublicationController, DocumentPublicationState>(
      DocumentPublicationController.new,
    );

/// Ни lastSyncedAt, ни local Save сами по себе не разрешают Publish.
final documentPublicationExpectedMutationProvider = Provider<String?>((ref) {
  final draft = ref.watch(portfolioDraftControllerProvider);
  final sync = ref.watch(portfolioSyncStateProvider);
  if (!draft.canEdit ||
      draft.saving ||
      draft.failure != null ||
      draft.hasUnsavedChanges ||
      draft.remoteUpdateAvailable ||
      draft.draft == null ||
      draft.draft!.pendingSync ||
      sync.status != PortfolioSyncStatus.synced) {
    return null;
  }
  return sync.confirmedMutationId;
});

final class DocumentPublicationState {
  const DocumentPublicationState({
    this.inventory,
    this.loading = true,
    this.busy = false,
    this.pending,
    this.failure,
  });

  final DocumentPublicationInventory? inventory;
  final bool loading;
  final bool busy;
  final DocumentPublicationMutation? pending;
  final DocumentPublicationFailure? failure;

  DocumentPublication? forDocument(String id) => inventory?.forDocument(id);
  bool get canMutate =>
      inventory != null &&
      !loading &&
      !busy &&
      pending == null &&
      (failure == null ||
          {
            DocumentPublicationFailureKind.conflict,
            DocumentPublicationFailureKind.invalidData,
          }.contains(failure?.kind));
}

class DocumentPublicationController extends Notifier<DocumentPublicationState> {
  int _generation = 0;
  DocumentPublicationRepository? _repository;
  DocumentPublicationOperationStore? _store;

  @override
  DocumentPublicationState build() {
    _repository = ref.watch(documentPublicationRepositoryProvider);
    final session = ref.watch(accountSessionProvider);
    final uid = !session.isLoading && !session.hasError
        ? session.value?.uid
        : null;
    _store = uid == null
        ? null
        : ref.watch(documentPublicationOperationStoreFactoryProvider)(uid);
    final generation = ++_generation;
    ref.onDispose(() => ++_generation);
    Future<void>.microtask(() {
      if (ref.mounted && generation == _generation) load();
    });
    return const DocumentPublicationState();
  }

  bool _active(int generation) => ref.mounted && generation == _generation;

  Future<void> load() async {
    if (state.busy) return;
    final repository = _repository;
    final store = _store;
    if (repository == null || store == null) {
      state = const DocumentPublicationState(loading: false);
      return;
    }
    final generation = _generation;
    state = DocumentPublicationState(
      inventory: state.inventory,
      loading: true,
      pending: state.pending,
    );
    DocumentPublicationMutation? pending = state.pending;
    try {
      pending = await store.read();
      final inventory = await repository.inventory();
      if (!_active(generation)) return;
      for (final item in inventory.publications.where(
        (item) => item.visibility == DocumentPublicationVisibility.deleted,
      )) {
        await _reconcileDeletion(item.documentId, generation);
      }
      if (!_active(generation)) return;
      state = DocumentPublicationState(
        inventory: inventory,
        loading: false,
        pending: pending,
        failure: pending == null
            ? null
            : const DocumentPublicationFailure(
                DocumentPublicationFailureKind.unknown,
              ),
      );
    } on Object catch (error) {
      if (!_active(generation)) return;
      state = DocumentPublicationState(
        inventory: state.inventory,
        loading: false,
        pending: pending,
        failure: _failure(error),
      );
    }
  }

  Future<bool> perform({
    required DocumentPublicationAction action,
    required String documentId,
  }) async {
    final repository = _repository;
    final store = _store;
    final expectedMutation = ref.read(
      documentPublicationExpectedMutationProvider,
    );
    if (repository == null ||
        store == null ||
        !state.canMutate ||
        (action == DocumentPublicationAction.deleteDocument &&
            ref.read(portfolioDraftControllerProvider).saving) ||
        (action == DocumentPublicationAction.publish &&
            expectedMutation == null)) {
      return false;
    }
    final mutation = DocumentPublicationMutation(
      action: action,
      operationId: List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      documentId: documentId,
      expectedMutationId: expectedMutation,
      expectedVersion: state.forDocument(documentId)?.version ?? 0,
      expectedGeneration: state.inventory!.lifecycleGeneration,
    );
    final generation = _generation;
    state = DocumentPublicationState(
      inventory: state.inventory,
      loading: false,
      busy: true,
      pending: mutation,
    );
    try {
      await store.write(mutation);
      if (!_active(generation)) return false;
    } on Object catch (error) {
      if (_active(generation)) {
        state = DocumentPublicationState(
          inventory: state.inventory,
          loading: false,
          failure: _failure(error),
        );
      }
      return false;
    }
    return _send(mutation, generation);
  }

  /// Никакого нового operationId после неизвестного результата.
  Future<bool> retryOperation() async {
    final pending = state.pending;
    if (pending == null || state.busy || state.loading || _repository == null) {
      return false;
    }
    state = DocumentPublicationState(
      inventory: state.inventory,
      loading: false,
      busy: true,
      pending: pending,
    );
    return _send(pending, _generation);
  }

  Future<bool> checkOperation() async {
    final pending = state.pending;
    final repository = _repository;
    if (pending == null || repository == null || state.busy) return false;
    final generation = _generation;
    state = DocumentPublicationState(
      inventory: state.inventory,
      loading: false,
      busy: true,
      pending: pending,
    );
    DocumentPublicationOperation result;
    try {
      result = await repository.status(pending.operationId);
    } on Object catch (error) {
      return _handleFailure(pending, generation, _failure(error));
    }
    try {
      return await _complete(result, pending, generation);
    } on Object catch (error) {
      if (_active(generation)) _retainUnknown(pending, _failure(error));
      return false;
    }
  }

  Future<bool> _send(
    DocumentPublicationMutation mutation,
    int generation,
  ) async {
    DocumentPublicationOperation result;
    try {
      result = await _repository!.mutate(mutation);
    } on Object catch (error) {
      return _handleFailure(mutation, generation, _failure(error));
    }
    try {
      return await _complete(result, mutation, generation);
    } on Object catch (error) {
      if (_active(generation)) _retainUnknown(mutation, _failure(error));
      return false;
    }
  }

  Future<bool> _handleFailure(
    DocumentPublicationMutation mutation,
    int generation,
    DocumentPublicationFailure failure,
  ) async {
    if (!_active(generation)) return false;
    if ({
      DocumentPublicationFailureKind.unknown,
      DocumentPublicationFailureKind.unavailable,
      DocumentPublicationFailureKind.storage,
    }.contains(failure.kind)) {
      _retainUnknown(mutation, failure);
    } else {
      try {
        final inventory = await _repository!.inventory();
        if (!_active(generation)) return false;
        await _store!.clear();
        if (!_active(generation)) return false;
        state = DocumentPublicationState(
          inventory: inventory,
          loading: false,
          failure: failure,
        );
      } on Object catch (refreshError) {
        if (_active(generation)) {
          _retainUnknown(mutation, _failure(refreshError));
        }
      }
    }
    return false;
  }

  Future<bool> _complete(
    DocumentPublicationOperation result,
    DocumentPublicationMutation mutation,
    int generation,
  ) async {
    if (!_active(generation)) return false;
    if (result.outcome != DocumentPublicationOutcome.completed ||
        result.operationId != mutation.operationId ||
        result.action != mutation.action.name ||
        result.publication?.documentId != mutation.documentId) {
      _retainUnknown(
        mutation,
        const DocumentPublicationFailure(
          DocumentPublicationFailureKind.unknown,
        ),
      );
      return false;
    }
    final publication = result.publication!;
    // Status возвращает текущую публикацию: другой девайс мог уже отозвать её.
    // Удалённый documentId, в отличие от Publish/Unpublish, необратим.
    if (mutation.action == DocumentPublicationAction.deleteDocument &&
        publication.visibility != DocumentPublicationVisibility.deleted) {
      _retainUnknown(
        mutation,
        const DocumentPublicationFailure(
          DocumentPublicationFailureKind.unknown,
        ),
      );
      return false;
    }
    if (mutation.action == DocumentPublicationAction.deleteDocument) {
      await _reconcileDeletion(mutation.documentId, generation);
    }
    if (!_active(generation)) return false;
    final inventory = await _repository!.inventory();
    if (!_active(generation)) return false;
    await _store!.clear();
    if (!_active(generation)) return false;
    state = DocumentPublicationState(inventory: inventory, loading: false);
    return true;
  }

  Future<void> _reconcileDeletion(String id, int generation) async {
    if (!_active(generation)) return;
    final repository = ref.read(portfolioDraftRepositoryProvider);
    ref
        .read(portfolioDraftControllerProvider.notifier)
        .acceptConfirmedDocumentDeletion(id, expectedRepository: repository);
  }

  void _retainUnknown(
    DocumentPublicationMutation mutation,
    DocumentPublicationFailure failure,
  ) {
    state = DocumentPublicationState(
      inventory: state.inventory,
      loading: false,
      pending: mutation,
      failure: failure,
    );
  }

  static DocumentPublicationFailure _failure(Object error) =>
      error is DocumentPublicationFailure
      ? error
      : const DocumentPublicationFailure(
          DocumentPublicationFailureKind.unavailable,
        );
}

class _MemoryOperationStore implements DocumentPublicationOperationStore {
  DocumentPublicationMutation? _mutation;
  @override
  Future<DocumentPublicationMutation?> read() async => _mutation;
  @override
  Future<void> write(DocumentPublicationMutation mutation) async =>
      _mutation = mutation;
  @override
  Future<void> clear() async => _mutation = null;
}
