import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import 'document_publication_providers.dart';
import 'domain/developer_card.dart';

final developerCardRepositoryFactoryProvider =
    Provider<DeveloperCardRepository? Function(String uid)>(
      (ref) =>
          (_) => null,
    );
final developerCardRepositoryProvider = Provider<DeveloperCardRepository?>((
  ref,
) {
  if (ref.watch(accountAuthRepositoryProvider) == null) return null;
  final session = ref.watch(accountSessionProvider);
  if (session.isLoading || session.hasError || session.value == null) {
    return null;
  }
  final uid = session.value!.uid;
  final repository = ref.watch(developerCardRepositoryFactoryProvider)(uid);
  return repository?.ownerUid == uid ? repository : null;
});

final developerCardProvider = StreamProvider.autoDispose
    .family<DeveloperCard, String>((ref, documentId) {
      final repository = ref.watch(developerCardRepositoryProvider);
      final state = ref.watch(documentPublicationControllerProvider);
      if (state.pending != null) {
        return Stream.error(
          const DeveloperCardFailure(DeveloperCardFailureKind.unknown),
        );
      }
      if (repository == null ||
          state.inventory == null ||
          state.loading ||
          state.busy ||
          state.failure != null) {
        return Stream.error(
          const DeveloperCardFailure(DeveloperCardFailureKind.unavailable),
        );
      }
      final publication = state.forDocument(documentId);
      if (publication == null) {
        return Stream.error(
          const DeveloperCardFailure(DeveloperCardFailureKind.unpublished),
        );
      }
      return repository.watch(publication);
    }, retry: (_, _) => null);
