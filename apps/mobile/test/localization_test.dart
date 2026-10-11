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
    'Legacy English preference renders Russian light UI before the screen appears',
    (tester) async {
      await tester.pumpWidget(
        const StackCardApp(
          initialLocation: '/settings/appearance',
          initialThemeMode: ThemeMode.dark,
          initialSettings: AppSettings(
            theme: AppTheme.light,
            language: AppLanguage.en,
          ),
        ),
      );
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
      expect(app.locale, const Locale('ru'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsNothing);
      expect(find.text('Приложение'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Приложение'))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reduced motion retains Russian route and failed persistence retries explicitly',
    (tester) async {
      final repository = _Settings()..failNext = true;
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/settings/appearance',
          settingsRepository: repository,
        ),
      );
      await tester.pumpAndSettle();
      final router = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .routerConfig;
      final motionSwitch = find.byKey(const Key('settings.reducedMotion'));
      await tester.ensureVisible(motionSwitch);
      await tester.tap(motionSwitch);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router),
      );
      expect(find.text('Не удалось сохранить настройки'), findsOneWidget);
      expect(repository.stored.language, AppLanguage.ru);
      expect(repository.stored.reducedMotion, isFalse);
      expect(
        MediaQuery.disableAnimationsOf(tester.element(motionSwitch)),
        isTrue,
      );
      await tester.ensureVisible(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(repository.stored.language, AppLanguage.ru);
      expect(find.text('Не удалось сохранить настройки'), findsNothing);
      expect(repository.stored.reducedMotion, isTrue);
      expect(repository.stored.showSourceDescriptions, isTrue);
      expect(find.text('English'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final item in [
    (route: '/home', heading: 'Портфолио пока пустое'),
    (route: '/editor', heading: 'Имя'),
    (route: '/projects', heading: 'Проекты: 4'),
    (route: '/settings', heading: 'Настройки'),
    (route: '/settings/appearance', heading: 'Приложение'),
    (route: '/settings/account', heading: 'Аккаунт и безопасность'),
    (route: '/settings/github', heading: 'GitHub'),
  ]) {
    testWidgets(
      'Russian UI ignores English legacy choice on ${item.route} with enlarged text',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          StackCardApp(
            initialLocation: item.route,
            initialSettings: const AppSettings(language: AppLanguage.en),
          ),
        );
        await tester.pumpAndSettle();
        if (item.route == '/home') {
          await tester.scrollUntilVisible(
            find.text(item.heading),
            200,
            scrollable: find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down,
                )
                .last,
          );
        }
        expect(
          item.route == '/projects'
              ? find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.label == item.heading,
                )
              : find.text(item.heading),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Legacy English choice leaves form validation in Russian', (
    tester,
  ) async {
    await tester.pumpWidget(
      const StackCardApp(
        initialSettings: AppSettings(language: AppLanguage.en),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.ensureVisible(find.text('Продолжить'));
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Укажите корректную электронную почту'), findsOneWidget);
    expect(find.text('Enter a valid email'), findsNothing);
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
