import '../domain/auth_repository.dart';
import '../domain/demo_session.dart';

class DemoAuthRepository implements AuthRepository {
  const DemoAuthRepository();

  @override
  Future<DemoSession> openDemo(String email) async {
    final error = validateDemoEmail(email);
    if (error != null) throw FormatException(error);
    return DemoSession(email: email);
  }
}
