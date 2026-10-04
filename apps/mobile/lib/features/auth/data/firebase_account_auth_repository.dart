import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/account_auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_user.dart';

class FirebaseAccountAuthRepository implements AccountAuthRepository {
  FirebaseAccountAuthRepository({
    required this._auth,
    this._googleClientId,
    this._googleServerClientId,
    this._googleCredential,
    this._googleSignOut,
  });

  final FirebaseAuth _auth;
  final String? _googleClientId;
  final String? _googleServerClientId;
  final Future<AuthCredential> Function()? _googleCredential;
  final Future<void> Function()? _googleSignOut;

  static Future<void>? _googleInitialization;

  @override
  Stream<AuthUser?> watchSession() {
    try {
      return _auth
          .authStateChanges()
          .map<AuthUser?>((user) {
            return user == null
                ? null
                : AuthUser(
                    uid: user.uid,
                    email: user.email,
                    displayName: user.displayName,
                  );
          })
          .handleError((Object error) {
            throw _failure(error);
          });
    } catch (error) {
      return Stream<AuthUser?>.error(_failure(error), StackTrace.empty);
    }
  }

  @override
  Future<void> signInEmail(String email, String password) => _guard(() async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });

  @override
  Future<void> registerEmail(String email, String password) => _guard(() async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });

  @override
  Future<void> sendPasswordReset(String email) => _guard(() async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Ответ не должен раскрывать наличие аккаунта для этого адреса.
      if (error.code != 'user-not-found') rethrow;
    }
  });

  @override
  Future<void> signInGoogle() => _guard(() async {
    final credential =
        await (_googleCredential?.call() ?? _getGoogleCredential());
    await _auth.signInWithCredential(credential);
  });

  @override
  Future<void> signOut() => _guard(() async {
    // Firebase определяет сессию; сбой очистки Google не должен мешать выходу.
    await _auth.signOut();
    try {
      if (_googleSignOut != null) {
        await _googleSignOut();
      } else if (_googleInitialization != null) {
        await _googleInitialization;
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {
      // Firebase уже вышел; следующая попытка Google потребует authenticate.
    }
  });

  Future<AuthCredential> _getGoogleCredential() async {
    await _ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthFailure(AuthFailureKind.configuration);
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<void> _ensureGoogleInitialized() async {
    final initialization = _googleInitialization ??= GoogleSignIn.instance
        .initialize(
          clientId: _googleClientId,
          serverClientId: _googleServerClientId,
        );
    try {
      await initialization;
    } catch (_) {
      if (identical(initialization, _googleInitialization)) {
        _googleInitialization = null;
      }
      rethrow;
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      throw _failure(error);
    }
  }

  AuthFailure _failure(Object error) {
    if (error is AuthFailure) return error;
    if (error is GoogleSignInException) {
      return AuthFailure(switch (error.code) {
        GoogleSignInExceptionCode.canceled => AuthFailureKind.cancelled,
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          AuthFailureKind.configuration,
        _ => AuthFailureKind.unknown,
      });
    }
    if (error is FirebaseAuthException) {
      return AuthFailure(switch (error.code) {
        'invalid-email' => AuthFailureKind.invalidEmail,
        'weak-password' => AuthFailureKind.weakPassword,
        'invalid-credential' ||
        'invalid-login-credentials' ||
        'wrong-password' ||
        'user-not-found' ||
        'account-exists-with-different-credential' =>
          AuthFailureKind.invalidCredentials,
        'email-already-in-use' => AuthFailureKind.emailInUse,
        'user-disabled' => AuthFailureKind.userDisabled,
        'network-request-failed' => AuthFailureKind.network,
        'too-many-requests' => AuthFailureKind.tooManyRequests,
        'operation-not-allowed' ||
        'app-not-authorized' ||
        'invalid-api-key' ||
        'configuration-not-found' => AuthFailureKind.configuration,
        _ => AuthFailureKind.unknown,
      });
    }
    return const AuthFailure(AuthFailureKind.unknown);
  }
}
