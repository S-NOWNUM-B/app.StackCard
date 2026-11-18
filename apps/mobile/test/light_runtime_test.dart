import 'dart:async';

import 'package:app_stackcard/app/local_runtime.dart';
import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/core/state/settings_repository.dart';
import 'package:app_stackcard/core/theme/stackcard_colors.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  for (final route in ['/home', '/projects', '/editor']) {
    testWidgets('Saved dark English settings render dark Russian $route', (
      tester,
    ) async {
      final repository = _Settings();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: route,
          initialThemeMode: ThemeMode.system,
          initialSettings: repository.stored,
          settingsRepository: repository,
        ),
      );
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.locale, const Locale('ru'));
      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        StackCardColors.dark.background,
      );
      expect(AppStrings.of(context).locale, const Locale('ru'));
      final navigation = find.byType(NavigationBar);
      expect(navigation, findsOneWidget);
      for (final label in ['Главная', 'Проекты', 'Редактор']) {
        expect(
          find.descendant(of: navigation, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(find.text('Резюме'), findsNothing);
      expect(MediaQuery.disableAnimationsOf(context), isTrue);
      expect(repository.writes, isEmpty);
      expect(
        repository.stored,
        const AppSettings(
          theme: AppTheme.dark,
          language: AppLanguage.en,
          showSourceDescriptions: false,
          reducedMotion: true,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('System theme mode follows OS brightness changes', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      const StackCardApp(
        initialLocation: '/projects',
        initialSettings: AppSettings(theme: AppTheme.system),
      ),
    );
    await tester.pumpAndSettle();
    Brightness current() =>
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness;
    expect(current(), Brightness.light);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(current(), Brightness.dark);
  });

  testWidgets(
    'Startup loading and failure follow the system theme before settings load',
    (tester) async {
      final pending = Completer<LocalRuntime>();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        StackCardBootstrap(loadRuntime: () => pending.future),
      );
      await tester.pump();
      final loading = tester.element(find.byType(Scaffold));
      expect(Theme.of(loading).brightness, Brightness.dark);
      expect(AppStrings.of(loading).locale, const Locale('ru'));

      pending.completeError(StateError('private startup diagnostic'));
      await tester.pumpAndSettle();
      final error = tester.element(find.byType(Scaffold));
      expect(Theme.of(error).brightness, Brightness.dark);
      expect(AppStrings.of(error).locale, const Locale('ru'));
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.textContaining('private startup diagnostic'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Settings implements SettingsRepository {
  AppSettings stored = const AppSettings(
    theme: AppTheme.dark,
    language: AppLanguage.en,
    showSourceDescriptions: false,
    reducedMotion: true,
  );
  final writes = <AppSettings>[];

  @override
  Future<AppSettings> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    writes.add(settings);
    stored = settings;
  }
}
