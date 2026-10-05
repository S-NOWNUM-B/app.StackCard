import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/stackcard_colors.dart';

/// Закреплённый SVG; доступное имя задаёт внешний control или живой текст badge.
class StackCardIcon extends StatelessWidget {
  const StackCardIcon({
    super.key,
    required this.name,
    this.size = 24,
    this.color,
  }) : assert(size > 0);

  final String name;
  final double size;

  /// Применяется только к монохромным Lucide, не к технологиям.
  final Color? color;

  static const lucideNames = <String>{
    'home',
    'file-text',
    'folder',
    'panels-top-left',
    'settings',
    'arrow-left',
    'copy',
    'check',
    'image',
    'more-horizontal',
    'camera',
    'user-round',
    'chevron-down',
    'grip-vertical',
    'arrow-up',
    'arrow-down',
    'pencil',
    'plus',
    'search',
  };

  static const technologyNames = <String>{
    'react',
    'typescript',
    'flutter',
    'dart',
  };

  @override
  Widget build(BuildContext context) {
    final lucide = lucideNames.contains(name);
    if (!lucide && !technologyNames.contains(name)) {
      throw ArgumentError.value(name, 'name', 'Unknown pinned StackCard SVG');
    }
    final foreground =
        color ?? IconTheme.of(context).color ?? context.colors.textPrimary;
    final brandMapper = switch (name) {
      'react' => const _BrandColorMapper(Color(0xFF61DAFB)),
      'typescript' => const _BrandColorMapper(Color(0xFF3178C6)),
      _ => null,
    };
    // CSS исходного Flutter SVG раскрыт в fill/opacity совместимого render asset.
    final assetPath = name == 'flutter'
        ? 'assets/icons/technology/flutter.render.svg'
        : 'assets/icons/${lucide ? 'lucide' : 'technology'}/$name.svg';
    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        colorFilter: lucide
            ? ColorFilter.mode(foreground, BlendMode.srcIn)
            : null,
        colorMapper: brandMapper,
      ),
    );
  }
}

/// В raw Simple Icons default black заменяется исходным Figma brand color.
/// Flutter/Dart и все остальные исходные fills проходят без преобразования.
class _BrandColorMapper extends ColorMapper {
  const _BrandColorMapper(this.brandColor);

  final Color brandColor;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => attributeName == 'fill' && color == Colors.black ? brandColor : color;
}
