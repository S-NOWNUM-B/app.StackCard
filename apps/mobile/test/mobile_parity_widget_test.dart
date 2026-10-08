import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/localization/mobile_parity_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/home/home_screen.dart';
import 'package:app_stackcard/features/media/media.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:app_stackcard/shared/widgets/stackcard_technology_badge.dart';
import 'package:app_stackcard/shared/widgets/stackcard_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Parity labels have complete ru/en app catalogue coverage', () {
    expect(
      russianMobileParityStrings.keys.toSet(),
      englishMobileParityStrings.keys.toSet(),
    );
    for (final locale in AppStrings.supportedLocales) {
      expect(
        AppStrings(locale).keys,
        containsAll(englishMobileParityStrings.keys),
      );
    }
  });

  testWidgets(
    'Copy is a sibling action, succeeds only after the clipboard write and clears on URL replacement',
    (tester) async {
      var opened = 0;
      var clipboard = '';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await _pump(
        tester,
        liveUrl: 'https://example.com/demo',
        onOpen: () => opened++,
      );
      expect(
        tester.getSize(
          find.byWidgetPredicate(
            (widget) => widget is StackCardIcon && widget.name == 'copy',
          ),
        ),
        const Size(20, 20),
      );
      await tester.tap(find.text('Копировать'));
      await tester.pumpAndSettle();
      expect(clipboard, 'https://example.com/demo');
      expect(opened, 0);
      expect(find.text('Скопировано'), findsOneWidget);
      await _pump(
        tester,
        liveUrl: 'https://example.com/next',
        onOpen: () => opened++,
      );
      expect(find.text('Скопировано'), findsNothing);
      expect(find.text('Копировать'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-project')));
      expect(opened, 1);
    },
  );

  testWidgets(
    'Home filters retain a selected check and project search keeps its original 24px SVG',
    (tester) async {
      await _pump(tester, screen: const HomeScreen());
      final check = find.byWidgetPredicate(
        (widget) => widget is StackCardIcon && widget.name == 'check',
      );
      expect(tester.getSize(check), const Size(16, 16));
      await tester.tap(find.byKey(const ValueKey('home.filter.2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home.filter.2')), findsOneWidget);
      expect(tester.getSize(check), const Size(16, 16));
      await _pump(tester, screen: const ProjectsScreen());
      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();
        expect(find.bySemanticsLabel('Проекты: 4'), findsOneWidget);
        final search = find.byWidgetPredicate(
          (widget) => widget is StackCardIcon && widget.name == 'search',
        );
        expect(tester.getSize(search), const Size(24, 24));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('Clipboard failure preserves Copy and never reports success', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _pump(tester, liveUrl: 'https://example.com/demo');
    await tester.tap(find.text('Копировать'));
    await tester.pumpAndSettle();
    expect(find.text('Скопировано'), findsNothing);
    expect(find.text('Не удалось скопировать ссылку.'), findsOneWidget);
    expect(find.text('Копировать'), findsOneWidget);
  });

  testWidgets(
    'Cover placeholder follows its title and gives way to selected media',
    (tester) async {
      Widget editor(List<String> paths) => ProviderScope(
        overrides: [
          portfolioMediaRepositoryProvider.overrideWithValue(
            _CoverRepository(),
          ),
        ],
        child: SingleChildScrollView(
          child: PortfolioMediaEditor(
            paths: paths,
            titleKey: 'mobileParity.cover',
            emptyState: const Text('No cover yet'),
            onChanged: (_) {},
            onBusyChanged: (_) {},
          ),
        ),
      );
      await _pump(tester, screen: editor(const []));
      final title = find.text('Обложка');
      final placeholder = find.text('No cover yet');
      final gallery = find.byKey(const ValueKey('media_gallery'));
      expect(
        tester.getTopLeft(title).dy,
        lessThan(tester.getTopLeft(placeholder).dy),
      );
      expect(
        tester.getTopLeft(placeholder).dy,
        lessThan(tester.getTopLeft(gallery).dy),
      );
      await _pump(
        tester,
        screen: editor(const [
          'accounts/owner/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg',
        ]),
      );
      expect(find.text('No cover yet'), findsNothing);
      expect(gallery, findsOneWidget);
      expect(find.byType(PortfolioMediaImage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final url in [
    '',
    'javascript:alert(1)',
    'https://person:secret@example.com',
  ]) {
    testWidgets('Absent or invalid URL is unavailable: $url', (tester) async {
      await _pump(tester, liveUrl: url);
      expect(find.text('Нет ссылки'), findsOneWidget);
      final button = tester.widget<StackCardButton>(
        find.byType(StackCardButton),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Ссылка не добавлена'), findsOneWidget);
    });
  }

  testWidgets(
    'Four compact badges and a separate More action reveal the full list',
    (tester) async {
      await _pump(
        tester,
        technologies: const [
          'React',
          'TypeScript',
          'Flutter',
          'Dart',
          'Kotlin',
          'PostgreSQL',
          'Docker',
        ],
      );
      expect(find.byType(StackCardTechnologyBadge), findsNWidgets(4));
      expect(find.text('+3'), findsOneWidget);
      final action = find.byType(StackCardMoreTechnologies);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Технологии проекта'), findsOneWidget);
      expect(find.text('Kotlin'), findsOneWidget);
      expect(find.text('PostgreSQL'), findsOneWidget);
      expect(find.text('Docker'), findsOneWidget);
    },
  );

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    for (final locale in [const Locale('ru'), const Locale('en')]) {
      testWidgets(
        'Card cover and all actions reflow at 320px scale 2: $theme/$locale',
        (tester) async {
          await _pump(
            tester,
            size: const Size(320, 640),
            scale: 2,
            theme: theme,
            locale: locale,
            liveUrl: 'https://example.com/demo',
            technologies: const [
              'React',
              'TypeScript',
              'Flutter',
              'Dart',
              'An unusually long technology name',
            ],
          );
          expect(tester.getSize(find.byType(ProjectLibraryCover)).height, 104);
          await tester.ensureVisible(find.byType(StackCardButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _CoverRepository implements PortfolioMediaRepository {
  @override
  String get ownerUid => 'owner';

  @override
  Future<Uint8List> read(String path) async =>
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);

  @override
  Future<String> upload(
    PreparedPortfolioImage image, {
    required void Function(double) onProgress,
  }) async =>
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);

  @override
  Future<void> delete(String path) async {}
}

Future<void> _pump(
  WidgetTester tester, {
  String liveUrl = '',
  List<String> technologies = const [],
  VoidCallback? onOpen,
  Size size = const Size(390, 844),
  double scale = 1,
  Locale locale = const Locale('ru'),
  ThemeMode theme = ThemeMode.dark,
  Widget? screen,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: StackCardTheme.light,
        darkTheme: StackCardTheme.dark,
        themeMode: theme,
        locale: locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child:
                screen ??
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ProjectLibraryCard(
                    key: const ValueKey('card'),
                    openKey: const ValueKey('open-project'),
                    title: 'A project with a descriptive name',
                    description: 'A useful description with longer text to check wrapping.',
                    technologies: technologies,
                    sourceLabel: 'GitHub · example/project',
                    liveUrl: liveUrl,
                    onOpen: onOpen,
                  ),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
