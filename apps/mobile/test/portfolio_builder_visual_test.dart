import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in [
      ('DM Sans', 'assets/fonts/DM_Sans.ttf'),
      ('Noto Sans', 'assets/fonts/Noto_Sans.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(entry.$1)..addFont(rootBundle.load(entry.$2));
      await loader.load();
    }
  });

  const routes = {
    'hub': '/portfolio/builder',
    'profile': '/portfolio/builder/profile',
    'project': '/projects/new',
    'preview': '/portfolio/preview',
  };
  const viewports = {
    'phone_portrait': Size(390, 844),
    'tablet_landscape': Size(1024, 768),
    'small_phone': Size(320, 640),
  };

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    for (final language in AppLanguage.values) {
      for (final viewport in viewports.entries) {
        for (final scale
            in viewport.key == 'small_phone' ? [2.0] : [1.0, 2.0]) {
          for (final route in routes.entries) {
            testWidgets('Builder ${route.key} ${theme.name} ${language.name} '
                '${viewport.key} text $scale', (tester) async {
              _setViewport(tester, viewport.value, scale: scale);
              await _open(
                tester,
                route: route.value,
                theme: theme,
                language: language,
              );
              expect(tester.takeException(), isNull);
              expect(find.text(_privateNote), findsNothing);
              if (scale == 1) await _checkAccessibility(tester);
              if (const bool.fromEnvironment('UPDATE_UI_PREVIEWS') &&
                  scale == 1 &&
                  language == AppLanguage.ru) {
                await expectLater(
                  find.byType(MaterialApp),
                  matchesGoldenFile(
                    '../../../docs/design/previews/builder_${route.key}_'
                    '${theme.name}_${viewport.key}.png',
                  ),
                );
              }
              await tester.drag(
                find.byType(SingleChildScrollView).last,
                const Offset(0, -10000),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: 'Конец Builder страницы без overflow',
              );
              if (scale == 1) await _checkAccessibility(tester);
            });
          }
        }
      }
    }
  }

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    for (final language in AppLanguage.values) {
      testWidgets('Builder project and block controls accessible ${theme.name} '
          '${language.name}', (tester) async {
        _setViewport(tester, const Size(390, 844));
        await _open(
          tester,
          route: '/portfolio/builder',
          theme: theme,
          language: language,
        );
        for (final key in [
          'builder_featured_stackcard',
          'builder_block_up_about',
          'builder_block_down_about',
          'builder_theme_light',
        ]) {
          await tester.ensureVisible(find.byKey(ValueKey(key)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _checkAccessibility(tester);
        }
      });
    }
    for (final portfolioTheme in PortfolioTheme.values) {
      testWidgets(
        'Preview uses ${portfolioTheme.name} portfolio theme independently '
        'from ${theme.name} app',
        (tester) async {
          _setViewport(tester, const Size(390, 844));
          await _open(
            tester,
            route: '/portfolio/preview',
            theme: theme,
            portfolioTheme: portfolioTheme,
          );
          final profile = find.byKey(const ValueKey('portfolio_block_profile'));
          expect(profile, findsOneWidget);
          expect(
            Theme.of(tester.element(profile)).brightness,
            portfolioTheme == PortfolioTheme.dark
                ? Brightness.dark
                : Brightness.light,
          );
          final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
          expect(
            app.themeMode,
            theme == AppTheme.dark ? ThemeMode.dark : ThemeMode.light,
          );
          await _checkAccessibility(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final language in AppLanguage.values) {
    for (final route in ['profile', 'project']) {
      testWidgets('Builder $route keyboard text 2.0 ${language.name}', (
        tester,
      ) async {
        _setViewport(tester, const Size(320, 640), scale: 2);
        await _open(tester, route: routes[route]!, language: language);
        final field = find.byKey(
          ValueKey('builder_form_${route == 'profile' ? 'name' : 'title'}'),
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.enterText(field, 'A long editable portfolio title');
        await tester.pump();
        final cancel = find.byKey(const ValueKey('builder_form_cancel'));
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(360));
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        if (route == 'profile') {
          expect(find.byKey(const ValueKey('builder_status')), findsOneWidget);
        } else {
          expect(
            find.byKey(const ValueKey('project.leave.discard')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const ValueKey('project.leave.discard')),
          );
          await tester.tap(find.byKey(const ValueKey('project.leave.discard')));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('project_search')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

const _privateNote = 'PRIVATE NOTE — never render in portfolio preview';

PortfolioContent _content(PortfolioTheme theme) => PortfolioContent(
  theme: theme,
  profile: const PortfolioProfile(
    name: 'Станислав Мамаев',
    username: 'snownumb',
    headline: 'Fullstack Developer · Flutter & TypeScript',
    bio:
        'Создаю понятные приложения и изучаю архитектуру. '
        'Люблю проекты, в которых детали помогают человеку.',
    locationText: 'Алматы, Казахстан',
  ),
  skills: const [
    Skill(id: 'flutter', name: 'Flutter'),
    Skill(id: 'dart', name: 'Dart'),
    Skill(id: 'typescript', name: 'TypeScript'),
  ],
  projects: [
    PortfolioProject(
      id: 'stackcard',
      title: 'StackCard — Developer Portfolio',
      description:
          'Редактор портфолио с локальным черновиком, '
          'явным сохранением и предпросмотром.',
      technologies: const ['Flutter', 'Dart', 'Riverpod'],
      repositoryUrl: 'https://github.com/snownumb/stackcard',
      liveUrl:
          'https://example.com/a-long-portfolio-project-address/'
          'that-must-wrap-on-small-phone-screens',
      featured: true,
    ),
  ],
  experience: const [
    Experience(
      id: 'independent',
      role: 'Разработчик приложений',
      organization: 'Личные проекты',
      period: '2025 — сейчас',
      description: 'Прототипы, доступный интерфейс и проверка сценариев.',
    ),
  ],
  education: const [
    Education(
      id: 'almau',
      institution: 'AlmaU',
      qualification: 'Software Engineering',
      period: '2024 — 2028',
      description: 'Разработка программного обеспечения.',
    ),
  ],
  links: const [
    SocialLink(
      id: 'github',
      label: 'GitHub',
      url: 'https://github.com/snownumb',
      kind: SocialLinkKind.github,
    ),
    SocialLink(
      id: 'website',
      label: 'Личный сайт',
      url: 'https://example.com/snownumb',
      kind: SocialLinkKind.website,
    ),
  ],
  resumeText: 'Fullstack Developer\nFlutter · TypeScript\nАлматы, Казахстан',
);

void _setViewport(WidgetTester tester, Size size, {double scale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _open(
  WidgetTester tester, {
  required String route,
  AppTheme theme = AppTheme.dark,
  AppLanguage language = AppLanguage.ru,
  PortfolioTheme? portfolioTheme,
}) async {
  final repository = MemoryPortfolioDraftRepository(
    clock: () => DateTime.utc(2026, 10, 3),
  );
  await repository.save(
    _content(
      portfolioTheme ??
          (theme == AppTheme.dark ? PortfolioTheme.dark : PortfolioTheme.light),
    ),
    expectedRevision: 0,
    notes: _privateNote,
  );
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: route,
      initialSettings: AppSettings(theme: theme, language: language),
      providerOverrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _checkAccessibility(WidgetTester tester) async {
  // SDK guidelines измеряют обрезанные scroll-границей semantics как полные
  // элементы. Проверяем все controls без clipping при исходной ширине экрана.
  final size = tester.view.physicalSize;
  final scroll = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(SingleChildScrollView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  final extraHeight = scroll.position.maxScrollExtent.ceilToDouble();
  tester.view.physicalSize = Size(size.width, size.height + extraHeight + 16);
  await tester.pumpAndSettle();
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  } finally {
    semantics.dispose();
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }
}
