import 'portfolio_content.dart';
import 'vacancy_match.dart';

/// Сколько технологий показывать отдельно; остальные уходят в «Другие».
const stackDnaTopCount = 6;

/// Годы вне диапазона считаются битой датой: проект остаётся без даты.
const stackDnaMinYear = 2000;
const stackDnaMaxYear = 2100;

/// Минимум проектов с технологиями для уверенных выводов.
const stackDnaEnoughProjects = 3;

/// «Главный стек»: технологии с долей не меньше порога, не больше [mainLimit].
const stackDnaMainShare = 0.15;
const stackDnaMainLimit = 3;

/// «Растёт»: доля в последних двух годах минимум на столько выше прежней.
const stackDnaRisingDelta = 0.10;

/// Источник данных одного проекта: технологии, язык GitHub и дата.
final class StackDnaProject {
  StackDnaProject({
    required this.id,
    required this.title,
    List<String> technologies = const [],
    this.language,
    this.date,
    this.fromGitHub = false,
  }) : technologies = List.unmodifiable(technologies);

  final String id;
  final String title;
  final List<String> technologies;

  /// Основной язык репозитория из GitHub-метаданных.
  final String? language;

  /// Последняя активность (GitHub updatedAt) или правка проекта; null — нет даты.
  final DateTime? date;
  final bool fromGitHub;
}

/// Проекты портфолио как вход. Форки и архивные репозитории исключаются:
/// они не отражают собственный стек. Только чтение, без сети.
List<StackDnaProject> stackDnaProjectsFrom(PortfolioContent content) {
  final result = <StackDnaProject>[];
  for (final project in content.projects) {
    // Скрытый проект не отражает стек, который владелец показывает.
    if (!project.visible) continue;
    final source = project.githubMetadata?.acceptedSource;
    if (source != null && (source.isFork || source.archived)) continue;
    result.add(
      StackDnaProject(
        id: project.id,
        title: project.title,
        technologies: project.technologies,
        language: source?.language,
        // Для GitHub-проекта — дата репозитория: правка текста в приложении
        // не переносит проект в текущий год.
        date: source?.updatedAt ?? project.updatedAt,
        fromGitHub: source != null,
      ),
    );
  }
  return result;
}

final class StackDnaShare {
  const StackDnaShare({
    required this.id,
    required this.label,
    required this.count,
    required this.share,
    this.firstYear,
    this.lastYear,
    this.isOther = false,
  });

  final String id;
  final String label;

  /// Число проектов, где технология встречается.
  final int count;

  /// Доля среди всех упоминаний, 0..1.
  final double share;

  /// Годы последней активности проектов (GitHub updatedAt / правка проекта),
  /// а не дата первого использования: даты создания в модели нет.
  final int? firstYear;
  final int? lastYear;

  /// Сводная строка «Другие».
  final bool isOther;
}

final class StackDnaYear {
  const StackDnaYear({
    required this.year,
    required this.counts,
    this.dominantId,
  });

  final int year;

  /// id технологии → число проектов года; пусто — в этот год данных нет.
  final Map<String, int> counts;
  final String? dominantId;
  bool get hasData => counts.isNotEmpty;
  int get total => counts.values.fold(0, (sum, value) => sum + value);
}

final class StackDna {
  StackDna({
    required List<StackDnaShare> shares,
    required List<StackDnaShare> all,
    required List<StackDnaYear> years,
    required List<String> mainStack,
    required List<String> rising,
    required this.projectCount,
    required this.undatedCount,
  }) : shares = List.unmodifiable(shares),
       all = List.unmodifiable(all),
       years = List.unmodifiable(years),
       mainStack = List.unmodifiable(mainStack),
       rising = List.unmodifiable(rising);

  /// Топ-N и «Другие» для составной полосы.
  final List<StackDnaShare> shares;

  /// Все технологии по убыванию доли.
  final List<StackDnaShare> all;
  final List<StackDnaYear> years;

  /// id технологий главного стека и растущих.
  final List<String> mainStack;
  final List<String> rising;

  /// Проектов с хотя бы одной технологией.
  final int projectCount;

  /// Из них без даты: на временной ряд не попали.
  final int undatedCount;

  bool get isEmpty => all.isEmpty;

  /// Мало данных: выводы ненадёжны.
  bool get isLowData => !isEmpty && projectCount < stackDnaEnoughProjects;

  String labelOf(String id) => all.firstWhere((item) => item.id == id).label;
}

/// Строит «ДНК стека» из проектов. Правила:
/// доля — упоминания технологии среди всех упоминаний (язык GitHub и список
/// technologies одного проекта дают одно упоминание на технологию);
/// главный стек — до трёх технологий с долей от 15%;
/// «растёт» — доля в двух последних годах выше прежней минимум на 10 п.п.
StackDna buildStackDna(
  Iterable<StackDnaProject> projects, {
  List<VacancyTerm> dictionary = defaultVacancyDictionary,
}) {
  final labels = <String, String>{};
  final counts = <String, int>{};
  final firstYear = <String, int>{};
  final lastYear = <String, int>{};
  final byYear = <int, Map<String, int>>{};
  var projectCount = 0;
  var undated = 0;

  for (final project in projects) {
    final ids = <String>{};
    for (final raw in [...project.technologies, ?project.language]) {
      final name = raw.trim();
      if (name.isEmpty || name.length > 60) continue;
      final term = findVacancyTechnology(name, dictionary: dictionary);
      // Неизвестные технологии получают префикс: id строки «Другие»
      // ('other') не может совпасть с названием технологии.
      final id = term?.id ?? 'x:${name.toLowerCase()}';
      if (ids.add(id)) labels.putIfAbsent(id, () => term?.label ?? name);
    }
    if (ids.isEmpty) continue;
    projectCount++;
    final rawYear = project.date?.toUtc().year;
    final year =
        rawYear != null &&
            rawYear >= stackDnaMinYear &&
            rawYear <= stackDnaMaxYear
        ? rawYear
        : null;
    if (year == null) undated++;
    for (final id in ids) {
      counts[id] = (counts[id] ?? 0) + 1;
      if (year == null) continue;
      firstYear[id] = firstYear[id] == null || year < firstYear[id]!
          ? year
          : firstYear[id]!;
      lastYear[id] = lastYear[id] == null || year > lastYear[id]!
          ? year
          : lastYear[id]!;
      final bucket = byYear.putIfAbsent(year, () => {});
      bucket[id] = (bucket[id] ?? 0) + 1;
    }
  }

  final total = counts.values.fold(0, (sum, value) => sum + value);
  int compare(String a, String b) {
    final byCount = counts[b]!.compareTo(counts[a]!);
    return byCount != 0
        ? byCount
        : labels[a]!.toLowerCase().compareTo(labels[b]!.toLowerCase());
  }

  final ordered = counts.keys.toList()..sort(compare);
  final all = [
    for (final id in ordered)
      StackDnaShare(
        id: id,
        label: labels[id]!,
        count: counts[id]!,
        share: counts[id]! / total,
        firstYear: firstYear[id],
        lastYear: lastYear[id],
      ),
  ];
  final top = all.take(stackDnaTopCount).toList();
  final rest = all.skip(stackDnaTopCount).toList();
  final shares = [
    ...top,
    if (rest.isNotEmpty)
      StackDnaShare(
        id: 'other',
        label: 'Другие',
        count: rest.fold(0, (sum, item) => sum + item.count),
        share: rest.fold(0.0, (sum, item) => sum + item.share),
        isOther: true,
      ),
  ];

  // Годы подряд от первого до последнего; годы без данных остаются пустыми.
  final years = <StackDnaYear>[];
  if (byYear.isNotEmpty) {
    final first = byYear.keys.reduce((a, b) => a < b ? a : b);
    final last = byYear.keys.reduce((a, b) => a > b ? a : b);
    for (var year = first; year <= last; year++) {
      final bucket = byYear[year] ?? const <String, int>{};
      String? dominant;
      for (final id in bucket.keys) {
        if (dominant == null ||
            bucket[id]! > bucket[dominant]! ||
            (bucket[id] == bucket[dominant] &&
                labels[id]!.toLowerCase().compareTo(
                      labels[dominant]!.toLowerCase(),
                    ) <
                    0)) {
          dominant = id;
        }
      }
      years.add(StackDnaYear(year: year, counts: bucket, dominantId: dominant));
    }
  }

  final main = [
    for (final item in all)
      if (item.share >= stackDnaMainShare) item.id,
  ].take(stackDnaMainLimit).toList();
  if (main.isEmpty && all.isNotEmpty) main.add(all.first.id);

  final rising = <String>[];
  if (years.where((year) => year.hasData).length >= 2) {
    final latest = years.last.year;
    var recentTotal = 0;
    var earlierTotal = 0;
    final recent = <String, int>{};
    final earlier = <String, int>{};
    for (final year in years) {
      final target = year.year >= latest - 1 ? recent : earlier;
      year.counts.forEach(
        (id, value) => target[id] = (target[id] ?? 0) + value,
      );
    }
    recentTotal = recent.values.fold(0, (sum, value) => sum + value);
    earlierTotal = earlier.values.fold(0, (sum, value) => sum + value);
    if (recentTotal > 0 && earlierTotal > 0) {
      for (final item in all) {
        final recentCount = recent[item.id] ?? 0;
        // now - before >= delta без накопления ошибки double.
        final gap =
            recentCount * earlierTotal - (earlier[item.id] ?? 0) * recentTotal;
        if (recentCount > 0 &&
            gap / (recentTotal * earlierTotal) >= stackDnaRisingDelta - 1e-9) {
          rising.add(item.id);
        }
      }
    }
  }

  return StackDna(
    shares: shares,
    all: all,
    years: years,
    mainStack: main,
    rising: rising,
    projectCount: projectCount,
    undatedCount: undated,
  );
}
