import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

class AppearanceController extends ChangeNotifier {
  AppearanceController({
    ThemeMode themeMode = ThemeMode.dark,
    AppSettings? initialSettings,
    SettingsRepository? settingsRepository,
  }) : _settings = initialSettings ?? AppSettings(theme: _appTheme(themeMode)),
       _repository = settingsRepository;

  AppSettings _settings;
  final SettingsRepository? _repository;
  AppSettings? _pending;
  Future<void>? _writeFuture;
  SettingsFailure? _saveFailure;
  bool _isSaving = false;
  bool _disposed = false;

  AppSettings get settings => _settings;
  ThemeMode get themeMode => switch (_settings.theme) {
    AppTheme.dark => ThemeMode.dark,
    AppTheme.light => ThemeMode.light,
    AppTheme.system => ThemeMode.system,
  };
  Locale get locale => Locale(_settings.language.name);
  bool get showSourceDescriptions => _settings.showSourceDescriptions;
  bool get reducedMotion => _settings.reducedMotion;
  bool get isSaving => _isSaving;
  SettingsFailure? get saveFailure => _saveFailure;

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(_settings.copyWith(theme: _appTheme(mode)));

  Future<void> setLanguage(AppLanguage language) =>
      _update(_settings.copyWith(language: language));

  Future<void> setShowSourceDescriptions(bool value) =>
      _update(_settings.copyWith(showSourceDescriptions: value));

  Future<void> setReducedMotion(bool value) =>
      _update(_settings.copyWith(reducedMotion: value));

  Future<void> _update(AppSettings next) {
    if (_disposed || next == _settings) return Future.value();
    _settings = next;
    _saveFailure = null;
    notifyListeners();
    return _queueSave();
  }

  Future<void> retrySave() => _disposed ? Future.value() : _queueSave();

  Future<void> _queueSave() {
    if (_repository == null) return Future.value();
    _pending = _settings;
    _saveFailure = null;
    if (_writeFuture != null) return _writeFuture!;
    _isSaving = true;
    notifyListeners();
    return _writeFuture = _persistPending();
  }

  // Один snapshot за раз; быстрые изменения заменяют ожидающий snapshot.
  Future<void> _persistPending() async {
    await Future<void>.value();
    while (_pending != null) {
      final next = _pending!;
      _pending = null;
      try {
        await _repository!.save(next);
        _saveFailure = null;
      } catch (error) {
        _saveFailure = error is SettingsFailure
            ? error
            : const SettingsFailure(SettingsFailureKind.write);
      }
    }
    _writeFuture = null;
    _isSaving = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

AppTheme _appTheme(ThemeMode mode) => switch (mode) {
  ThemeMode.dark => AppTheme.dark,
  ThemeMode.light => AppTheme.light,
  ThemeMode.system => AppTheme.system,
};
