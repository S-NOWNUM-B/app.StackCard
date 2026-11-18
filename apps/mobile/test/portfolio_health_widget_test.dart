import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _now = DateTime.utc(2026, 11, 16);

PortfolioHealth _partial() => buildPortfolioHealth(
  content: PortfolioContent(
    profile: const PortfolioProfile(name: 'Имя'),
    projects: [
      PortfolioProject(
        id: 'p1',
        title: 'Очень длинное название проекта для проверки переноса строк',
        description: '',
        technologies: const [],
      ),
    ],
  ),
  now: _now,
  published: false,
);

PortfolioHealth _perfect() => PortfolioHealth(score: 100, checks: const []);

GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (_, _) => const Scaffold(body: PortfolioHealthCard()),
    ),
    GoRoute(path: '/health', builder: (_, _) => const PortfolioHealthScreen()),
    GoRoute(path: '/editor', builder: (_, _) => const Text('editor stub')),
  ],
);

Future<ProviderContainer> _open(
  WidgetTester tester, {
  required PortfolioHealth? health,
  ThemeData? theme,
  double width = 390,
  String path = '/home',
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = _router()..go(path);
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [portfolioHealthProvider.overrideWithValue(health)],
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
  return container;
}

void main() {
  testWidgets('Card shows score and tip count, then opens details', (
    tester,
  ) async {
    final health = _partial();
    await _open(tester, health: health);
    expect(find.text('Здоровье портфолио'), findsOneWidget);
    expect(find.text('${health.score}'), findsOneWidget);
    expect(find.text('Советов: ${health.improvements.length}'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home.health')));
    await tester.pumpAndSettle();
    expect(find.byType(PortfolioHealthScreen), findsOneWidget);
  });

  testWidgets('Details use the shared screen header with a localized Back', (
    tester,
  ) async {
    await _open(tester, health: _partial(), path: '/health');
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Назад'), findsOneWidget);
  });

  testWidgets('Card is hidden while there is no saved portfolio', (
    tester,
  ) async {
    await _open(tester, health: null);
    expect(find.byKey(const Key('home.health')), findsNothing);
  });

  testWidgets('A perfect portfolio shows 100 and no tips', (tester) async {
    await _open(tester, health: _perfect());
    expect(find.text('Всё в порядке'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home.health')));
    await tester.pumpAndSettle();
    expect(find.text('Отлично, советов нет'), findsOneWidget);
    expect(find.text('Что улучшить'), findsNothing);
  });

  testWidgets('Details without a portfolio explain what to do', (tester) async {
    await _open(tester, health: null, path: '/health');
    expect(find.byKey(const Key('health.empty')), findsOneWidget);
  });

  testWidgets(
    'A tip leads to the matching Editor section and stays read-only',
    (tester) async {
      final container = await _open(
        tester,
        health: _partial(),
        path: '/health',
      );
      final tip = find.textContaining('нет описания');
      expect(tip, findsOneWidget);
      await tester.ensureVisible(tip);
      final button = find.descendant(
        of: find.ancestor(of: tip, matching: find.byType(Column)).first,
        matching: find.text('Открыть в Редакторе'),
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('editor stub'), findsOneWidget);
      expect(
        container.read(mainPortfolioEditorFocusProvider),
        PortfolioHealthSection.projects,
      );
    },
  );

  testWidgets('The publication tip opens Home instead of the Editor', (
    tester,
  ) async {
    final container = await _open(tester, health: _partial(), path: '/health');
    final action = find.text('Открыть Главную');
    await tester.scrollUntilVisible(action, 300);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.health')), findsOneWidget);
    expect(container.read(mainPortfolioEditorFocusProvider), isNull);
  });

  for (final entry in {
    'light': StackCardTheme.light,
    'dark': StackCardTheme.dark,
  }.entries) {
    for (final width in [320.0, 390.0]) {
      testWidgets(
        'Card and details render in ${entry.key} at $width without overflow',
        (tester) async {
          await _open(
            tester,
            health: _partial(),
            theme: entry.value,
            width: width,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('home.health')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('health.score')), findsOneWidget);
          expect(tester.takeException(), isNull);
          final scaffold = tester.element(find.byType(Scaffold).first);
          expect(
            Theme.of(scaffold).brightness,
            entry.key == 'dark' ? Brightness.dark : Brightness.light,
          );
        },
      );
    }
  }
}
