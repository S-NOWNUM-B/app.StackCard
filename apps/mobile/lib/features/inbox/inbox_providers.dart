import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import 'domain/contact_request.dart';

final inboxRepositoryFactoryProvider =
    Provider<InboxRepository? Function(String uid)>(
      (ref) =>
          (_) => null,
    );
final inboxRepositoryProvider = Provider<InboxRepository?>((ref) {
  if (ref.watch(accountAuthRepositoryProvider) == null) return null;
  final session = ref.watch(accountSessionProvider);
  final uid = !session.isLoading && !session.hasError
      ? session.value?.uid
      : null;
  if (uid == null) return null;
  final repository = ref.watch(inboxRepositoryFactoryProvider)(uid);
  return repository?.ownerUid == uid ? repository : null;
});

final inboxRequestProvider = FutureProvider.autoDispose
    .family<ContactRequest?, String>((ref, id) async {
      final repository = ref.watch(inboxRepositoryProvider);
      if (repository == null) {
        throw const InboxFailure(InboxFailureKind.unavailable);
      }
      final result = await repository.get(id);
      if (!ref.mounted) {
        throw const InboxFailure(InboxFailureKind.unauthenticated);
      }
      return result;
    }, retry: (_, _) => null);

final inboxControllerProvider = NotifierProvider<InboxController, InboxState>(
  InboxController.new,
);

final class InboxState {
  const InboxState({
    this.requests = const [],
    this.cursor,
    this.loading = false,
    this.loadingMore = false,
    this.loaded = false,
    this.failure,
  });
  final List<ContactRequest> requests;
  final InboxCursor? cursor;
  final bool loading, loadingMore, loaded;
  final InboxFailure? failure;
}

class InboxController extends Notifier<InboxState> {
  int _generation = 0;
  @override
  InboxState build() {
    ref.watch(inboxRepositoryProvider);
    final generation = ++_generation;
    ref.onDispose(() => ++_generation);
    Future.microtask(() {
      if (ref.mounted && generation == _generation) load();
    });
    return const InboxState(loading: true);
  }

  Future<void> load({bool more = false}) async {
    if (more && (state.loading || state.loadingMore || state.cursor == null)) {
      return;
    }
    final repository = ref.read(inboxRepositoryProvider);
    final generation = ++_generation;
    final old = state;
    state = InboxState(
      requests: more ? old.requests : const [],
      cursor: old.cursor,
      loading: !more,
      loadingMore: more,
      loaded: old.loaded,
    );
    try {
      if (repository == null) {
        throw const InboxFailure(InboxFailureKind.unavailable);
      }
      final result = await repository.list(after: more ? old.cursor : null);
      if (!ref.mounted || generation != _generation) return;
      final byId = {
        for (final item in [
          ...(more ? old.requests : <ContactRequest>[]),
          ...result.requests,
        ])
          item.requestId: item,
      };
      state = InboxState(
        requests: List.unmodifiable(byId.values),
        cursor: result.nextCursor,
        loaded: true,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = InboxState(
        requests: old.requests,
        cursor: old.cursor,
        loaded: old.loaded,
        failure: error is InboxFailure
            ? error
            : const InboxFailure(InboxFailureKind.unavailable),
      );
    }
  }
}
