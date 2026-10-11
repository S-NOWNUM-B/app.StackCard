import 'dart:convert';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Registration password length', () {
    test('Requires at least 8 code points', () {
      expect(RegistrationPasswordPolicy.evaluate('cloudca'), {
        RegistrationPasswordIssue.tooShort,
      });
      expect(RegistrationPasswordPolicy.evaluate('cloudcat'), isEmpty);
    });

    test('Counts supplementary Unicode by code point rather than UTF-16', () {
      final tooShort = _unicodePassword(7);
      final minimum = _unicodePassword(8);

      expect(tooShort.length, 14);
      expect(RegistrationPasswordPolicy.evaluate(tooShort), {
        RegistrationPasswordIssue.tooShort,
      });
      expect(RegistrationPasswordPolicy.evaluate(minimum), isEmpty);
    });

    test('Accepts 128 code points and rejects 129 without truncation', () {
      final maximum = _unicodePassword(128);
      final tooLong = _unicodePassword(129);

      expect(RegistrationPasswordPolicy.evaluate(maximum), isEmpty);
      expect(RegistrationPasswordPolicy.evaluate(tooLong), {
        RegistrationPasswordIssue.tooLong,
      });
      expect(tooLong.runes.length, 129);
    });

    test('Empty input reports the minimum length', () {
      expect(RegistrationPasswordPolicy.evaluate(''), {
        RegistrationPasswordIssue.tooShort,
      });
    });
  });

  group('Registration password content', () {
    test(
      'Accepts long lowercase and Unicode phrases without composition rules',
      () {
        for (final password in [
          'four clouds over the mountain',
          'Тихий вечер над горными озёрами',
          '月の光と静かな夜の長い散歩道の先',
          '😀 walking past green pines 😀',
        ]) {
          expect(
            RegistrationPasswordPolicy.evaluate(password),
            isEmpty,
            reason: password,
          );
        }
      },
    );

    test(
      'Counts and preserves leading, trailing, repeated and Unicode spaces',
      () {
        const password = '  cedar\u00a0moon  river  ';
        final originalBytes = utf8.encode(password);

        expect(RegistrationPasswordPolicy.evaluate(password), isEmpty);
        expect(utf8.encode(password), originalBytes);
        expect(password, '  cedar\u00a0moon  river  ');
        expect(RegistrationPasswordPolicy.evaluate('  clear river  '), isEmpty);
      },
    );

    test('Rejects local obvious common passwords and complete sequences', () {
      for (final password in [
        '123456789012345',
        '1234567890123456',
        '0123456789012345',
        '9876543210987654',
        'passwordpassword',
        '  PASSWORDPASSWORD  ',
        'qwertyqwertyqwerty',
        'letmeinletmeinletmein',
        'abcdefghijklmnopqrstuvwxyz',
        'zyxwvutsrqponmlkjihgfedcba',
        'парольпарольпароль',
      ]) {
        expect(RegistrationPasswordPolicy.evaluate(password), {
          RegistrationPasswordIssue.tooCommon,
        }, reason: password);
      }
    });

    test('Rejects a single repeated code point and whitespace-only input', () {
      for (final password in [
        'aaaaaaaaaaaaaaa',
        '111111111111111',
        '😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀',
        '               ',
      ]) {
        expect(RegistrationPasswordPolicy.evaluate(password), {
          RegistrationPasswordIssue.tooCommon,
        }, reason: password);
      }
    });

    test(
      'Rejects complete short Unicode patterns and incomplete final repeats',
      () {
        for (final password in [
          'abababababababab',
          'abcabcabcabcabc',
          'abcdabcdabcdabcd',
          'abcabcabcabcabca',
          'abcdabcdabcdabc',
          'ha ha ha ha ha ha',
          'ЖяЖяЖяЖяЖяЖяЖяЖя',
          '😀🚀😀🚀😀🚀😀🚀😀🚀😀🚀😀🚀😀',
          '😀🚀🌙⭐😀🚀🌙⭐😀🚀🌙⭐😀🚀🌙',
        ]) {
          expect(RegistrationPasswordPolicy.evaluate(password), {
            RegistrationPasswordIssue.tooCommon,
          }, reason: password);
        }
      },
    );

    test('Allows ordinary phrases containing short repetitions', () {
      for (final password in [
        'ha ha ha along the cedar path',
        'abcdabcdabcdabc under winter rain',
        '😀🚀😀🚀 walk beside a quiet lake',
      ]) {
        expect(
          RegistrationPasswordPolicy.evaluate(password),
          isEmpty,
          reason: password,
        );
      }
    });

    test('Common words within a long phrase are allowed', () {
      expect(
        RegistrationPasswordPolicy.evaluate('my password for the violet moon'),
        isEmpty,
      );
      expect(
        RegistrationPasswordPolicy.evaluate('qwerty under distant stars'),
        isEmpty,
      );
    });

    test('Rejects exact email and local-part matches ignoring letter case', () {
      const email = 'Moonlight.River@Example.Dev';

      expect(
        RegistrationPasswordPolicy.evaluate(
          'moonlight.river@example.dev',
          email: email,
        ),
        {RegistrationPasswordIssue.matchesEmail},
      );
      expect(
        RegistrationPasswordPolicy.evaluate('MOONLIGHT.RIVER', email: email),
        {RegistrationPasswordIssue.matchesEmail},
      );
      expect(
        RegistrationPasswordPolicy.evaluate(
          '  moonlight.river  ',
          email: '  $email  ',
        ),
        {RegistrationPasswordIssue.matchesEmail},
      );
    });

    test(
      'Does not reject a long phrase just for containing the local part',
      () {
        expect(
          RegistrationPasswordPolicy.evaluate(
            'Moonlight.River walks across a cedar bridge',
            email: 'Moonlight.River@example.dev',
          ),
          isEmpty,
        );
      },
    );

    test('Reports all applicable issues in an immutable set', () {
      final issues = RegistrationPasswordPolicy.evaluate(
        'aaaa',
        email: 'aaaa@example.dev',
      );

      expect(issues, {
        RegistrationPasswordIssue.tooShort,
        RegistrationPasswordIssue.tooCommon,
        RegistrationPasswordIssue.matchesEmail,
      });
      expect(
        () => issues.add(RegistrationPasswordIssue.tooLong),
        throwsUnsupportedError,
      );
    });
  });
}

String _unicodePassword(int length) => List.generate(
  length,
  (index) => String.fromCharCode(0x1f600 + index % 32),
).join();
