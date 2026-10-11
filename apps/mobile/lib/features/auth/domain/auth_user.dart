final class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.hasGoogle = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool hasGoogle;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.hasGoogle == hasGoogle;

  @override
  int get hashCode => Object.hash(uid, email, displayName, hasGoogle);
}
