import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../portfolio_draft/portfolio_draft.dart';
import 'domain/github_repository.dart';

/// Public browsing never opens a private draft before account/guest access.
final githubPortfolioDraftStateProvider = Provider<PortfolioDraftState?>((ref) {
  if (ref.watch(accountAuthRepositoryProvider) != null) {
    final session = ref.watch(accountSessionProvider);
    if (session.isLoading || session.hasError || !session.hasValue) return null;
    if (session.value == null && !ref.watch(guestAccessProvider)) return null;
  }
  return ref.watch(portfolioDraftControllerProvider);
});

GitHubProjectSource githubPortfolioSource(GitHubRepository repository) =>
    GitHubProjectSource(
      repositoryId: repository.id,
      name: repository.name,
      fullName: repository.fullName,
      htmlUrl: repository.htmlUrl,
      description: repository.description,
      language: repository.language,
      stars: repository.stars,
      forks: repository.forks,
      isFork: repository.isFork,
      archived: repository.archived,
      updatedAt: repository.updatedAt,
    );
