import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import 'stackcard_button.dart';

enum StackCardViewState {
  loading,
  empty,
  error,
  offline,
  noResults,
  unavailable,
}

class StackCardStateView extends StatelessWidget {
  const StackCardStateView({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final StackCardViewState kind;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final canRetry =
        onRetry != null &&
        (kind == StackCardViewState.error ||
            kind == StackCardViewState.offline);
    return Semantics(
      liveRegion: kind != StackCardViewState.empty,
      child: Padding(
        padding: const EdgeInsets.all(StackCardSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind == StackCardViewState.loading)
              SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: context.strings.tr('common.loading'),
                ),
              )
            else
              ExcludeSemantics(
                child: Icon(
                  switch (kind) {
                    StackCardViewState.error => Icons.error_outline_rounded,
                    StackCardViewState.offline => Icons.cloud_off_outlined,
                    StackCardViewState.noResults => Icons.search_off_outlined,
                    StackCardViewState.unavailable =>
                      Icons.lock_outline_rounded,
                    StackCardViewState.empty ||
                    StackCardViewState.loading => Icons.inbox_outlined,
                  },
                  size: 32,
                  color: kind == StackCardViewState.error
                      ? colors.error
                      : colors.textSecondary,
                ),
              ),
            const SizedBox(height: StackCardSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: StackCardSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (canRetry) ...[
              const SizedBox(height: StackCardSpacing.lg),
              StackCardButton(
                label: context.strings.tr('common.retry'),
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
