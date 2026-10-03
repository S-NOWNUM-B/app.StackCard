import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/auth/data/demo_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Demo email validation keeps the existing form rule', () {
    for (final email in [
      null,
      '',
      'invalid',
      'alex@example',
      'a b@example.dev',
    ]) {
      expect(validateDemoEmail(email), 'Укажите корректный email');
    }
    for (final email in [
      'alex@example.dev',
      '  Alex@Example.Dev  ',
      'alex+demo@example.dev',
    ]) {
      expect(validateDemoEmail(email), isNull);
    }
  });

  test(
    'Demo repository returns a normalized session for a valid email',
    () async {
      const repository = DemoAuthRepository();
      final session = await repository.openDemo('  Alex@Example.Dev  ');
      expect(session.email, 'alex@example.dev');
    },
  );

  test(
    'Demo repository rejects invalid input through the same domain rule',
    () {
      const repository = DemoAuthRepository();
      expect(
        repository.openDemo('invalid'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            validateDemoEmail('invalid'),
          ),
        ),
      );
    },
  );
}
