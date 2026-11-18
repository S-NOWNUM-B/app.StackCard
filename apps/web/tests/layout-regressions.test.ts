import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { PageHeader } from '../src/components/ui';
import { SiteFooter } from '../src/components/marketing';

const css = readFileSync(new URL('../src/app/globals.css', import.meta.url), 'utf8');

// Тело правила по точному селектору (первое вхождение в начале строки)
function ruleBody(selector: string, from = 0) {
  const start = css.indexOf(`\n${selector} {`, from);
  assert.ok(start >= 0, `нет правила ${selector}`);
  return css.slice(start, css.indexOf('}', start));
}

test('ссылки футера столбцами: блочный flex, не inline, и цель касания 44px', () => {
  const body = ruleBody('.footer-top > div > a');
  assert.match(body, /display: flex;/);
  assert.match(body, /min-height: 44px/);
  // Регрессия: общий блок целей касания не должен переопределять display ссылок футера
  const touchBlock = css.slice(css.indexOf('/* Цели касания не меньше 44px'));
  const footerInBlock = touchBlock
    .split('}')
    .filter((rule) => /\.site-footer|\.footer-top/.test(rule.split('{')[0]));
  assert.deepEqual(footerInBlock, [], 'футер правится только в собственных правилах');
});

test('в разметке футера ссылки лежат в колонках внутри div, а не в общей строке', () => {
  const markup = renderToStaticMarkup(createElement(SiteFooter));
  const columns = markup.match(/<div><h2>[^<]+<\/h2>(?:<a [^>]+>[^<]*<\/a>)+<\/div>/g) ?? [];
  assert.equal(columns.length, 3);
});

test('на узком экране кнопки «Вверх/Вниз» накладываются и не занимают место строки', () => {
  const marker = css.indexOf('@media (max-width: 640px) {\n    .sortable-steps {');
  assert.ok(marker >= 0, 'нет оверлея кнопок перемещения на узком экране');
  assert.match(css.slice(marker, marker + 400), /position: absolute/);
});

test('PageHeader: один h1, стрелка назад с подписью, высота строки заголовка постоянна', () => {
  const markup = renderToStaticMarkup(
    createElement(PageHeader, {
      title: 'Здоровье портфолио',
      subtitle: 'Подпись',
      back: { label: 'Назад на Главную', onClick: () => {} },
    }),
  );
  assert.equal((markup.match(/<h1/g) ?? []).length, 1);
  assert.match(markup, /aria-label="Назад на Главную"/);
  assert.match(ruleBody('.page-header-row'), /min-height: 48px/);
  assert.match(ruleBody('.page-header h1'), /min-height: 48px/);
  const plain = renderToStaticMarkup(createElement(PageHeader, { title: 'Настройки' }));
  assert.doesNotMatch(plain, /page-back/);
});

test('текст значения в строках редактора не сжимается: min-width: 0 по всей цепочке', () => {
  for (const selector of ['.sortable-content', '.record-editor-summary', '.record-editor-copy'])
    assert.match(ruleBody(selector), /min-width: 0/, selector);
  assert.match(ruleBody('.record-editor-copy'), /overflow-wrap: anywhere/);
});

test('заголовки страниц и секций не сжимаются до разрыва слова: перенос кнопок вместо anywhere', () => {
  for (const selector of ['.page-header h1', '.editor-card-header h2']) {
    const body = ruleBody(selector);
    assert.match(body, /overflow-wrap: normal/, selector);
    assert.match(body, /min-width: min-content/, selector);
  }
  assert.match(ruleBody('.page-header-row'), /flex-wrap: wrap/);
  assert.match(ruleBody('.editor-card-header'), /flex-wrap: wrap/);
});
