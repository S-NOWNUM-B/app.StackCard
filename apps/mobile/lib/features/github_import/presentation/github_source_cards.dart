import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../portfolio_draft/portfolio_draft.dart';
import '../github_portfolio_providers.dart';
import '../domain/github_profile.dart';
import '../domain/github_repository.dart';
import 'github_project_review_sheet.dart';
import 'github_import_controller.dart';

class GitHubProfileCard extends StatelessWidget {
  const GitHubProfileCard({super.key, required this.profile});

  final GitHubProfile profile;

  @override
  Widget build(BuildContext context) => StackCardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.name ?? profile.login,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        Text('@${profile.login}', style: Theme.of(context).textTheme.bodyLarge),
        if (profile.bio case final bio?) ...[
          const SizedBox(height: StackCardSpacing.lg),
          Text(bio, style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (profile.location case final location?) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(location, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: StackCardSpacing.lg),
        Text(
          context.strings.tr('github.publicRepos', {
            'count': profile.publicRepositories,
          }),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        GitHubSourceLink(url: profile.htmlUrl),
      ],
    ),
  );
}

class GitHubRepositoryCard extends StatelessWidget {
  const GitHubRepositoryCard({
    super.key,
    required this.repository,
    this.showDescription = true,
    this.validatedAt,
  });

  final GitHubRepository repository;
  final bool showDescription;
  final DateTime? validatedAt;

  @override
  Widget build(BuildContext context) => StackCardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(repository.name, style: Theme.of(context).textTheme.titleLarge),
        if (showDescription) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            repository.description ??
                context.strings.tr('github.noDescription'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
        const SizedBox(height: StackCardSpacing.lg),
        Wrap(
          spacing: StackCardSpacing.lg,
          runSpacing: StackCardSpacing.sm,
          children: [
            Text(
              repository.language ?? context.strings.tr('github.noLanguage'),
            ),
            Text('Stars: ${repository.stars}'),
            Text('Forks: ${repository.forks}'),
            if (repository.isFork) const Text('Fork'),
            if (repository.archived)
              Text(context.strings.tr('github.filter.archived')),
          ],
        ),
        const SizedBox(height: StackCardSpacing.lg),
        GitHubSourceLink(url: repository.htmlUrl),
        const SizedBox(height: StackCardSpacing.lg),
        _GitHubProjectActions(
          key: ValueKey('github_project_actions_${repository.id}'),
          repository: repository,
          validatedAt: validatedAt,
        ),
      ],
    ),
  );
}

class _GitHubProjectActions extends ConsumerWidget {
  const _GitHubProjectActions({
    super.key,
    required this.repository,
    this.validatedAt,
  });
  final GitHubRepository repository;
  final DateTime? validatedAt;

  void _feedback(BuildContext context, bool applied) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.strings.tr(
            applied ? 'githubSync.applied' : 'githubSync.actionFailed',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(githubPortfolioDraftStateProvider);
    final source = githubPortfolioSource(repository);
    final PortfolioGitHubReview review;
    try {
      review = reviewGitHubProject(
        state?.content ?? PortfolioContent(),
        source,
      );
    } on PortfolioGitHubFailure catch (failure) {
      return Text(
        context.strings.tr(
          failure.kind == PortfolioGitHubFailureKind.invalidSource
              ? 'githubSync.invalidSource'
              : 'githubSync.invalidDraft',
        ),
        key: ValueKey('github_invalid_${repository.id}'),
      );
    }
    final ready = state?.canEdit == true && state?.saving != true;
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state?.loaded == true) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              strings.tr('githubSync.status.${review.status.name}'),
              key: ValueKey('github_status_${repository.id}'),
            ),
          ),
          const SizedBox(height: StackCardSpacing.sm),
        ],
        StackCardButton(
          key: ValueKey('github_preview_${repository.id}'),
          label: strings.tr('githubSync.preview'),
          icon: Icons.visibility_outlined,
          onPressed: () => showGitHubProjectReview(context, review: review),
        ),
        if (state == null) ...[
          const SizedBox(height: StackCardSpacing.sm),
          StackCardButton(
            label: strings.tr('githubSync.signIn'),
            onPressed: () => context.go('/sign-in?from=%2Fgithub-import'),
          ),
        ] else if (review.project == null) ...[
          const SizedBox(height: StackCardSpacing.sm),
          StackCardButton(
            key: ValueKey('github_add_${repository.id}'),
            label: strings.tr('githubSync.add'),
            icon: Icons.add_rounded,
            onPressed: !ready
                ? null
                : () {
                    final expected = ref.read(portfolioDraftRepositoryProvider);
                    final applied = ref
                        .read(portfolioDraftControllerProvider.notifier)
                        .addGitHubProject(
                          source,
                          validatedAt: validatedAt,
                          expectedRepository: expected,
                        );
                    _feedback(context, applied);
                  },
          ),
        ] else ...[
          if (review.status == PortfolioGitHubReviewStatus.changesAvailable ||
              (review.status == PortfolioGitHubReviewStatus.ignored &&
                  review.project!.githubMetadata!.acceptedSource !=
                      source)) ...[
            const SizedBox(height: StackCardSpacing.sm),
            StackCardButton(
              key: ValueKey('github_review_${repository.id}'),
              label: strings.tr('githubSync.review'),
              icon: Icons.compare_arrows_rounded,
              onPressed: !ready
                  ? null
                  : () async {
                      final expected = ref.read(
                        portfolioDraftRepositoryProvider,
                      );
                      final accepted = await showGitHubProjectReview(
                        context,
                        review: review,
                        reviewChanges: true,
                        canAccept: true,
                      );
                      if (!context.mounted || accepted != true) return;
                      final latest = ref
                          .read(githubImportControllerProvider)
                          .repositories;
                      if (!latest.any(
                        (repository) =>
                            githubPortfolioSource(repository) == source,
                      )) {
                        _feedback(context, false);
                        return;
                      }
                      final applied = ref
                          .read(portfolioDraftControllerProvider.notifier)
                          .acceptGitHubChanges(
                            review,
                            validatedAt: validatedAt,
                            expectedRepository: expected,
                          );
                      _feedback(context, applied);
                    },
            ),
          ],
          const SizedBox(height: StackCardSpacing.sm),
          StackCardButton(
            key: ValueKey('github_edit_${repository.id}'),
            label: strings.tr('githubSync.edit'),
            icon: Icons.edit_outlined,
            onPressed: !ready
                ? null
                : () => context.push(
                    '/projects/${Uri.encodeComponent(review.project!.id)}/edit',
                  ),
          ),
        ],
        if (state != null &&
            (review.status == PortfolioGitHubReviewStatus.newRepository ||
                review.status ==
                    PortfolioGitHubReviewStatus.changesAvailable)) ...[
          const SizedBox(height: StackCardSpacing.sm),
          StackCardButton(
            key: ValueKey('github_ignore_${repository.id}'),
            label: strings.tr('githubSync.ignore'),
            onPressed: !ready
                ? null
                : () {
                    final expected = ref.read(portfolioDraftRepositoryProvider);
                    final applied = ref
                        .read(portfolioDraftControllerProvider.notifier)
                        .ignoreGitHubRepository(
                          source,
                          expectedRepository: expected,
                        );
                    _feedback(context, applied);
                  },
          ),
        ],
      ],
    );
  }
}

class GitHubSourceLink extends StatelessWidget {
  const GitHubSourceLink({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(url, style: Theme.of(context).textTheme.bodySmall)),
      IconButton(
        tooltip: context.strings.tr('github.copyLink'),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.copy_rounded),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: url));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.strings.tr('github.linkCopied'))),
          );
        },
      ),
    ],
  );
}
