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
  }) : _sliver = false;

  const StackCardCard.sliver({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(StackCardSpacing.cardPadding),
    this.elevated = false,
    this.outlined = false,
  }) : _sliver = true;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  final bool _sliver;

  /// Контейнер сущности; обычные секции сохраняют плоский разделитель.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final contained = elevated || outlined;
    final decoration = BoxDecoration(
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
    );
    if (_sliver) {
      return DecoratedSliver(
        decoration: decoration,
        sliver: SliverPadding(
          // Ink включает рамку в padding; sliver сохраняет ту же геометрию.
          padding: padding.add(decoration.padding),
          sliver: child,
        ),
      );
    }
    return Material(
      type: MaterialType.transparency,
      borderRadius: contained
          ? BorderRadius.circular(StackCardRadius.large)
          : null,
      child: Ink(
        decoration: decoration,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
