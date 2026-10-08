import 'package:flutter/material.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';

class StackCardCard extends StatelessWidget {
  const StackCardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(StackCardSpacing.cardPadding),
    this.elevated = false,
    this.outlined = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  /// Контейнер сущности; обычные секции сохраняют плоский разделитель.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final contained = elevated || outlined;
    return Material(
      type: MaterialType.transparency,
      borderRadius: contained
          ? BorderRadius.circular(StackCardRadius.large)
          : null,
      child: Ink(
        decoration: BoxDecoration(
          color: elevated
              ? colors.surfaceElevated
              : outlined
              ? colors.surface
              : Colors.transparent,
          borderRadius: contained
              ? BorderRadius.circular(StackCardRadius.large)
              : null,
          border: contained
              ? Border.all(color: colors.border)
              : Border(bottom: BorderSide(color: colors.borderSubtle)),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
