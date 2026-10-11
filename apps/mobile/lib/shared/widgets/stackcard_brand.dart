import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StackCardBrand extends StatelessWidget {
  const StackCardBrand({
    super.key,
    this.compact = false,
    this.trimWordmarkPadding = false,
  });

  final bool compact;
  final bool trimWordmarkPadding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = isDark ? 'paper' : 'ink';
    final family = compact ? 'mark' : 'wordmark';
    // Wordmark350×48 уже включает Mark A и исходное outlined написание.
    // Высота40 сохранена; contain вписывает бренд в узкий layout без искажения.
    const height = 40.0;
    final width = compact ? height : height * 350 / 48;
    final picture = SvgPicture.asset(
      'assets/branding/design_v2/stackcard-v2-$family-$tone.svg',
      width: width,
      height: height,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    // У исходного wordmark справа пустое поле. Viewport оставляет равные
    // боковые поля вокруг paths, не меняя SVG, масштаб или начертание.
    const trimmedWidth = height * 243.878 / 48;
    final trim = trimWordmarkPadding && !compact;
    return Semantics(
      label: 'StackCard',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: trim ? trimmedWidth : width,
          height: height,
          child: trim
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: trimmedWidth,
                    height: height,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: width,
                        maxWidth: width,
                        minHeight: height,
                        maxHeight: height,
                        child: Transform.translate(
                          offset: const Offset(0, -0.625),
                          child: picture,
                        ),
                      ),
                    ),
                  ),
                )
              : picture,
        ),
      ),
    );
  }
}
