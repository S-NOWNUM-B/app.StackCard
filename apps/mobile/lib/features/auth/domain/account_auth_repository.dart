import 'auth_user.dart';

abstract interface class AccountAuthRepository {
  Stream<AuthUser?> watchSession();
  Future<void> signInEmail(String email, String password);
  Future<void> registerEmail(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signInGoogle();
  Future<void> signOut();
}
