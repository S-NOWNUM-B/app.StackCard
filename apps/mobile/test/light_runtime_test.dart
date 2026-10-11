import 'dart:async';

import 'package:app_stackcard/app/local_runtime.dart';
import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/core/state/settings_repository.dart';
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
    testWidgets('Legacy dark English settings render light Russian $route', (
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
      expect(app.themeMode, ThemeMode.light);
      expect(app.locale, const Locale('ru'));
      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.light);
      expect(Theme.of(context).scaffoldBackgroundColor, Colors.white);
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

  testWidgets('Startup loading and failure remain light before settings load', (
    tester,
  ) async {
    final pending = Completer<LocalRuntime>();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      StackCardBootstrap(loadRuntime: () => pending.future),
    );
    await tester.pump();
    final loading = tester.element(find.byType(Scaffold));
    expect(Theme.of(loading).brightness, Brightness.light);
    expect(AppStrings.of(loading).locale, const Locale('ru'));

    pending.completeError(StateError('private startup diagnostic'));
    await tester.pumpAndSettle();
    final error = tester.element(find.byType(Scaffold));
    expect(Theme.of(error).brightness, Brightness.light);
    expect(AppStrings.of(error).locale, const Locale('ru'));
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.textContaining('private startup diagnostic'), findsNothing);
    expect(tester.takeException(), isNull);
  });
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
