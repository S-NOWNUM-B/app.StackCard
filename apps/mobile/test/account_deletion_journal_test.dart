import 'package:app_stackcard/features/settings/settings_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences implements SharedPreferencesAsync {
  _Preferences(this.storage);
  final Map<String, String> storage;
  @override
  Future<String?> getString(String key) async => storage[key];
  @override
  Future<void> setString(String key, String value) async =>
      storage[key] = value;
  @override
  Future<void> remove(String key) async => storage.remove(key);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'deletion journal retains the same operation after reopen and isolates UID',
    () async {
      final storage = <String, String>{};
      final preferences = _Preferences(storage);
      await SharedPreferencesAccountDeletionJournal(preferences, 'owner').write(
        const AccountDeletionRequest(
          operationId: 'stable-op',
          expectedGeneration: 4,
        ),
      );
      final reopened = SharedPreferencesAccountDeletionJournal(
        preferences,
        'owner',
      );
      expect((await reopened.read())!.operationId, 'stable-op');
      expect((await reopened.read())!.expectedGeneration, 4);
      expect(
        await SharedPreferencesAccountDeletionJournal(
          preferences,
          'other',
        ).read(),
        isNull,
      );
      await reopened.clear();
      expect(await reopened.read(), isNull);
    },
  );
  test(
    'recovery receipt and pending UID survive restart without Firebase tokens',
    () async {
      final storage = <String, String>{};
      final preferences = _Preferences(storage);
      final recoveryKey = List.filled(64, 'a').join();
      await SharedPreferencesAccountDeletionJournal(
        preferences,
        'deleted-owner',
      ).write(
        AccountDeletionRequest(
          operationId: 'stable-op',
          expectedGeneration: 4,
          recoveryKey: recoveryKey,
        ),
      );
      expect(
        await SharedPreferencesAccountDeletionJournal.readPendingOwner(
          preferences,
        ),
        'deleted-owner',
      );
      final reopened = SharedPreferencesAccountDeletionJournal(
        preferences,
        'deleted-owner',
      );
      expect((await reopened.read())!.recoveryKey, recoveryKey);
      expect(storage.values.any((value) => value.contains('token')), isFalse);
      await reopened.clear();
      expect(
        await SharedPreferencesAccountDeletionJournal.readPendingOwner(
          preferences,
        ),
        isNull,
      );
    },
  );

  test('corrupt deletion journal is preserved and does not authorize a new operation', () async {
    final storage = <String, String>{};
    final journal = SharedPreferencesAccountDeletionJournal(
      _Preferences(storage),
      'owner',
    );
    storage[journal.key] =
        '{"version":1,"operationId":"","expectedGeneration":-1}';
    await expectLater(journal.read(), throwsFormatException);
    expect(storage[journal.key], isNotNull);
  });
}
