import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/state/app_settings.dart';
import '../../../core/state/settings_repository.dart';

final class SharedPreferencesSettingsRepository implements SettingsRepository {
  SharedPreferencesSettingsRepository(SharedPreferencesAsync preferences)
    : _preferences = preferences;

  static const storageKey = 'stackcard.settings.v1';
  static const schemaVersion = 1;
  final SharedPreferencesAsync _preferences;

  @override
  Future<AppSettings> load() async {
    final String? stored;
    try {
      stored = await _preferences.getString(storageKey);
    } catch (_) {
      throw const SettingsFailure(SettingsFailureKind.read);
    }
    if (stored == null) return const AppSettings();
    try {
      final value = jsonDecode(stored);
      if (value is! Map<String, dynamic> ||
          value['version'] is! int ||
          value['version'] != schemaVersion) {
        return const AppSettings();
      }
      return AppSettings(
        theme: switch (value['theme']) {
          'light' => AppTheme.light,
          'system' => AppTheme.system,
          _ => AppTheme.dark,
        },
        language: value['language'] == 'en' ? AppLanguage.en : AppLanguage.ru,
        showSourceDescriptions: value['showSourceDescriptions'] is bool
            ? value['showSourceDescriptions'] as bool
            : true,
      );
    } on FormatException {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      await _preferences.setString(
        storageKey,
        jsonEncode({
          'version': schemaVersion,
          'theme': settings.theme.name,
          'language': settings.language.name,
          'showSourceDescriptions': settings.showSourceDescriptions,
        }),
      );
    } catch (_) {
      throw const SettingsFailure(SettingsFailureKind.write);
    }
  }
}
