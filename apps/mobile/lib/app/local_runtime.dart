import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/state/app_settings.dart';
import '../core/state/settings_repository.dart';
import '../core/storage/local_storage.dart';
import '../features/github_import/data/hive_github_response_cache.dart';
import '../features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import '../features/settings/data/shared_preferences_settings_repository.dart';

/// Composition root открывает disk-адаптеры до первого экрана приложения.
final class LocalRuntime {
  LocalRuntime({
    required this.settings,
    required this.settingsRepository,
    required this.storage,
  });

  final AppSettings settings;
  final SettingsRepository settingsRepository;
  final LocalStorage storage;

  late final githubCache = HiveGitHubResponseCache(storage.githubResponses);
  late final draftRepository = HivePortfolioDraftRepository(
    storage.portfolioDraft,
  );

  static Future<LocalRuntime> load({
    Directory? directory,
    SettingsRepository? settingsRepository,
  }) async {
    final repository =
        settingsRepository ??
        SharedPreferencesSettingsRepository(SharedPreferencesAsync());
    final settings = await repository.load();
    final storage = await LocalStorage.open(directory: directory);
    return LocalRuntime(
      settings: settings,
      settingsRepository: repository,
      storage: storage,
    );
  }
}
