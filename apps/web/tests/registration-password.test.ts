import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { PasswordField } from '../src/components/auth-form';
import { registrationPasswordIssues } from '../src/lib/registration-password';

test('registration permits a long passphrase without invented character-category requirements', () => {
  assert.ok(registrationPasswordIssues('Северок').has('tooShort'));
  assert.equal(registrationPasswordIssues('Северная').size, 0);
  assert.equal(registrationPasswordIssues('Северный ветер над морем').size, 0);
  assert.equal(registrationPasswordIssues('a gentle amber evening').size, 0);
});
test('obvious passwords and partial repeating patterns are rejected even when long enough', () => {
  for (const value of [
    'aaaaaaaaaaaaaaaa',
    'ababababababababa',
    'abcdabcdabcdabcdab',
    'qwertyqwertyqwerty',
    'passwordpassword',
    '1234567890123456789',
    'парольпарольпароль',
  ])
    assert.ok(registrationPasswordIssues(value).has('tooCommon'));
});
test('length uses Unicode code points and spaces are preserved as password characters', () => {
  assert.ok(registrationPasswordIssues('😀'.repeat(7)).has('tooShort'));
  assert.ok(!registrationPasswordIssues('😀'.repeat(8)).has('tooShort'));
  assert.ok(!registrationPasswordIssues('😀'.repeat(128)).has('tooLong'));
  assert.ok(registrationPasswordIssues('😀'.repeat(129)).has('tooLong'));
  assert.ok(!registrationPasswordIssues('  северный ветер ').has('tooShort'));
});
test('registration rejects email and local-part equality without rejecting unrelated email substrings', () => {
  assert.ok(
    registrationPasswordIssues('OWNER@example.com', ' owner@example.com ').has('matchesEmail'),
  );
  assert.ok(registrationPasswordIssues('owner', 'owner@example.com').has('matchesEmail'));
  assert.ok(
    !registrationPasswordIssues('owner describes a project', 'owner@example.com').has(
      'matchesEmail',
    ),
  );
});
test('both password controls start obscured and expose separate accessible visibility actions', () => {
  for (const label of ['Пароль', 'Подтверждение пароля']) {
    const html = renderToStaticMarkup(
      createElement(PasswordField, {
        label,
        value: '',
        onChange: () => {},
        autoComplete: 'new-password',
      }),
    );
    assert.ok(html.includes('type="password"'));
    assert.ok(
      html.includes(label === 'Пароль' ? 'Показать пароль' : 'Показать подтверждение пароля'),
    );
    assert.ok(html.includes('aria-pressed="false"'));
    assert.ok(html.includes('type="button"'));
  }
});
