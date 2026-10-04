import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';

class StackCardButton extends StatelessWidget {
  const StackCardButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.primary = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null && !loading;
    final foreground = primary && enabled
        ? StackCardColors.dark.background
        : Theme.of(context).colorScheme.onSurface;
    final button = FilledButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: StackCardSpacing.lg,
            vertical: StackCardSpacing.md,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelLarge,
        ),
        foregroundColor: WidgetStatePropertyAll(foreground),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.surfaceHover;
          }
          if (primary) return colors.accent;
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return colors.surfaceHover;
          }
          return colors.surface;
        }),
        // Сохранение фона primary не ухудшает контраст при нажатии.
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(
              color: primary ? colors.textPrimary : colors.accent,
              width: 2,
            );
          }
          if (primary && states.contains(WidgetState.hovered)) {
            return BorderSide(color: colors.accentHover, width: 2);
          }
          return BorderSide(
            color: primary && enabled ? colors.accent : colors.border,
          );
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            ),
            const SizedBox(width: StackCardSpacing.sm),
          ] else if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: StackCardSpacing.sm),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
    return Semantics(
      liveRegion: loading,
      value: loading ? context.strings.tr('common.loading') : null,
      child: button,
    );
  }
}
