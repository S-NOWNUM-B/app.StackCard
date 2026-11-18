import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

PortfolioProject _project(String id, List<String> tech, int year) =>
    PortfolioProject(
      id: id,
      title: id,
      description: '',
      technologies: tech,
      updatedAt: DateTime.utc(year, 3, 1),
    );

Future<MemoryPortfolioDraftRepository> _repository(
  List<PortfolioProject> projects,
) async {
  final repository = MemoryPortfolioDraftRepository();
  await repository.save(
    PortfolioContent(projects: projects),
    expectedRevision: 0,
    notes: 'private',
  );
  return repository;
}

Future<(ProviderContainer, MemoryPortfolioDraftRepository)> _open(
  WidgetTester tester,
  List<PortfolioProject> projects, {
  ThemeData? theme,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = await _repository(projects);
  final router = GoRouter(
    initialLocation: '/stack-dna',
    routes: [
      GoRoute(path: '/stack-dna', builder: (_, _) => const StackDnaScreen()),
      GoRoute(path: '/github-import', builder: (_, _) => const Text('import')),
      GoRoute(path: '/projects', builder: (_, _) => const Text('projects')),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme ?? StackCardTheme.light,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, repository);
}

final _rich = [
  _project('a', ['Java', 'SQL'], 2020),
  _project('b', ['Java'], 2021),
  _project('c', ['Kotlin', 'js'], 2024),
  _project('d', ['Kotlin', 'JavaScript'], 2024),
  _project('e', ['Kotlin'], 2023),
];

void main() {
  testWidgets('Empty portfolio suggests connecting GitHub', (tester) async {
    await _open(tester, const []);
    expect(find.byKey(const Key('dna.empty')), findsOneWidget);
    expect(
      find.text('Подключите GitHub или добавьте технологии в проекты'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('dna.import')));
    await tester.pumpAndSettle();
    expect(find.text('import'), findsOneWidget);
  });

  testWidgets('Few projects show a low-data note instead of conclusions', (
    tester,
  ) async {
    await _open(tester, [
      _project('a', ['Dart'], 2024),
    ]);
    expect(find.byKey(const Key('dna.lowData')), findsOneWidget);
    expect(find.byKey(const Key('dna.main')), findsNothing);
    expect(find.byKey(const Key('dna.bar')), findsOneWidget);
  });

  testWidgets('Shows shares, main stack, rising and years with gaps', (
    tester,
  ) async {
    await _open(tester, _rich);
    expect(find.byKey(const Key('dna.lowData')), findsNothing);
    expect(find.byKey(const Key('dna.main')), findsOneWidget);
    expect(find.byKey(const Key('dna.rising')), findsOneWidget);
    expect(find.text('JavaScript'), findsOneWidget);
    expect(find.byKey(const Key('dna.item.javascript')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('dna.year.2022.empty')),
      300,
    );
    expect(find.byKey(const Key('dna.year.2022.empty')), findsOneWidget);
    expect(find.byKey(const Key('dna.year.2024')), findsOneWidget);
  });

  testWidgets('The chart has a text description for screen readers', (
    tester,
  ) async {
    await _open(tester, _rich);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Доли технологий: ')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('The feature reads only: no draft changes, no writes', (
    tester,
  ) async {
    final (container, repository) = await _open(tester, _rich);
    final revision = (await repository.read())!.revision;
    final before = container.read(portfolioDraftControllerProvider).content;
    await tester.pumpAndSettle();
    final state = container.read(portfolioDraftControllerProvider);
    expect(state.content, before);
    expect(state.hasUnsavedChanges, isFalse);
    expect((await repository.read())!.revision, revision);
  });

  testWidgets('Long technology names do not overflow at 320', (tester) async {
    await _open(tester, [
      _project('a', [
        'Очень-длинное-название-технологии-без-пробелов-для-проверки',
      ], 2022),
      _project('b', [
        'Другая очень длинная технология с несколькими словами подряд',
      ], 2023),
      _project('c', ['Dart'], 2024),
    ], width: 320);
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'light': StackCardTheme.light,
    'dark': StackCardTheme.dark,
  }.entries) {
    for (final width in [320.0, 390.0]) {
      testWidgets('Screen fits in ${entry.key} at $width', (tester) async {
        await _open(tester, _rich, theme: entry.value, width: width);
        expect(find.byKey(const Key('dna.bar')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final scaffold = tester.element(find.byType(Scaffold).first);
        expect(
          Theme.of(scaffold).brightness,
          entry.key == 'dark' ? Brightness.dark : Brightness.light,
        );
      });
    }
  }
}
