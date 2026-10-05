import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StackCardBrand extends StatelessWidget {
  const StackCardBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = isDark ? 'paper' : 'ink';
    final family = compact ? 'mark' : 'wordmark';
    // Wordmark350×48 уже включает Mark A и исходное outlined написание.
    // Высота40 сохранена; contain вписывает бренд в узкий layout без искажения.
    const height = 40.0;
    final width = compact ? height : height * 350 / 48;
    return Semantics(
      label: 'StackCard',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: height,
          child: SvgPicture.asset(
            'assets/branding/design_v2/stackcard-v2-$family-$tone.svg',
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
