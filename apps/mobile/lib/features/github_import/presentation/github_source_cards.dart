import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_poster.dart';
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
  Widget build(BuildContext context) => StackCardPoster(
    color: context.colors.cyan,
    variant: 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '@${profile.login}',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: context.colors.ink),
              ),
            ),
            GitHubSourceLink(url: profile.htmlUrl, compact: true),
          ],
        ),
        StackCardArtwork(height: 100, color: context.colors.ink, variant: 1),
        Text(
          profile.name ?? profile.login,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: context.colors.ink),
        ),
        if (profile.bio case final bio? when bio.isNotEmpty) ...[
          const SizedBox(height: StackCardSpacing.md),
          Text(
            bio,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.ink),
          ),
        ],
        if (profile.location case final location?) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            location,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.ink),
          ),
        ],
        const SizedBox(height: StackCardSpacing.lg),
        Text(
          context.strings.tr('github.publicRepos', {
            'count': profile.publicRepositories,
          }),
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: context.colors.ink),
        ),
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
    padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                repository.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            GitHubSourceLink(url: repository.htmlUrl, compact: true),
          ],
        ),
        if (showDescription && repository.description?.isNotEmpty == true) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            repository.description!,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
        const SizedBox(height: StackCardSpacing.lg),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: StackCardSpacing.lg,
          runSpacing: StackCardSpacing.sm,
          children: [
            if (repository.language case final language?) Text(language),
            _SourceMetric(
              icon: Icons.star_border_rounded,
              value: repository.stars,
              label: context.strings.tr('githubSync.metadata.stars'),
            ),
            _SourceMetric(
              icon: Icons.call_split_rounded,
              value: repository.forks,
              label: context.strings.tr('githubSync.metadata.forks'),
            ),
            if (repository.isFork) const Text('Fork'),
            if (repository.archived)
              Text(context.strings.tr('github.filter.archived')),
          ],
        ),
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

class _SourceMetric extends StatelessWidget {
  const _SourceMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: context.colors.textSecondary),
        const SizedBox(width: StackCardSpacing.xs),
        Text('$value', style: Theme.of(context).textTheme.labelLarge),
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
    final suggestions = state?.canEdit == true
        ? buildPortfolioSuggestions(
            content: state?.content ?? PortfolioContent(),
            sources: [source],
            now: ref.watch(portfolioSuggestionClockProvider)(),
          ).where((item) => item.repositoryId == repository.id).toList()
        : const <PortfolioSuggestion>[];
    final strings = context.strings;
    return Wrap(
      spacing: StackCardSpacing.sm,
      runSpacing: StackCardSpacing.sm,
      children: [
        if (state?.loaded == true) ...[
          SizedBox(
            width: double.infinity,
            child: Semantics(
              liveRegion: true,
              child: Text(
                strings.tr('githubSync.status.${review.status.name}'),
                key: ValueKey('github_status_${repository.id}'),
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: context.colors.textSecondary),
              ),
            ),
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: PortfolioSuggestionList(
              key: ValueKey('github_suggestions_${repository.id}'),
              suggestions: suggestions,
              showTitle: false,
              showTargetTitle: false,
              showActions: false,
            ),
          ),
        ],
        StackCardButton(
          key: ValueKey('github_preview_${repository.id}'),
          label: strings.tr('githubSync.preview'),
          icon: Icons.visibility_outlined,
          onPressed: () => showGitHubProjectReview(context, review: review),
        ),
        if (state == null) ...[
          StackCardButton(
            label: strings.tr('githubSync.signIn'),
            onPressed: () => context.go('/sign-in?from=%2Fgithub-import'),
          ),
        ] else if (review.project == null) ...[
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
  const GitHubSourceLink({super.key, required this.url, this.compact = false});

  final String url;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final copy = IconButton(
      tooltip: context.strings.tr('github.copyLink'),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.link_rounded),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.tr('github.linkCopied'))),
        );
      },
    );
    if (compact) {
      return Semantics(label: url, child: copy);
    }
    return Row(
      children: [
        Expanded(
          child: Text(url, style: Theme.of(context).textTheme.bodySmall),
        ),
        copy,
      ],
    );
  }
}
