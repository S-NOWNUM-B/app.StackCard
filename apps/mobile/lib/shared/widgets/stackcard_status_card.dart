import 'package:flutter/material.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import 'stackcard_card.dart';

enum StackCardStatusTone { neutral, success, error }

/// Единая карточка статуса: иконка тона, заголовок и пояснение. Тон передаётся
/// не только цветом: у каждого свой значок.
class StackCardStatusCard extends StatelessWidget {
  const StackCardStatusCard({
    super.key,
    this.title,
    required this.message,
    this.tone = StackCardStatusTone.neutral,
  });

  final String? title;
  final String message;
  final StackCardStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final (icon, accent) = switch (tone) {
      StackCardStatusTone.neutral => (
        Icons.info_outline_rounded,
        colors.textSecondary,
      ),
      StackCardStatusTone.success => (
        Icons.check_circle_outline_rounded,
        colors.successText,
      ),
      StackCardStatusTone.error => (Icons.error_outline_rounded, colors.error),
    };
    return Semantics(
      container: true,
      liveRegion: tone == StackCardStatusTone.error,
      child: StackCardCard(
        elevated: true,
        padding: const EdgeInsets.all(StackCardSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 22, color: accent)),
            const SizedBox(width: StackCardSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: text.labelLarge?.copyWith(
                        color: tone == StackCardStatusTone.neutral
                            ? colors.textPrimary
                            : accent,
                      ),
                    ),
                    const SizedBox(height: StackCardSpacing.xs),
                  ],
                  Text(
                    message,
                    style: text.bodyMedium?.copyWith(
                      color: tone == StackCardStatusTone.error && title == null
                          ? colors.error
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
