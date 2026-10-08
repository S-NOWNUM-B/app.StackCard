import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';

enum StackCardButtonRole { primary, secondary, quiet, danger }

class StackCardButton extends StatefulWidget {
  const StackCardButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconWidget,
    this.primary = false,
    this.loading = false,
    this.role,
    this.unavailableReason,
    this.iconSize = 18,
  }) : assert(icon == null || iconWidget == null),
       assert(iconSize > 0);

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? iconWidget;
  final double iconSize;
  final bool primary;
  final bool loading;

  /// Явная роль имеет приоритет над совместимым параметром [primary].
  final StackCardButtonRole? role;

  /// Причина недоступности, которую владелец действия получает из его состояния.
  final String? unavailableReason;

  @override
  State<StackCardButton> createState() => _StackCardButtonState();
}

class _StackCardButtonState extends State<StackCardButton> {
  bool _focused = false;

  void _focusChanged(bool value) {
    if (mounted && value != _focused) {
      setState(() => _focused = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final role =
        widget.role ??
        (widget.primary
            ? StackCardButtonRole.primary
            : StackCardButtonRole.secondary);
    final enabled = widget.onPressed != null && !widget.loading;
    final unavailable = !enabled && !widget.loading;
    final foreground = unavailable
        ? colors.textSecondary
        : switch (role) {
            StackCardButtonRole.primary => colors.onPrimary,
            StackCardButtonRole.danger => colors.error,
            StackCardButtonRole.secondary ||
            StackCardButtonRole.quiet => colors.textPrimary,
          };
    final faceOutline = unavailable
        ? colors.controlOutline
        : switch (role) {
            StackCardButtonRole.primary => colors.primaryOutline,
            StackCardButtonRole.secondary => colors.controlOutline,
            StackCardButtonRole.quiet => Colors.transparent,
            StackCardButtonRole.danger => colors.error,
          };
    final focused = enabled && _focused;
    final button = Focus(
      canRequestFocus: false,
      onFocusChange: _focusChanged,
      child: Semantics(
        button: true,
        enabled: enabled,
        focused: enabled ? focused : null,
        label: widget.label,
        liveRegion: widget.loading,
        value: widget.loading ? context.strings.tr('common.loading') : null,
        onTap: enabled ? widget.onPressed : null,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? widget.onPressed : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(StackCardRadius.medium),
                border: Border.all(
                  color: focused ? colors.focus : Colors.transparent,
                  width: 2,
                ),
              ),
              // 40px Face + 4px с каждой стороны: target48 и neutral focus gap.
              child: Padding(
                padding: const EdgeInsets.all(StackCardSpacing.xs),
                child: FilledButton(
                  onPressed: enabled ? widget.onPressed : null,
                  style: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(
                      Size(
                        StackCardSize.touchTarget - StackCardSpacing.xs * 2,
                        StackCardSize.touchTarget - StackCardSpacing.xs * 2,
                      ),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.all(StackCardSpacing.sm),
                    ),
                    visualDensity: VisualDensity.standard,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: WidgetStatePropertyAll(
                      theme.textTheme.labelLarge,
                    ),
                    foregroundColor: WidgetStatePropertyAll(foreground),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (unavailable) {
                        return colors.surfaceElevated;
                      }
                      final active =
                          states.contains(WidgetState.pressed) ||
                          states.contains(WidgetState.hovered);
                      return switch (role) {
                        StackCardButtonRole.primary =>
                          active ? colors.accentHover : colors.primary,
                        StackCardButtonRole.quiet =>
                          active ? colors.surfaceHover : Colors.transparent,
                        StackCardButtonRole.secondary ||
                        StackCardButtonRole.danger =>
                          active ? colors.surfaceHover : colors.surfaceElevated,
                      };
                    }),
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    surfaceTintColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    elevation: const WidgetStatePropertyAll(0),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: faceOutline),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          StackCardRadius.medium,
                        ),
                      ),
                    ),
                  ).merge(theme.filledButtonTheme.style),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.loading) ...[
                        SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        ),
                        const SizedBox(width: StackCardSpacing.sm),
                      ] else if (widget.icon != null ||
                          widget.iconWidget != null) ...[
                        SizedBox.square(
                          dimension: widget.iconSize,
                          child: IconTheme.merge(
                            data: IconThemeData(
                              color: foreground,
                              size: widget.iconSize,
                            ),
                            child:
                                widget.iconWidget ??
                                Icon(widget.icon, size: widget.iconSize),
                          ),
                        ),
                        const SizedBox(width: StackCardSpacing.sm),
                      ],
                      Flexible(
                        child: Text(widget.label, textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final reason = widget.unavailableReason;
    if (!unavailable || reason == null || reason.trim().isEmpty) {
      return button;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        button,
        const SizedBox(height: StackCardSpacing.xs),
        Text(
          reason,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textMeta),
        ),
      ],
    );
  }
}
