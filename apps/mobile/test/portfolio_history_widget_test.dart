import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_colors.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_history_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _time = DateTime.utc(2026, 11, 16, 10);

PortfolioContent _workspace(String name, {int projects = 1}) {
  final ids = [for (var i = 0; i < projects; i++) 'p$i'];
  return PortfolioContent(
    projects: [
      for (final id in ids)
        PortfolioProject(
          id: id,
          title: 'Очень длинное название проекта номер $id для проверки',
          description: 'Описание',
          technologies: const ['Dart'],
        ),
    ],
    mainPortfolioId: 'main',
    documents: [
      PortfolioDocument(
        id: 'main',
        title: 'Основное',
        kind: PortfolioDocumentKind.portfolio,
        createdAt: _time,
        updatedAt: _time,
        content: PortfolioContent(
          profile: PortfolioProfile(name: name, headline: 'Разработчик'),
          skills: const [Skill(id: 's', name: 'Dart')],
        ),
        projects: [
          for (final id in ids) PortfolioProjectAttachment(projectId: id),
        ],
      ),
    ],
  );
}

Future<MemoryPortfolioHistoryRepository> _seed() async {
  final repository = MemoryPortfolioHistoryRepository();
  await repository.record(_workspace('Первая'), _time);
  await repository.record(
    _workspace('Вторая', projects: 2),
    _time.add(const Duration(hours: 1)),
  );
  return repository;
}

Future<ProviderContainer> _open(
  WidgetTester tester, {
  PortfolioHistoryRepository? repository,
  List<Override> overrides = const [],
  ThemeData? theme,
  double width = 390,
  String path = '/history',
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/history',
        builder: (_, _) => const PortfolioHistoryScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => PortfolioHistoryVersionScreen(
              snapshotId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(path: '/editor', builder: (_, _) => const Text('editor stub')),
      GoRoute(path: '/home', builder: (_, _) => const Text('home stub')),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      if (repository != null)
        portfolioHistoryRepositoryFactoryProvider.overrideWithValue(
          (_) => repository,
        ),
      ...overrides,
    ],
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
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  testWidgets('Empty history explains when versions appear', (tester) async {
    await _open(tester, repository: MemoryPortfolioHistoryRepository());
    expect(find.text('Пока нет сохранённых версий'), findsOneWidget);
  });

  testWidgets('Loading and error states are shown, error can retry', (
    tester,
  ) async {
    final never = Completer<List<PortfolioSnapshot>>();
    await _open(
      tester,
      overrides: [
        portfolioHistoryListProvider.overrideWith((ref) => never.future),
      ],
    );
    expect(find.text('Загрузка версий'), findsOneWidget);
  });

  testWidgets('A failing store shows an error with retry', (tester) async {
    var calls = 0;
    await _open(
      tester,
      overrides: [
        portfolioHistoryListProvider.overrideWith((ref) async {
          calls++;
          throw const PortfolioHistoryFailure();
        }),
      ],
    );
    expect(find.text('Не удалось загрузить версии'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('List shows newest first with counts and what changed', (
    tester,
  ) async {
    await _open(tester, repository: await _seed());
    expect(find.text('Проектов: 2 · Навыков: 1'), findsOneWidget);
    expect(find.text('Проектов: 1 · Навыков: 1'), findsOneWidget);
    expect(find.textContaining('добавлено проектов: 1'), findsOneWidget);
    expect(find.textContaining('изменён профиль'), findsOneWidget);
    expect(find.text('первая версия'), findsOneWidget);
    final newer = tester.getTopLeft(find.text('Проектов: 2 · Навыков: 1'));
    final older = tester.getTopLeft(find.text('Проектов: 1 · Навыков: 1'));
    expect(newer.dy, lessThan(older.dy));
  });

  testWidgets('Version view is read-only and always light', (tester) async {
    final repository = await _seed();
    final first = (await repository.list()).last;
    await _open(
      tester,
      repository: repository,
      theme: StackCardTheme.dark,
      path: '/history/${first.id}',
    );
    expect(find.text('Первая'), findsOneWidget);
    final inner = tester.element(find.text('Первая'));
    expect(Theme.of(inner).brightness, Brightness.light);
    expect(inner.colors.surface, StackCardColors.light.surface);
    // Хром экрана следует тёмной теме.
    final scaffold = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(scaffold).brightness, Brightness.dark);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('A missing version says so', (tester) async {
    await _open(
      tester,
      repository: await _seed(),
      path: '/history/does-not-exist',
    );
    expect(find.text('Версия не найдена'), findsOneWidget);
  });

  testWidgets('Restore asks for confirmation, then hands over to the Editor', (
    tester,
  ) async {
    final repository = await _seed();
    final snapshot = (await repository.list()).last;
    final container = await _open(
      tester,
      repository: repository,
      path: '/history/${snapshot.id}',
    );
    await tester.tap(find.byKey(const Key('history.restore')));
    await tester.pumpAndSettle();
    expect(find.textContaining('несохранённые изменения'), findsOneWidget);
    await tester.tap(find.byKey(const Key('history.restore.cancel')));
    await tester.pumpAndSettle();
    expect(container.read(mainPortfolioEditorRestoreProvider), isNull);
    expect(find.text('editor stub'), findsNothing);

    await tester.tap(find.byKey(const Key('history.restore')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history.restore.confirm')));
    await tester.pumpAndSettle();
    expect(container.read(mainPortfolioEditorRestoreProvider)?.id, snapshot.id);
    expect(find.text('editor stub'), findsOneWidget);
    // Откат ничего не записал в историю.
    expect(await repository.list(), hasLength(2));
  });

  for (final entry in {
    'light': StackCardTheme.light,
    'dark': StackCardTheme.dark,
  }.entries) {
    for (final width in [320.0, 390.0]) {
      testWidgets('History screens fit in ${entry.key} at $width', (
        tester,
      ) async {
        final repository = await _seed();
        await _open(
          tester,
          repository: repository,
          theme: entry.value,
          width: width,
        );
        expect(find.byKey(const Key('history.list')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('history.restore')), findsOneWidget);
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
