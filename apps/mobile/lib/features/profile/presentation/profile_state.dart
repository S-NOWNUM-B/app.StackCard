import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile.dart';
import '../profile_dependencies.dart';
import '../../portfolio_draft/portfolio_draft.dart';
import 'portfolio_profile_projection.dart';

final profileProvider = FutureProvider<Profile>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  ref.watch(portfolioDraftRepositoryProvider);
  // Подписка на readiness ставится после первого read: его завершение не
  // должно инвалидировать ожидающий Future и повторно вызывать demo source.
  try {
    await ref.read(portfolioDraftControllerProvider.notifier).ensureLoaded();
  } on PortfolioDraftFailure {
    if (ref.mounted) {
      ref.watch(
        portfolioDraftControllerProvider.select(
          (state) => (
            state.loaded,
            state.loaded ? null : state.failure,
            state.content,
          ),
        ),
      );
    }
    rethrow;
  }
  if (!ref.mounted) throw StateError('Profile read was cancelled');
  final (_, _, content) = ref.watch(
    portfolioDraftControllerProvider.select(
      (state) =>
          (state.loaded, state.loaded ? null : state.failure, state.content),
    ),
  );
  return content == null
      ? repository.getProfile()
      : projectPortfolioProfile(content);
}, retry: (_, _) => null);
