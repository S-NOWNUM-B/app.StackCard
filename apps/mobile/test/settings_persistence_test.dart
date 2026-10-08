import 'dart:async';
import 'dart:convert';

import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/core/state/appearance_controller.dart';
import 'package:app_stackcard/core/state/settings_repository.dart';
import 'package:app_stackcard/features/settings/data/shared_preferences_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('A fresh repository restores the complete settings snapshot', () async {
    final storage = <String, String>{'unrelated.key': 'preserved'};
    const settings = AppSettings(
      theme: AppTheme.system,
      language: AppLanguage.en,
      showSourceDescriptions: false,
      reducedMotion: true,
    );
    await SharedPreferencesSettingsRepository(_Preferences(storage))
        .save(settings);
    final restored = await SharedPreferencesSettingsRepository(
      _Preferences(storage),
    ).load();
    expect(restored, settings);
    expect(storage['unrelated.key'], 'preserved');
    final record = jsonDecode(
      storage[SharedPreferencesSettingsRepository.storageKey]!,
    ) as Map<String, dynamic>;
    expect(
      record['version'],
      SharedPreferencesSettingsRepository.schemaVersion,
    );
    expect(record['theme'], 'system');
  });

  test('Absent, malformed and unsupported records use safe defaults', () async {
    for (final value in <String?>[
      null,
      '{broken',
      '[]',
      '{"version":3,"theme":"light"}',
      '{"version":1.0,"theme":"light"}',
      '{"version":1,"theme":false,"language":42,"showSourceDescriptions":"false"}',
    ]) {
      final storage = <String, String>{
        SharedPreferencesSettingsRepository.storageKey: ?value,
      };
      expect(
        await SharedPreferencesSettingsRepository(_Preferences(storage)).load(),
        const AppSettings(),
      );
    }
  });

  test(
    'Missing fields default independently without discarding valid language',
    () async {
      final storage = {
        SharedPreferencesSettingsRepository.storageKey:
            '{"version":1,"language":"en"}',
      };
      expect(
        await SharedPreferencesSettingsRepository(_Preferences(storage)).load(),
        const AppSettings(language: AppLanguage.en),
      );
    },
  );

  test(
    'Version 1 settings preserve choices and add reduced motion false',
    () async {
      final storage = {
        SharedPreferencesSettingsRepository.storageKey: '{"version":1,"theme":"light","language":"en","showSourceDescriptions":false}',
      };
      expect(
        await SharedPreferencesSettingsRepository(_Preferences(storage)).load(),
        const AppSettings(
          theme: AppTheme.light,
          language: AppLanguage.en,
          showSourceDescriptions: false,
        ),
      );
    },
  );

  test(
    'Reduced motion persists and a failed preference write retries',
    () async {
      final repository = _Settings()..failNext = true;
      final controller = AppearanceController(settingsRepository: repository);
      addTearDown(controller.dispose);
      await controller.setReducedMotion(true);
      expect(controller.reducedMotion, isTrue);
      expect(controller.saveFailure, isNotNull);
      expect(repository.stored.reducedMotion, isFalse);
      await controller.retrySave();
      expect(controller.saveFailure, isNull);
      expect(repository.stored.reducedMotion, isTrue);
    },
  );

  test('Platform failures become typed read and write failures', () async {
    final preferences = _Preferences({}, fail: true);
    final repository = SharedPreferencesSettingsRepository(preferences);
    await expectLater(
      repository.load(),
      throwsA(
        isA<SettingsFailure>().having(
          (error) => error.kind,
          'kind',
          SettingsFailureKind.read,
        ),
      ),
    );
    await expectLater(
      repository.save(const AppSettings()),
      throwsA(
        isA<SettingsFailure>().having(
          (error) => error.kind,
          'kind',
          SettingsFailureKind.write,
        ),
      ),
    );
  });

  test('Restored settings take precedence over the legacy initial theme', () {
    final controller = AppearanceController(
      themeMode: ThemeMode.dark,
      initialSettings: const AppSettings(
        theme: AppTheme.light,
        language: AppLanguage.en,
        showSourceDescriptions: false,
      ),
    );
    addTearDown(controller.dispose);
    expect(controller.themeMode, ThemeMode.light);
    expect(controller.locale, const Locale('en'));
    expect(controller.showSourceDescriptions, isFalse);
  });

  test(
    'Concurrent edits serialize and persist the latest complete snapshot',
    () async {
      final gate = Completer<void>();
      final repository = _Settings(gate: gate);
      final controller = AppearanceController(settingsRepository: repository);
      addTearDown(controller.dispose);
      final first = controller.setThemeMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      expect(repository.writes, [const AppSettings(theme: AppTheme.light)]);
      final second = controller.setLanguage(AppLanguage.en);
      final third = controller.setShowSourceDescriptions(false);
      expect(controller.isSaving, isTrue);
      expect(repository.writes, hasLength(1));
      gate.complete();
      await Future.wait([first, second, third]);
      expect(repository.writes, hasLength(2));
      expect(repository.maximumConcurrentWrites, 1);
      expect(repository.stored, controller.settings);
      expect(
        repository.stored,
        const AppSettings(
          theme: AppTheme.light,
          language: AppLanguage.en,
          showSourceDescriptions: false,
        ),
      );
      expect(controller.isSaving, isFalse);
      final restarted = AppearanceController(
        initialSettings: await repository.load(),
      );
      addTearDown(restarted.dispose);
      expect(restarted.settings, controller.settings);
    },
  );

  test(
    'A failed save keeps the selection and retry persists current settings',
    () async {
      final repository = _Settings()..failNext = true;
      final controller = AppearanceController(settingsRepository: repository);
      addTearDown(controller.dispose);
      await controller.setLanguage(AppLanguage.en);
      expect(controller.locale, const Locale('en'));
      expect(controller.saveFailure?.kind, SettingsFailureKind.write);
      expect(repository.stored.language, AppLanguage.ru);
      await controller.retrySave();
      expect(controller.saveFailure, isNull);
      expect(repository.stored.language, AppLanguage.en);
    },
  );

  test(
    'Disposal suppresses notifications while pending settings still persist',
    () async {
      final gate = Completer<void>();
      final repository = _Settings(gate: gate);
      final controller = AppearanceController(settingsRepository: repository);
      final saving = controller.setThemeMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      controller.setLanguage(AppLanguage.en);
      controller.dispose();
      gate.complete();
      await saving;
      expect(
        repository.stored,
        const AppSettings(theme: AppTheme.light, language: AppLanguage.en),
      );
    },
  );
}

class _Preferences implements SharedPreferencesAsync {
  _Preferences(this.storage, {this.fail = false});
  final Map<String, String> storage;
  final bool fail;

  @override
  Future<String?> getString(String key) async {
    if (fail) throw StateError('unavailable');
    return storage[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    if (fail) throw StateError('unavailable');
    storage[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings implements SettingsRepository {
  _Settings({this.gate});
  final Completer<void>? gate;
  AppSettings stored = const AppSettings();
  final writes = <AppSettings>[];
  bool failNext = false;
  int concurrentWrites = 0;
  int maximumConcurrentWrites = 0;

  @override
  Future<AppSettings> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    writes.add(settings);
    concurrentWrites++;
    if (concurrentWrites > maximumConcurrentWrites) {
      maximumConcurrentWrites = concurrentWrites;
    }
    try {
      await gate?.future;
      if (failNext) {
        failNext = false;
        throw const SettingsFailure(SettingsFailureKind.write);
      }
      stored = settings;
    } finally {
      concurrentWrites--;
    }
  }
}
