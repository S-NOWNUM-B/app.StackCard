import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/account_deletion_journal.dart';
export 'domain/account_deletion_journal.dart';
export 'data/shared_preferences_account_deletion_journal.dart';

final accountDeletionJournalFactoryProvider =
    Provider<AccountDeletionJournal Function(String uid)>((ref) {
      final journals = <String, AccountDeletionJournal>{};
      return (uid) => journals.putIfAbsent(uid, _MemoryDeletionJournal.new);
    });

class _MemoryDeletionJournal implements AccountDeletionJournal {
  AccountDeletionRequest? _request;
  @override
  Future<AccountDeletionRequest?> read() async => _request;
  @override
  Future<void> write(AccountDeletionRequest request) async =>
      _request = request;
  @override
  Future<void> clear() async => _request = null;
}

/// Вызывается только после подтверждённого сервером completed для того же UID.
final accountConfirmedDeletionCleanupProvider =
    Provider<Future<void> Function(String uid)?>((ref) => null);

/// Bootstrap восстанавливает только UID pending receipt; ключ остаётся в журнале.
final accountDeletionInitialOwnerProvider = Provider<String?>((ref) => null);
final accountPendingDeletionOwnerProvider =
    NotifierProvider<AccountPendingDeletionOwner, String?>(
      AccountPendingDeletionOwner.new,
    );

class AccountPendingDeletionOwner extends Notifier<String?> {
  @override
  String? build() => ref.read(accountDeletionInitialOwnerProvider);
  void mark(String uid) => state = uid;
  void clear(String uid) {
    if (state == uid) state = null;
  }
}
