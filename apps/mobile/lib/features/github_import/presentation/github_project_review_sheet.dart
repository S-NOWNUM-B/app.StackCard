import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../portfolio_draft/portfolio_draft.dart';

Future<bool?> showGitHubProjectReview(
  BuildContext context, {
  required PortfolioGitHubReview review,
  bool reviewChanges = false,
  bool canAccept = false,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 720),
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.85,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        StackCardSpacing.xl,
        StackCardSpacing.sm,
        StackCardSpacing.xl,
        StackCardSpacing.xxl,
      ),
      child: GitHubProjectReviewSheet(
        review: review,
        reviewChanges: reviewChanges,
        canAccept: canAccept,
      ),
    ),
  ),
);

class GitHubProjectReviewSheet extends StatelessWidget {
  const GitHubProjectReviewSheet({
    super.key,
    required this.review,
    this.reviewChanges = false,
    this.canAccept = false,
  });

  final PortfolioGitHubReview review;
  final bool reviewChanges;
  final bool canAccept;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final project = review.project;
    final previous = project?.githubMetadata?.acceptedSource;
    final fields = reviewChanges
        ? review.changedFields
        : PortfolioGitHubField.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          review.source.fullName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        Text(
          strings.tr(
            reviewChanges ? 'githubSync.reviewNote' : 'githubSync.previewNote',
          ),
        ),
        const SizedBox(height: StackCardSpacing.lg),
        if (reviewChanges && fields.isEmpty)
          Text(strings.tr('githubSync.metadataChanged')),
        for (final field in fields) ...[
          StackCardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.tr('githubSync.field.${field.name}'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: StackCardSpacing.sm),
                if (reviewChanges && previous != null) ...[
                  Text(
                    strings.tr('githubSync.previous'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(_display(context, _sourceValue(previous, field))),
                  const SizedBox(height: StackCardSpacing.sm),
                ],
                Text(
                  strings.tr('githubSync.incoming'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(_display(context, _sourceValue(review.source, field))),
                if (project != null &&
                    project.githubMetadata?.overrideFields.contains(field) ==
                        true) ...[
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    strings.tr('githubSync.override'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(_display(context, _projectValue(project, field))),
                ],
              ],
            ),
          ),
          const SizedBox(height: StackCardSpacing.lg),
        ],
        if (reviewChanges && previous != null)
          for (final change in _metadataChanges(
            context,
            previous,
            review.source,
          )) ...[
            StackCardCard(
              key: ValueKey('github_metadata_${change.$1}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.tr('githubSync.metadata.${change.$1}'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    strings.tr('githubSync.previous'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(change.$2),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    strings.tr('githubSync.incoming'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(change.$3),
                ],
              ),
            ),
            const SizedBox(height: StackCardSpacing.lg),
          ],
        if (reviewChanges && canAccept) ...[
          StackCardButton(
            key: const ValueKey('github_review_accept'),
            label: strings.tr('githubSync.accept'),
            primary: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: StackCardSpacing.sm),
        ],
        StackCardButton(
          key: const ValueKey('github_review_close'),
          label: strings.tr(
            reviewChanges ? 'githubSync.cancel' : 'githubSync.close',
          ),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

List<(String, String, String)> _metadataChanges(
  BuildContext context,
  GitHubProjectSource previous,
  GitHubProjectSource incoming,
) {
  String boolean(bool value) =>
      context.strings.tr(value ? 'githubSync.yes' : 'githubSync.no');
  return [
    if (previous.fullName != incoming.fullName)
      ('fullName', previous.fullName, incoming.fullName),
    if (previous.stars != incoming.stars)
      ('stars', '${previous.stars}', '${incoming.stars}'),
    if (previous.forks != incoming.forks)
      ('forks', '${previous.forks}', '${incoming.forks}'),
    if (previous.isFork != incoming.isFork)
      ('isFork', boolean(previous.isFork), boolean(incoming.isFork)),
    if (previous.archived != incoming.archived)
      ('archived', boolean(previous.archived), boolean(incoming.archived)),
    if (previous.updatedAt != incoming.updatedAt)
      (
        'updatedAt',
        previous.updatedAt.toIso8601String(),
        incoming.updatedAt.toIso8601String(),
      ),
  ];
}

String _display(BuildContext context, String value) =>
    value.isEmpty ? context.strings.tr('githubSync.empty') : value;

String _sourceValue(GitHubProjectSource source, PortfolioGitHubField field) =>
    switch (field) {
      PortfolioGitHubField.title => source.name,
      PortfolioGitHubField.description => source.description ?? '',
      PortfolioGitHubField.technologies => source.language ?? '',
      PortfolioGitHubField.repositoryUrl => source.htmlUrl,
    };

String _projectValue(PortfolioProject project, PortfolioGitHubField field) =>
    switch (field) {
      PortfolioGitHubField.title => project.title,
      PortfolioGitHubField.description => project.description,
      PortfolioGitHubField.technologies => project.technologies.join(', '),
      PortfolioGitHubField.repositoryUrl => project.repositoryUrl,
    };
