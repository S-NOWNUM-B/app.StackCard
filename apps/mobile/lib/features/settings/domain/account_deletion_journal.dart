final class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.operationId,
    required this.expectedGeneration,
    this.recoveryKey,
  });
  final String operationId;
  final int expectedGeneration;
  final String? recoveryKey;
}

abstract interface class AccountDeletionJournal {
  Future<AccountDeletionRequest?> read();
  Future<void> write(AccountDeletionRequest request);
  Future<void> clear();
}
