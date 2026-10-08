import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/account_deletion_journal.dart';

/// UID входит в ключ. Неизвестный результат переживает закрытие приложения.
final class SharedPreferencesAccountDeletionJournal
    implements AccountDeletionJournal {
  SharedPreferencesAccountDeletionJournal(this.preferences, this.ownerUid)
    : key = 'stackcard.account-deletion.${Uri.encodeComponent(ownerUid)}.v1';
  final SharedPreferencesAsync preferences;
  final String key;
  final String ownerUid;
  static const pendingOwnerKey = 'stackcard.account-deletion.pending-owner.v1';
  static Future<String?> readPendingOwner(SharedPreferencesAsync preferences) =>
      preferences.getString(pendingOwnerKey);
  @override
  Future<AccountDeletionRequest?> read() async {
    final raw = await preferences.getString(key);
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        (value['version'] != 1 && value['version'] != 2) ||
        value['operationId'] is! String ||
        (value['operationId'] as String).isEmpty ||
        value['expectedGeneration'] is! int ||
        value['expectedGeneration'] < 0) {
      throw const FormatException('Invalid account deletion journal');
    }
    if (value['version'] == 2 &&
        (value['recoveryKey'] is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['recoveryKey']))) {
      throw const FormatException('Invalid deletion recovery receipt');
    }
    return AccountDeletionRequest(
      operationId: value['operationId'],
      expectedGeneration: value['expectedGeneration'],
      recoveryKey: value['recoveryKey'] as String?,
    );
  }

  @override
  Future<void> write(AccountDeletionRequest request) async {
    await preferences.setString(
      key,
      jsonEncode({
        'version': request.recoveryKey == null ? 1 : 2,
        'operationId': request.operationId,
        'expectedGeneration': request.expectedGeneration,
        if (request.recoveryKey != null) 'recoveryKey': request.recoveryKey,
      }),
    );
    await preferences.setString(pendingOwnerKey, ownerUid);
  }

  @override
  Future<void> clear() async {
    await preferences.remove(key);
    if (await preferences.getString(pendingOwnerKey) == ownerUid) {
      await preferences.remove(pendingOwnerKey);
    }
  }
}
