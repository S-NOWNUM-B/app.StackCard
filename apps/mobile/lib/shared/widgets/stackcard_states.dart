import 'package:flutter/material.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import 'stackcard_button.dart';

enum StackCardViewState { loading, empty, error }

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
    return Semantics(
      liveRegion: kind != StackCardViewState.empty,
      child: Padding(
        padding: const EdgeInsets.all(StackCardSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind == StackCardViewState.loading)
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Загрузка',
                ),
              )
            else
              ExcludeSemantics(
                child: Icon(
                  kind == StackCardViewState.error
                      ? Icons.error_outline_rounded
                      : Icons.inbox_outlined,
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
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: StackCardSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            if (kind == StackCardViewState.error && onRetry != null) ...[
              const SizedBox(height: StackCardSpacing.lg),
              StackCardButton(
                label: 'Повторить',
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
