export type RegistrationPasswordIssue = 'tooShort' | 'tooLong' | 'tooCommon' | 'matchesEmail';
export const registrationPasswordMinimumLength = 8;
export const registrationPasswordMaximumLength = 128;
const commonPasswords = new Set([
  'password',
  'password1',
  'password123',
  'qwerty123',
  'iloveyou',
  'welcome',
  'changeme',
  'пароль',
  'парольпарольпароль',
]);
const commonPatterns = [
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
];
function isCommon(value: string): boolean {
  if (!value || commonPasswords.has(value)) return true;
  const points = Array.from(value);
  if (points.every((point) => point === points[0])) return true;
  for (let length = 2; length <= 4 && length * 2 <= points.length; length++)
    if (points.every((point, index) => point === points[index % length])) return true;
  return (
    value.length >= 6 &&
    commonPatterns.some((pattern) =>
      Array.from(value).every((point, index) => point === pattern[index % pattern.length]),
    )
  );
}
// Согласовано с mobile RegistrationPasswordPolicy. Пароль для SDK не изменяется.
export function registrationPasswordIssues(
  password: string,
  email = '',
): Set<RegistrationPasswordIssue> {
  const issues = new Set<RegistrationPasswordIssue>(),
    length = Array.from(password).length,
    comparison = password.trim().toLowerCase(),
    normalizedEmail = email.trim().toLowerCase();
  if (length < registrationPasswordMinimumLength) issues.add('tooShort');
  if (length > registrationPasswordMaximumLength) issues.add('tooLong');
  if (password && isCommon(comparison)) issues.add('tooCommon');
  if (
    comparison &&
    normalizedEmail &&
    [normalizedEmail, normalizedEmail.split('@')[0]].includes(comparison)
  )
    issues.add('matchesEmail');
  return issues;
}
