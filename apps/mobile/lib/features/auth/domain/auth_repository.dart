import 'demo_session.dart';

abstract interface class AuthRepository {
  Future<DemoSession> openDemo(String email);
}
