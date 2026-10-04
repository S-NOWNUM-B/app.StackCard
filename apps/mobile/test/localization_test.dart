import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/core/state/settings_repository.dart';
import 'package:app_stackcard/features/settings/settings_screen.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Russian and English catalogs have matching keys and parameters', () {
    const russian = AppStrings(Locale('ru'));
    const english = AppStrings(Locale('en'));
    expect(russian.keys, english.keys);
    final parameterPattern = RegExp(r'\{(\w+)\}');
    for (final key in russian.keys) {
      final ru = russianAppStrings[key]!;
      final en = englishAppStrings[key]!;
      final ruParameters = parameterPattern
          .allMatches(ru)
          .map((match) => match[1]!)
          .toSet();
      final enParameters = parameterPattern
          .allMatches(en)
          .map((match) => match[1]!)
          .toSet();
      expect(ruParameters, enParameters, reason: key);
      expect(ru.trim(), isNotEmpty, reason: key);
      expect(en.trim(), isNotEmpty, reason: key);
      final values = {for (final name in ruParameters) name: '42'};
      expect(russian.tr(key, values), isNot(contains('{')), reason: key);
      expect(english.tr(key, values), isNot(contains('{')), reason: key);
    }
  });

  test('Counts use Russian plural forms and English singular', () {
    const russian = AppStrings(Locale('ru'));
    const english = AppStrings(Locale('en'));
    expect(russian.projectCount(1), '1 проект');
    expect(russian.projectCount(2), '2 проекта');
    expect(russian.projectCount(5), '5 проектов');
    expect(russian.projectCount(11), '11 проектов');
    expect(russian.skillCount(21), '21 навык');
    expect(english.projectCount(1), '1 project');
    expect(english.projectCount(2), '2 projects');
    expect(english.skillCount(5), '5 skills');
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets(
    'Restored appearance and language are applied before the screen appears',
    (tester) async {
      await tester.pumpWidget(
        const StackCardApp(
          initialLocation: '/settings',
          initialThemeMode: ThemeMode.dark,
          initialSettings: AppSettings(
            theme: AppTheme.light,
            language: AppLanguage.en,
          ),
        ),
      );
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
      expect(app.locale, const Locale('en'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Внешний вид'), findsNothing);
      expect(
        Theme.of(tester.element(find.text('Appearance'))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Changing language preserves the route and a failed write retries explicitly',
    (tester) async {
      final repository = _Settings()..failNext = true;
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/settings',
          settingsRepository: repository,
        ),
      );
      await tester.pumpAndSettle();
      final router = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .routerConfig;
      await tester.ensureVisible(find.text('English'));
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router),
      );
      expect(find.text('Unable to save settings'), findsOneWidget);
      expect(repository.stored.language, AppLanguage.ru);
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.stored.language, AppLanguage.en);
      expect(find.text('Unable to save settings'), findsNothing);
      final descriptionSwitch = find.byType(SwitchListTile);
      await tester.ensureVisible(descriptionSwitch);
      await tester.tap(descriptionSwitch);
      await tester.pumpAndSettle();
      expect(repository.stored.showSourceDescriptions, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final item in [
    (route: '/home', heading: 'Hello, Alex'),
    (route: '/portfolio', heading: 'Editor'),
    (route: '/projects', heading: 'Made by you'),
    (route: '/settings', heading: 'Appearance'),
  ]) {
    testWidgets('English UI on ${item.route} supports enlarged text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: item.route,
          initialSettings: const AppSettings(language: AppLanguage.en),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(item.heading), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('English form validation uses translated presentation copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const StackCardApp(
        initialSettings: AppSettings(language: AppLanguage.en),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.ensureVisible(find.text('Open demo'));
    await tester.tap(find.text('Open demo'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Укажите корректный email'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Settings implements SettingsRepository {
  AppSettings stored = const AppSettings();
  bool failNext = false;

  @override
  Future<AppSettings> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    if (failNext) {
      failNext = false;
      throw const SettingsFailure(SettingsFailureKind.write);
    }
    stored = settings;
  }
}
