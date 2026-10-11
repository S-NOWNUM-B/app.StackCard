import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { ConfirmationDialog } from '../src/components/confirmation-dialog';
import { TagEditor } from '../src/components/tag-editor';

test('confirmation uses a labelled modal with cancellation before the primary confirmation', () => {
  let calls = 0;
  const html = renderToStaticMarkup(
    createElement(ConfirmationDialog, {
      request: { title: 'Удалить проект?', message: 'Репозиторий GitHub сохранится.' },
      onDecision: () => calls++,
    }),
  );
  assert.ok(html.includes('aria-labelledby='));
  assert.ok(html.includes('aria-describedby='));
  assert.ok(html.includes('Удалить проект?'));
  assert.ok(html.includes('Репозиторий GitHub сохранится.'));
  assert.ok(html.indexOf('Отмена') < html.indexOf('Подтвердить'));
  assert.match(html, /class="button secondary [^"]*"[^>]*>Отмена<\/button>/);
  assert.match(html, /class="button primary [^"]*"[^>]*>Подтвердить<\/button>/);
  assert.ok(html.includes('class="dialog-actions"'));
  assert.equal(calls, 0);
  assert.ok(!html.includes(' open='));
});

test('editing retains Save semantics with the same cancellation and action order', () => {
  const html = renderToStaticMarkup(
    createElement(TagEditor, {
      heading: 'Навыки',
      title: 'Добавить навык',
      addLabel: 'Добавить навык',
      removeLabel: 'Удалить навык',
      listLabel: 'Навыки',
      items: [],
      onAdd: () => {},
      onRemove: () => {},
    }),
  );
  assert.ok(html.includes('class="dialog-actions"'));
  assert.ok(html.indexOf('Отмена') < html.indexOf('Сохранить'));
  assert.ok(!html.includes('Подтвердить'));
  assert.ok(!html.includes('Готово'));
});
