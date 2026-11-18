import { test } from 'node:test';
import assert from 'node:assert/strict';
import { contactDisplay } from '../src/components/document-view';

test('почта и телефон показываются без служебной схемы', () => {
  assert.equal(contactDisplay('Почта', 'mailto:name@example.com').text, 'name@example.com');
  assert.equal(contactDisplay('Телефон', 'tel:+70000000000').text, '+70000000000');
  assert.equal(contactDisplay('Сайт', 'https://example.com/me').text, 'https://example.com/me');
});

test('подпись, повторяющая значение, не выводится вторым разом', () => {
  assert.equal(contactDisplay('name@example.com', 'mailto:name@example.com').showLabel, false);
  assert.equal(contactDisplay('  NAME@example.com ', 'mailto:name@example.com').showLabel, false);
  assert.equal(contactDisplay('https://t.me/name', 'https://t.me/name').showLabel, false);
  assert.equal(contactDisplay('Почта', 'mailto:name@example.com').showLabel, true);
  assert.equal(contactDisplay('', 'https://example.com').showLabel, false);
});
