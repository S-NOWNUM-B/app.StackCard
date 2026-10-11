import 'package:app_stackcard/core/state/appearance_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Appearance defaults to light and retains legacy preference modes', () {
    final controller = AppearanceController();
    final systemController = AppearanceController(themeMode: ThemeMode.system);
    addTearDown(controller.dispose);
    addTearDown(systemController.dispose);

    expect(controller.themeMode, ThemeMode.light);
    expect(systemController.themeMode, ThemeMode.system);
  });

  test('Only a changed mode notifies subscribers', () {
    final controller = AppearanceController();
    addTearDown(controller.dispose);
    final observed = <ThemeMode>[];
    controller.addListener(() => observed.add(controller.themeMode));

    controller.setThemeMode(ThemeMode.dark);
    controller.setThemeMode(ThemeMode.light);
    controller.setThemeMode(ThemeMode.light);
    controller.setThemeMode(ThemeMode.system);

    expect(observed, [ThemeMode.dark, ThemeMode.light, ThemeMode.system]);
  });

  test('A new controller starts a fresh session', () {
    final first = AppearanceController()..setThemeMode(ThemeMode.dark);
    first.dispose();
    final fresh = AppearanceController();
    addTearDown(fresh.dispose);

    expect(fresh.themeMode, ThemeMode.light);
  });
}
