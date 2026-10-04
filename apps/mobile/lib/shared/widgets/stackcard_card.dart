import 'package:flutter/material.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';

class StackCardCard extends StatelessWidget {
  const StackCardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(StackCardSpacing.cardPadding),
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: elevated ? colors.surfaceElevated : Colors.transparent,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
