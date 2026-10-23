import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/stackcard_colors.dart';
import 'stackcard_icon.dart';
import 'technology_catalog_data.dart';

export 'technology_catalog_data.dart' show TechnologyInfo, technologyCatalog;

/// Ключ сравнения: регистр, пробелы, точки и дефисы не важны («Next.js» = «nextjs»).
String _key(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+#а-яё]'), '');

final Map<String, TechnologyInfo> _index = {
  for (final info in technologyCatalog.reversed) ...{
    for (final alias in info.aliases) _key(alias): info,
    _key(info.title): info,
  },
};

/// Известная технология по введённому названию или синониму; иначе null.
TechnologyInfo? findTechnology(String label) {
  final key = _key(label);
  return key.isEmpty ? null : _index[key];
}

/// Подсказки при вводе: сначала совпадение с началом названия, затем с синонимом.
/// Каталог отсортирован по популярности, поэтому порядок записей значим.
List<TechnologyInfo> technologySuggestions(
  String query, {
  Iterable<String> exclude = const [],
  int limit = 6,
}) {
  final q = _key(query);
  if (q.isEmpty) return const [];
  final excluded = {for (final item in exclude) _key(item)};
  final scored = <(int, TechnologyInfo)>[];
  for (final info in technologyCatalog) {
    if (excluded.contains(_key(info.title))) continue;
    final title = _key(info.title);
    final aliases = info.aliases.map(_key);
    final score = title.startsWith(q)
        ? 0
        : aliases.any((alias) => alias.startsWith(q))
        ? 1
        : title.contains(q)
        ? 2
        : aliases.any((alias) => alias.contains(q))
        ? 3
        : null;
    if (score != null) scored.add((score, info));
  }
  // Внутри одного уровня — порядок каталога: популярные технологии выше.
  scored.sort(
    (a, b) => a.$1 != b.$1
        ? a.$1.compareTo(b.$1)
        : technologyCatalog
              .indexOf(a.$2)
              .compareTo(technologyCatalog.indexOf(b.$2)),
  );
  return [for (final item in scored.take(limit)) item.$2];
}

const _multicolor = {'Flutter', 'Dart'};

/// Иконка технологии на тёмной плашке; неизвестная — нейтральная папка.
class StackCardTechnologyIcon extends StatelessWidget {
  const StackCardTechnologyIcon({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final info = findTechnology(label);
    final slug = info?.slug;
    final Widget icon;
    if (info == null) {
      icon = StackCardIcon(name: 'folder', size: 18, color: colors.paper);
    } else if (slug == null && _multicolor.contains(info.title)) {
      // Официальные многоцветные знаки Design v2 рисуются без перекраски.
      icon = StackCardIcon(name: info.title.toLowerCase(), size: 18);
    } else {
      // Одноцветный SVG получает фирменный цвет; слишком тёмный не читается на ink.
      final brand = info.brandColor;
      final color = brand.computeLuminance() < 0.15 ? colors.paper : brand;
      icon = SvgPicture.asset(
        slug == null
            ? 'assets/icons/technology/${info.title.toLowerCase()}.svg'
            : 'assets/icons/technology/simple-icons/$slug.svg',
        width: 18,
        height: 18,
        excludeFromSemantics: true,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(4),
      ),
      child: SizedBox.square(dimension: 24, child: Center(child: icon)),
    );
  }
}
