import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/stack_dna.dart';
import 'package:flutter_test/flutter_test.dart';

StackDnaProject _p(
  String id, {
  List<String> tech = const [],
  String? language,
  int? year,
}) => StackDnaProject(
  id: id,
  title: id,
  technologies: tech,
  language: language,
  date: year == null ? null : DateTime.utc(year, 6, 1),
);

void main() {
  test('Пустые данные дают пустой результат без падений', () {
    final dna = buildStackDna(const []);
    expect(dna.isEmpty, isTrue);
    expect(dna.isLowData, isFalse);
    expect(dna.shares, isEmpty);
    expect(dna.years, isEmpty);
    expect(dna.mainStack, isEmpty);
    final blank = buildStackDna([
      _p('a', tech: ['  ', '']),
    ]);
    expect(blank.isEmpty, isTrue);
  });

  test('Один язык: доля 100%, он же главный стек, мало данных', () {
    final dna = buildStackDna([_p('a', language: 'Dart', year: 2024)]);
    expect(dna.all.single.share, 1);
    expect(dna.mainStack, ['dart']);
    expect(dna.isLowData, isTrue);
    expect(dna.rising, isEmpty);
  });

  test('Синонимы сводятся к одному названию и не дублируются в проекте', () {
    final dna = buildStackDna([
      _p('a', tech: ['js', 'JavaScript'], language: 'JavaScript'),
      _p('b', tech: ['ECMAScript', 'ts']),
      _p('c', tech: ['Postgres', 'PostgreSQL']),
    ]);
    final js = dna.all.firstWhere((item) => item.id == 'javascript');
    expect(js.label, 'JavaScript');
    expect(js.count, 2);
    expect(
      dna.all.firstWhere((item) => item.id == 'typescript').label,
      'TypeScript',
    );
    expect(dna.all.firstWhere((item) => item.id == 'postgresql').count, 1);
  });

  test(
    'Неизвестные технологии сохраняют написание и сводятся без учёта регистра',
    () {
      final dna = buildStackDna([
        _p('a', tech: ['Zustand']),
        _p('b', tech: ['zustand']),
      ]);
      expect(dna.all.single.label, 'Zustand');
      expect(dna.all.single.count, 2);
    },
  );

  test('Доли в сумме дают 1; топ-N и «Другие»', () {
    final dna = buildStackDna([
      for (var i = 0; i < 9; i++) _p('p$i', tech: ['T$i']),
    ]);
    expect(dna.shares, hasLength(stackDnaTopCount + 1));
    expect(dna.shares.last.isOther, isTrue);
    expect(dna.shares.last.count, 3);
    expect(
      dna.shares.fold<double>(0, (sum, item) => sum + item.share),
      closeTo(1, 1e-9),
    );
  });

  test('Равные доли упорядочены по названию, результат детерминирован', () {
    final dna = buildStackDna([
      _p('a', tech: ['Rust']),
      _p('b', tech: ['Dart']),
      _p('c', tech: ['Kotlin']),
    ]);
    expect(dna.all.map((item) => item.label), ['Dart', 'Kotlin', 'Rust']);
    expect(
      buildStackDna([
        _p('a', tech: ['Rust']),
      ]).all.single.id,
      'rust',
    );
  });

  test('Годы без данных остаются пустыми, доминанта по году', () {
    final dna = buildStackDna([
      _p('a', tech: ['Java'], year: 2021),
      _p('b', tech: ['Java', 'Kotlin'], year: 2021),
      _p('c', tech: ['Dart'], year: 2024),
    ]);
    expect(dna.years.map((year) => year.year), [2021, 2022, 2023, 2024]);
    expect(dna.years[1].hasData, isFalse);
    expect(dna.years[1].dominantId, isNull);
    expect(dna.years.first.dominantId, 'java');
    expect(dna.years.last.dominantId, 'dart');
    final java = dna.all.firstWhere((item) => item.id == 'java');
    expect((java.firstYear, java.lastYear), (2021, 2021));
  });

  test('Проекты без даты считаются в долях, но не во временном ряду', () {
    final dna = buildStackDna([
      _p('a', tech: ['Dart']),
      _p('b', tech: ['Dart'], year: 2023),
    ]);
    expect(dna.projectCount, 2);
    expect(dna.undatedCount, 1);
    expect(dna.years.single.counts, {'dart': 1});
  });

  test('Растущая технология: доля в последних двух годах заметно выше', () {
    final dna = buildStackDna([
      _p('a', tech: ['Java'], year: 2020),
      _p('b', tech: ['Java'], year: 2021),
      _p('c', tech: ['Kotlin'], year: 2024),
      _p('d', tech: ['Kotlin'], year: 2024),
      _p('e', tech: ['Java'], year: 2023),
    ]);
    expect(dna.rising, ['kotlin']);
    expect(dna.mainStack, containsAll(['java', 'kotlin']));
  });

  test('Рост не объявляется без достаточного числа лет', () {
    final dna = buildStackDna([
      _p('a', tech: ['Dart'], year: 2024),
      _p('b', tech: ['Rust'], year: 2024),
    ]);
    expect(dna.rising, isEmpty);
  });

  test('Главный стек: не больше трёх, с порогом доли', () {
    final dna = buildStackDna([
      _p('a', tech: ['A', 'B', 'C', 'D', 'E']),
      _p('b', tech: ['A', 'B', 'C', 'D', 'E']),
    ]);
    expect(dna.mainStack, hasLength(stackDnaMainLimit));
  });

  test(
    'Для GitHub-проекта берётся дата репозитория, не правка в приложении',
    () {
      final content = PortfolioContent(
        projects: [
          PortfolioProject(
            id: 'g',
            title: 'g',
            description: '',
            technologies: const ['Dart'],
            updatedAt: DateTime.utc(2026, 1, 1),
            githubMetadata: GitHubProjectMetadata(
              acceptedSource: GitHubProjectSource(
                repositoryId: 1,
                name: 'r',
                fullName: 'o/r',
                htmlUrl: 'https://github.com/o/r',
                stars: 0,
                forks: 0,
                isFork: false,
                archived: false,
                updatedAt: DateTime.utc(2021, 2, 1),
              ),
            ),
          ),
        ],
      );
      expect(
        stackDnaProjectsFrom(content).single.date,
        DateTime.utc(2021, 2, 1),
      );
    },
  );

  test('Скрытые проекты не входят в стек', () {
    final input = stackDnaProjectsFrom(
      PortfolioContent(
        projects: [
          PortfolioProject(
            id: 'h',
            title: 'h',
            description: '',
            technologies: const ['Rust'],
            visible: false,
          ),
          PortfolioProject(
            id: 'v',
            title: 'v',
            description: '',
            technologies: const ['Dart'],
          ),
        ],
      ),
    );
    expect(input.map((p) => p.id), ['v']);
  });

  test('Jest не сливается с обобщённым «Тестированием»', () {
    final dna = buildStackDna([
      _p('a', tech: ['Jest']),
      _p('b', tech: ['Unit tests']),
    ]);
    expect(dna.all.map((item) => item.label).toSet(), {'Jest', 'Тестирование'});
  });

  test('Битые годы не раздувают временной ряд', () {
    final dna = buildStackDna([
      _p('a', tech: ['Dart'], year: 1),
      _p('b', tech: ['Dart'], year: 9999),
      _p('c', tech: ['Dart'], year: 2024),
    ]);
    expect(dna.years.map((y) => y.year), [2024]);
    expect(dna.undatedCount, 2);
  });

  test('Порог роста включает ровно 10 п.п. без ошибки округления', () {
    // Раньше: 3/5 против 1/2 давало 0.0999… и не проходило порог.
    final dna = buildStackDna([
      _p('e1', tech: ['Java'], year: 2020),
      _p('e2', tech: ['Kotlin'], year: 2020),
      _p('r1', tech: ['Kotlin'], year: 2024),
      _p('r2', tech: ['Kotlin'], year: 2024),
      _p('r3', tech: ['Kotlin'], year: 2024),
      _p('r4', tech: ['Java'], year: 2024),
      _p('r5', tech: ['Java'], year: 2024),
    ]);
    expect(dna.rising, ['kotlin']);
  });

  test('Если ни одна доля не достигла порога, главным остаётся лидер', () {
    final dna = buildStackDna([
      for (var i = 0; i < 10; i++) _p('p$i', tech: ['T$i']),
    ]);
    expect(dna.mainStack, hasLength(1));
  });

  test('Технология с названием «other» не сливается со строкой «Другие»', () {
    final dna = buildStackDna([
      for (var i = 0; i < 7; i++) _p('p$i', tech: ['T$i']),
      _p('o1', tech: ['other']),
      _p('o2', tech: ['Other']),
    ]);
    final other = dna.shares.singleWhere((item) => item.isOther);
    expect(other.id, 'other');
    final named = dna.all.where((item) => item.label.toLowerCase() == 'other');
    expect(named, hasLength(1));
    expect(named.single.id, isNot('other'));
    expect(named.single.count, 2);
    expect(dna.shares.where((item) => item.id == 'other'), hasLength(1));
  });

  group('вход из портфолио', () {
    GitHubProjectSource source({bool fork = false, bool archived = false}) =>
        GitHubProjectSource(
          repositoryId: 1,
          name: 'r',
          fullName: 'o/r',
          htmlUrl: 'https://github.com/o/r',
          stars: 0,
          forks: 0,
          isFork: fork,
          archived: archived,
          updatedAt: DateTime.utc(2023, 5, 1),
          language: 'Rust',
        );

    PortfolioProject project(String id, GitHubProjectSource? github) =>
        PortfolioProject(
          id: id,
          title: id,
          description: '',
          technologies: const ['Dart'],
          source: github == null
              ? PortfolioProjectSource.manual
              : PortfolioProjectSource.github,
          githubMetadata: github == null
              ? null
              : GitHubProjectMetadata(acceptedSource: github),
        );

    test(
      'форки и архивные репозитории исключаются, язык и дата берутся из GitHub',
      () {
        final input = stackDnaProjectsFrom(
          PortfolioContent(
            projects: [
              project('own', source()),
              project('fork', source(fork: true)),
              project('old', source(archived: true)),
              project('manual', null),
            ],
          ),
        );
        expect(input.map((item) => item.id), ['own', 'manual']);
        expect(input.first.language, 'Rust');
        expect(input.first.date, DateTime.utc(2023, 5, 1));
        expect(input.last.date, isNull);
        final dna = buildStackDna(input);
        expect(dna.all.map((item) => item.id).toSet(), {'dart', 'rust'});
      },
    );
  });
}
