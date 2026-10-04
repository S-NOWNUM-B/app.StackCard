import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../domain/github_read_metadata.dart';

class GitHubCacheNotice extends StatelessWidget {
  const GitHubCacheNotice({super.key, required this.metadata});

  final GitHubReadMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final storageFailure =
        metadata.cacheWriteFailed || metadata.cacheUnavailable;
    if (!metadata.fromCache && !storageFailure) return const SizedBox.shrink();
    final checked = metadata.validatedAt?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: StackCardSpacing.lg),
      child: Semantics(
        liveRegion: true,
        child: StackCardCard(
          padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (metadata.fromCache) ...[
                Text(
                  context.strings.tr('github.cache.title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: StackCardSpacing.sm),
                Text(
                  context.strings.tr('github.cache.hint'),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: context.colors.textSecondary),
                ),
                if (checked != null) ...[
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    context.strings.tr('github.cache.date', {
                      'date':
                          '${localizations.formatCompactDate(checked)} '
                          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(checked))}',
                    }),
                  ),
                ],
              ],
              if (storageFailure) ...[
                if (metadata.fromCache)
                  const SizedBox(height: StackCardSpacing.lg),
                Text(
                  context.strings.tr('github.cache.storageTitle'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: StackCardSpacing.sm),
                Text(
                  context.strings.tr('github.cache.storageHint'),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: context.colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
