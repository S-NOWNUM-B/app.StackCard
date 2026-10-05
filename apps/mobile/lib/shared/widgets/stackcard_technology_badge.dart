import 'package:flutter/material.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import 'stackcard_icon.dart';

/// Информационный badge: текст остаётся полным, неизвестный label не изменяется.
class StackCardTechnologyBadge extends StatelessWidget {
  const StackCardTechnologyBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final normalized = label.trim().toLowerCase();
    final known = StackCardIcon.technologyNames.contains(normalized);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(StackCardRadius.small),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: StackCardSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.ink,
                  borderRadius: BorderRadius.circular(StackCardSpacing.xs),
                ),
                child: SizedBox.square(
                  dimension: 24,
                  child: Center(
                    child: StackCardIcon(
                      name: known ? normalized : 'folder',
                      size: 18,
                      color: known ? null : colors.paper,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: StackCardSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// +N открывает настоящий полный список; сама информация badge не интерактивна.
class StackCardMoreTechnologies extends StatelessWidget {
  const StackCardMoreTechnologies({
    super.key,
    required this.count,
    required this.label,
    this.onPressed,
  }) : assert(count > 0);

  final int count;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.square(StackCardSize.touchTarget),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.all(StackCardSpacing.sm),
          ),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: WidgetStatePropertyAll(
            Theme.of(context).textTheme.bodySmall,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.textSecondary
                : colors.textPrimary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.hovered)
                ? colors.surfaceHover
                : colors.surfaceElevated,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: colors.focus, width: 2)
                : BorderSide(color: colors.controlOutline),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StackCardRadius.small),
            ),
          ),
        ),
        child: Semantics(
          label: label,
          excludeSemantics: true,
          child: Text('+$count'),
        ),
      ),
    );
  }
}
