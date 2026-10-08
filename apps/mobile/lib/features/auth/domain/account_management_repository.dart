/// Управление текущим аккаунтом отдельно от API входа; SDK остаётся в data.
abstract interface class AccountManagementRepository {
  Future<AccountSecurity> readSecurity(String expectedUid);
  Future<void> sendVerification(String expectedUid);
  Future<void> reauthenticatePassword(String expectedUid, String password);
  Future<void> reauthenticateGoogle(String expectedUid);
  Future<void> requestEmailChange(String expectedUid, String email);
  Future<void> changePassword(String expectedUid, String password);
  Future<void> linkPassword(String expectedUid, String email, String password);
  Future<void> linkGoogle(String expectedUid);
  Future<void> unlinkProvider(String expectedUid, String providerId);
}

final class AccountSecurity {
  AccountSecurity({
    required this.uid,
    this.email,
    required this.emailVerified,
    required Set<String> providers,
  }) : providers = Set.unmodifiable(providers);
  final String uid;
  final String? email;
  final bool emailVerified;
  final Set<String> providers;
  bool get hasPassword => providers.contains('password');
  bool get hasGoogle => providers.contains('google.com');
  bool canUnlink(String provider) =>
      providers.contains(provider) &&
      providers.any(
        (item) =>
            item != provider && (item == 'password' || item == 'google.com'),
      );
}

enum AccountManagementFailureKind {
  ownerChanged,
  reauthenticationRequired,
  lastProvider,
  providerInUse,
  invalidEmail,
  weakPassword,
  invalidCredentials,
  emailInUse,
  network,
  tooManyRequests,
  cancelled,
  configuration,
  unknown,
}

final class AccountManagementFailure implements Exception {
  const AccountManagementFailure(this.kind);
  final AccountManagementFailureKind kind;
  @override
  String toString() => 'AccountManagementFailure(${kind.name})';
}
