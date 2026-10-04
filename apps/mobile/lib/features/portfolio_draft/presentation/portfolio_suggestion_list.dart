import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../domain/portfolio_suggestions.dart';

/// Suggestions only explain a rule and open an explicit review or editor action.
class PortfolioSuggestionList extends StatelessWidget {
  const PortfolioSuggestionList({
    super.key,
    required this.suggestions,
    this.onAction,
    this.showTitle = true,
    this.showActions = true,
    this.showTargetTitle = true,
  });

  final List<PortfolioSuggestion> suggestions;
  final ValueChanged<PortfolioSuggestion>? onAction;
  final bool showTitle;
  final bool showActions;
  final bool showTargetTitle;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            context.strings.tr('suggestions.title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            context.strings.tr('suggestions.note'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.lg),
        ],
        for (var index = 0; index < suggestions.length; index++) ...[
          if (index > 0) const SizedBox(height: StackCardSpacing.lg),
          _SuggestionReason(
            suggestion: suggestions[index],
            showTargetTitle:
                showTargetTitle &&
                (index == 0 ||
                    (
                          suggestions[index - 1].projectId,
                          suggestions[index - 1].repositoryId,
                        ) !=
                        (
                          suggestions[index].projectId,
                          suggestions[index].repositoryId,
                        )),
            showAction: showActions,
            onAction: onAction,
          ),
        ],
        if (!showActions) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              for (final action
                  in suggestions.map((item) => item.action).toSet())
                Text(
                  context.strings.tr('suggestions.source.${action.name}'),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.colors.textSecondary),
                ),
            ],
          ),
        ],
      ],
    );
    return showTitle ? StackCardCard(child: content) : content;
  }
}

class _SuggestionReason extends StatelessWidget {
  const _SuggestionReason({
    required this.suggestion,
    required this.showTargetTitle,
    required this.showAction,
    required this.onAction,
  });

  final PortfolioSuggestion suggestion;
  final bool showTargetTitle;
  final bool showAction;
  final ValueChanged<PortfolioSuggestion>? onAction;

  String _reason(BuildContext context) {
    final strings = context.strings;
    final date = suggestion.updatedAt
        ?.toUtc()
        .toIso8601String()
        .split('T')
        .first;
    return switch (suggestion.kind) {
      PortfolioSuggestionKind.newRepository ||
      PortfolioSuggestionKind.missingDescription ||
      PortfolioSuggestionKind.missingPreview => strings.tr(
        'suggestions.reason.${suggestion.kind.name}',
      ),
      PortfolioSuggestionKind.recentActivity => strings.tr(
        'suggestions.reason.recentActivity',
        {
          'date': date!,
          'days': PortfolioSuggestionThresholds.recentActivityWindow.inDays,
        },
      ),
      PortfolioSuggestionKind.inactiveProject => strings.tr(
        'suggestions.reason.inactiveProject',
        {
          'date': date!,
          'days': PortfolioSuggestionThresholds.inactiveProjectAge.inDays,
        },
      ),
      PortfolioSuggestionKind.featuredCandidate =>
        suggestion.repositoryId == null
            ? strings.tr('suggestions.reason.featuredCandidate.manual')
            : (suggestion.stars ?? 0) >=
                  PortfolioSuggestionThresholds.featuredMinimumStars
            ? strings.tr('suggestions.reason.featuredCandidate', {
                'stars': suggestion.stars!,
                'threshold': PortfolioSuggestionThresholds.featuredMinimumStars,
              })
            : strings.tr('suggestions.reason.featuredCandidate.recent'),
    };
  }

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey('portfolio_suggestion_${suggestion.id}'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showTargetTitle) ...[
        Text(
          suggestion.targetTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: StackCardSpacing.xs),
      ],
      Text(_reason(context), style: Theme.of(context).textTheme.bodyMedium),
      if (showAction) ...[
        const SizedBox(height: StackCardSpacing.sm),
        Wrap(
          spacing: StackCardSpacing.sm,
          runSpacing: StackCardSpacing.sm,
          children: [
            StackCardButton(
              key: ValueKey('portfolio_suggestion_action_${suggestion.id}'),
              label: context.strings.tr(
                'suggestions.action.${suggestion.kind.name}',
              ),
              icon: suggestion.action == PortfolioSuggestionAction.editProject
                  ? Icons.edit_outlined
                  : Icons.visibility_outlined,
              onPressed: onAction == null ? null : () => onAction!(suggestion),
            ),
          ],
        ),
      ],
    ],
  );
}
