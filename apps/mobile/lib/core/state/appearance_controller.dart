import 'package:flutter/material.dart';

class AppearanceController extends ChangeNotifier {
  AppearanceController({this._themeMode = ThemeMode.dark});

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }
}
