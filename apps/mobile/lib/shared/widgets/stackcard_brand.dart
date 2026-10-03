import 'package:flutter/material.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';

class StackCardBrand extends StatelessWidget {
  const StackCardBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Суффиксы оригинальных SVG описывают графику, а не тему приложения.
    final markColor = isDark
        ? StackCardColors.dark.textPrimary
        : StackCardColors.dark.background;
    return Semantics(
      label: 'StackCard',
      image: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size.square(40),
              painter: _StackCardMarkPainter(
                foreground: markColor,
                accent: context.colors.accent,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: StackCardSpacing.sm),
              Flexible(
                child: Text(
                  'StackCard',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: markColor, letterSpacing: -0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Геометрия mark SVG из assets/branding, viewBox 80 × 80.
class _StackCardMarkPainter extends CustomPainter {
  const _StackCardMarkPainter({required this.foreground, required this.accent});

  final Color foreground;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 80, size.height / 80);
    final upper = Path()
      ..moveTo(24, 10)
      ..lineTo(66, 10)
      ..lineTo(66, 24)
      ..lineTo(28, 24)
      ..lineTo(28, 36)
      ..lineTo(12, 36)
      ..lineTo(12, 22)
      ..quadraticBezierTo(12, 10, 24, 10)
      ..close();
    final lower = Path()
      ..moveTo(12, 56)
      ..lineTo(50, 56)
      ..lineTo(50, 44)
      ..lineTo(66, 44)
      ..lineTo(66, 58)
      ..quadraticBezierTo(66, 70, 54, 70)
      ..lineTo(12, 70)
      ..close();
    final paint = Paint()..color = foreground;
    canvas.drawPath(upper, paint);
    canvas.drawPath(lower, paint);
    canvas.drawRect(
      const Rect.fromLTWH(24, 32, 30, 16),
      Paint()..color = accent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StackCardMarkPainter oldDelegate) {
    return foreground != oldDelegate.foreground || accent != oldDelegate.accent;
  }
}
