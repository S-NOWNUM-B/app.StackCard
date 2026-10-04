import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';

/// Цельная цветовая поверхность. Декор не участвует в interaction/semantics.
class StackCardPoster extends StatelessWidget {
  const StackCardPoster({
    super.key,
    required this.child,
    required this.color,
    this.variant = 0,
    this.padding = const EdgeInsets.all(StackCardSpacing.xl),
    this.art = true,
  });

  final Widget child;
  final Color color;
  final int variant;
  final EdgeInsetsGeometry padding;
  final bool art;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(StackCardRadius.xlarge),
      child: ColoredBox(
        color: color,
        child: Stack(
          children: [
            if (art)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _PosterTexture(colors.ink, variant),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: padding,
              child: Theme(
                data: theme.copyWith(
                  textTheme: theme.textTheme.apply(
                    bodyColor: colors.ink,
                    displayColor: colors.ink,
                  ),
                  iconTheme: IconThemeData(color: colors.ink),
                  extensions: [
                    colors.copyWith(
                      textPrimary: colors.ink,
                      textSecondary: colors.ink.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Локальная абстрактная графика для posters; без загрузки внешних изображений.
class StackCardArtwork extends StatelessWidget {
  const StackCardArtwork({
    super.key,
    this.color,
    this.variant = 0,
    this.height = 160,
  });

  final Color? color;
  final int variant;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _RibbonPainter(color ?? context.colors.ink, variant),
        ),
      ),
    ),
  );
}

class _PosterTexture extends CustomPainter {
  const _PosterTexture(this.ink, this.variant);
  final Color ink;
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width * 1.05, size.height * 0.35);
    for (var i = 0; i < 12; i++) {
      final radius = 30.0 + i * 18;
      canvas.drawCircle(center, radius, paint);
    }
    final stripe = Paint()..color = ink.withValues(alpha: 0.13);
    for (var i = 0; i < 18; i++) {
      final x = size.width - 72 + i * 4;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - 18, i % 3 == 0 ? 2 : 1, 8),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(_PosterTexture oldDelegate) =>
      ink != oldDelegate.ink || variant != oldDelegate.variant;
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter(this.ink, this.variant);
  final Color ink;
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * 0.56, size.height * 0.49);
    canvas.rotate(-0.35 + (variant % 3) * 0.22);
    final scale = math.min(size.width / 290, size.height / 150);
    canvas.scale(scale);
    if (variant % 3 == 2) {
      // Альтернативный силуэт: сдвинутые плоскости вместо орбитальной ленты.
      for (var i = 0; i < 11; i++) {
        final offset = i * 5.0;
        final plane = Path()
          ..moveTo(-100 + offset, -55 + offset * .4)
          ..lineTo(45 + offset, -55 + offset * .4)
          ..lineTo(95 + offset, 15 + offset * .4)
          ..lineTo(-50 + offset, 15 + offset * .4)
          ..close();
        canvas.drawPath(
          plane,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 0 ? 3 : 1.2,
        );
      }
      canvas.restore();
      return;
    }
    // Слои одной ленты дают пространственный силуэт без glow и градиентов.
    for (var i = 18; i >= 0; i--) {
      final y = i * 2.0;
      final rect = Rect.fromCenter(
        center: Offset(-20 + i * 1.5, y - 20),
        width: 214,
        height: 90,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color = ink.withValues(alpha: 0.2 + (18 - i) * 0.035)
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 3 : 1.25,
      );
    }
    canvas.rotate(math.pi / 2.7);
    for (var i = 0; i < 14; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(15.0 + i, -10 + i * 1.8),
          width: 138,
          height: 65,
        ),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    canvas.restore();
    final star = Path();
    final center = Offset(size.width * 0.12, size.height * 0.32);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final radius = i.isEven ? 16.0 : 3.5;
      final point =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(star..close(), Paint()..color = ink);
    canvas.drawLine(
      Offset(size.width * .83, size.height * .72),
      Offset(size.width * .94, size.height * .72),
      Paint()
        ..color = ink
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(size.width * .885, size.height * .64),
      Offset(size.width * .885, size.height * .8),
      Paint()
        ..color = ink
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) =>
      ink != oldDelegate.ink || variant != oldDelegate.variant;
}
