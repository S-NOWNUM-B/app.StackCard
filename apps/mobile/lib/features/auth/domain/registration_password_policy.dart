enum RegistrationPasswordIssue { tooShort, tooLong, tooCommon, matchesEmail }

abstract final class RegistrationPasswordPolicy {
  static const minimumLength = 8;
  static const maximumLength = 128;

  // Небольшой локальный список очевидных вариантов, без проверки утечек.
  static const _commonPasswords = {
    'password',
    'password1',
    'password123',
    'qwerty123',
    'iloveyou',
    'welcome',
    'changeme',
    'пароль',
    'парольпарольпароль',
  };

  static const _commonPatterns = {
    'password',
    'qwerty',
    'letmein',
    'admin',
    '1234567890',
    '0123456789',
    '9876543210',
    '0987654321',
    'abcdefghijklmnopqrstuvwxyz',
    'zyxwvutsrqponmlkjihgfedcba',
    'qwertyuiop',
    'asdfghjkl',
    'zxcvbnm',
  };

  /// Проверяет только регистрацию, не изменяя введённый пароль.
  static Set<RegistrationPasswordIssue> evaluate(
    String password, {
    String email = '',
  }) {
    final issues = <RegistrationPasswordIssue>{};
    final length = password.runes.length;
    if (length < minimumLength) {
      issues.add(RegistrationPasswordIssue.tooShort);
    }
    if (length > maximumLength) {
      issues.add(RegistrationPasswordIssue.tooLong);
    }

    // Пробелы учитываются в длине и сохраняются; сравнение не меняет SDK input.
    final comparison = password.trim().toLowerCase();
    if (password.isNotEmpty && _isCommon(comparison)) {
      issues.add(RegistrationPasswordIssue.tooCommon);
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (comparison.isNotEmpty && normalizedEmail.isNotEmpty) {
      final localPart = normalizedEmail.split('@').first;
      if (comparison == normalizedEmail || comparison == localPart) {
        issues.add(RegistrationPasswordIssue.matchesEmail);
      }
    }
    return Set.unmodifiable(issues);
  }

  static bool _isCommon(String password) {
    if (password.isEmpty || _commonPasswords.contains(password)) return true;
    final codePoints = password.runes.toList(growable: false);
    if (codePoints.every((codePoint) => codePoint == codePoints.first)) {
      return true;
    }
    // Проверяем повтор по всему паролю, включая неполный последний цикл.
    for (
      var patternLength = 2;
      patternLength <= 4 && patternLength * 2 <= codePoints.length;
      patternLength++
    ) {
      var repeats = true;
      for (var index = patternLength; index < codePoints.length; index++) {
        if (codePoints[index] != codePoints[index % patternLength]) {
          repeats = false;
          break;
        }
      }
      if (repeats) return true;
    }
    return password.length >= 6 &&
        _commonPatterns.any((pattern) {
          for (var index = 0; index < password.length; index++) {
            if (password.codeUnitAt(index) !=
                pattern.codeUnitAt(index % pattern.length)) {
              return false;
            }
          }
          return true;
        });
  }
}
