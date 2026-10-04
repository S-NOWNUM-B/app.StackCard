import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../core/theme/stackcard_colors.dart';
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
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        Text(
          strings.tr(
            reviewChanges ? 'githubSync.reviewNote' : 'githubSync.previewNote',
          ),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: StackCardSpacing.lg),
        if (reviewChanges && fields.isEmpty)
          Text(strings.tr('githubSync.metadataChanged')),
        for (final field in fields)
          _ReviewField(
            title: strings.tr('githubSync.field.${field.name}'),
            previous: reviewChanges && previous != null
                ? _display(context, _sourceValue(previous, field))
                : null,
            incoming: _display(context, _sourceValue(review.source, field)),
            overrideValue:
                project != null &&
                    project.githubMetadata?.overrideFields.contains(field) ==
                        true
                ? _display(context, _projectValue(project, field))
                : null,
          ),
        if (reviewChanges && previous != null)
          for (final change in _metadataChanges(
            context,
            previous,
            review.source,
          ))
            _ReviewField(
              key: ValueKey('github_metadata_${change.$1}'),
              title: strings.tr('githubSync.metadata.${change.$1}'),
              previous: change.$2,
              incoming: change.$3,
            ),
        const SizedBox(height: StackCardSpacing.xl),
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

class _ReviewField extends StatelessWidget {
  const _ReviewField({
    super.key,
    required this.title,
    required this.incoming,
    this.previous,
    this.overrideValue,
  });

  final String title;
  final String incoming;
  final String? previous;
  final String? overrideValue;

  @override
  Widget build(BuildContext context) => StackCardCard(
    padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: StackCardSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final before = previous == null
                ? null
                : _ReviewValue(
                    label: context.strings.tr('githubSync.previous'),
                    value: previous!,
                    lineColor: context.colors.border,
                  );
            final after = _ReviewValue(
              label: context.strings.tr('githubSync.incoming'),
              value: incoming,
              lineColor: context.colors.cyan,
            );
            if (before != null &&
                constraints.maxWidth >= 500 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.7) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: before),
                  const SizedBox(width: StackCardSpacing.xl),
                  Expanded(child: after),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (before != null) ...[
                  before,
                  const SizedBox(height: StackCardSpacing.md),
                ],
                after,
              ],
            );
          },
        ),
        if (overrideValue != null) ...[
          const SizedBox(height: StackCardSpacing.md),
          _ReviewValue(
            label: context.strings.tr('githubSync.override'),
            value: overrideValue!,
            lineColor: context.colors.pink,
          ),
        ],
      ],
    ),
  );
}

class _ReviewValue extends StatelessWidget {
  const _ReviewValue({
    required this.label,
    required this.value,
    required this.lineColor,
  });

  final String label;
  final String value;
  final Color lineColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: lineColor, width: 2)),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: StackCardSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    ),
  );
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
