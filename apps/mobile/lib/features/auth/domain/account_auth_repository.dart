import 'auth_user.dart';

abstract interface class AccountAuthRepository {
  Stream<AuthUser?> watchSession();
  Future<void> signInEmail(String email, String password);
  Future<void> registerEmail(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signInGoogle();
  Future<void> signOut();
}

/// Явный результат SDK; пустой профиль не означает новый аккаунт.
final class AccountAuthResult {
  const AccountAuthResult({required this.uid, required this.isNewUser});

  final String uid;
  final bool isNewUser;
}

/// Дополнительная capability сохраняет совместимость preview repositories.
abstract interface class AccountAuthCreationRepository {
  Future<AccountAuthResult> registerEmailWithResult(
    String email,
    String password,
  );
  Future<AccountAuthResult> signInGoogleWithResult();
}
