enum AuthFailureKind {
  invalidEmail,
  weakPassword,
  invalidCredentials,
  emailInUse,
  userDisabled,
  network,
  tooManyRequests,
  cancelled,
  configuration,
  unknown,
}

final class AuthFailure implements Exception {
  const AuthFailure(this.kind);

  final AuthFailureKind kind;

  @override
  String toString() => 'AuthFailure(${kind.name})';
}
