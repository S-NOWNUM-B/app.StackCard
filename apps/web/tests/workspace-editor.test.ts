import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import {
  attachment,
  emptyContent,
  mainDocument,
  migrateMainPortfolio,
  type Contact,
} from '../src/lib/model';
import { ContentEditor, normalizeContactUrl, saveContact } from '../src/components/content-editor';
import { moveItem } from '../src/components/sortable-list';
import {
  emptyProject,
  reorderAttachment,
  selectAttachments,
} from '../src/components/project-editor';
import { findTechnology, technologySuggestions } from '../src/lib/technology-catalog';
import { technologyIconPaths } from '../src/lib/technology-icon-paths';
import { encodeQr } from '../src/lib/qr-code';
import { cardTechnologies } from '../src/components/developer-card';
import { TagEditor } from '../src/components/tag-editor';

test('moveItem reorders a copy and ignores out-of-range moves', () => {
  const items = ['a', 'b', 'c', 'd'];
  assert.deepEqual(moveItem(items, 0, 2), ['b', 'c', 'a', 'd']);
  assert.deepEqual(moveItem(items, 3, 0), ['d', 'a', 'b', 'c']);
  assert.deepEqual(items, ['a', 'b', 'c', 'd']);
  assert.equal(moveItem(items, 1, 1), items);
  assert.equal(moveItem(items, 0, 4), items);
});

test('contact dialog normalizes like mobile and validates with the shared contact grammar', () => {
  assert.equal(normalizeContactUrl(' name@example.com ', 'email'), 'mailto:name@example.com');
  assert.equal(normalizeContactUrl('+7 (700) 123-45-67', 'phone'), 'tel:+77001234567');
  assert.equal(normalizeContactUrl('@stack_card', 'telegram'), 'https://t.me/stack_card');
  const added = saveContact([], null, { label: ' Почта ', kind: 'email', url: 'a@b.co' });
  assert.equal(added.length, 1);
  assert.deepEqual(
    { ...added[0], id: '' },
    {
      id: '',
      label: 'Почта',
      url: 'mailto:a@b.co',
      kind: 'email',
      publishAllowed: true,
      visible: true,
    },
  );
  assert.throws(
    () => saveContact([], null, { label: '', kind: 'website', url: 'https://a.b' }),
    /Название ссылки/,
  );
  assert.throws(
    () => saveContact([], null, { label: 'Сайт', kind: 'website', url: 'javascript:alert(1)' }),
    /https:\/\//,
  );
  assert.throws(
    () => saveContact([], null, { label: 'Телефон', kind: 'phone', url: '12' }),
    /международном/,
  );
  const edited = saveContact(added, added[0], {
    label: 'Сайт',
    kind: 'website',
    url: 'https://example.com',
  });
  assert.equal(edited[0].id, added[0].id);
  assert.equal(edited[0].kind, 'website');
  const hidden: Contact = { ...added[0], id: 'gone' };
  assert.throws(
    () => saveContact(added, hidden, { label: 'x', kind: 'website', url: 'https://a.b' }),
    /изменился/,
  );
});

test('attachment reorder keeps hidden references in place and selection follows mobile order', () => {
  const workspace = migrateMainPortfolio(emptyContent(), null);
  const [a, b, c] = ['a', 'b', 'c'].map((id) => ({ ...emptyProject(), id, title: id }));
  workspace.projects = [a, b, c];
  const document = mainDocument(workspace)!;
  document.projects = [attachment('a'), attachment('ghost'), attachment('b'), attachment('c')];
  assert.deepEqual(
    reorderAttachment(workspace, document, 2, 0).map((x) => x.projectId),
    ['c', 'ghost', 'a', 'b'],
  );
  assert.equal(reorderAttachment(workspace, document, 0, 0), document.projects);
  document.projects = [attachment('b'), attachment('ghost')];
  assert.deepEqual(
    selectAttachments(workspace, document, new Set(['c', 'a', 'b'])).map((x) => x.projectId),
    ['b', 'ghost', 'a', 'c'],
  );
  assert.deepEqual(
    selectAttachments(workspace, document, new Set()).map((x) => x.projectId),
    ['ghost'],
  );
});

test('technology catalog matches mobile aliases and every icon slug has path data', () => {
  assert.equal(findTechnology('next.js')?.title, 'Next.js');
  assert.equal(findTechnology('Postgres')?.title, 'PostgreSQL');
  assert.equal(findTechnology('k8s')?.title, 'Kubernetes');
  assert.equal(findTechnology('Планирование'), null);
  assert.equal(technologySuggestions('re')[0].title, 'React');
  assert.ok(!technologySuggestions('re', ['React']).some((info) => info.title === 'React'));
  assert.equal(technologySuggestions('').length, 0);
  for (const title of ['Kotlin', 'Docker', 'Java'])
    assert.ok(technologyIconPaths[findTechnology(title)!.slug!], title);
});

test('QR encoder picks the smallest version and fixed finder patterns', () => {
  assert.equal(encodeQr('A').size, 21);
  const url = encodeQr(`https://stackcard.example/d/${'a'.repeat(32)}`);
  assert.equal(url.size, 33);
  const finder = (x: number, y: number) =>
    [0, 6].every((d) => url.modules[y][x + d] && url.modules[y + d][x]);
  assert.ok(finder(0, 0) && finder(url.size - 7, 0) && finder(0, url.size - 7));
  assert.throws(() => encodeQr('x'.repeat(400)), /слишком длинная/);
});

test('developer card technologies merge skills and project technologies without repeats', () => {
  const list = cardTechnologies({
    content: {
      skills: [
        { id: '1', name: 'React' },
        { id: '2', name: 'Kotlin' },
      ],
      projects: [{ technologies: ['react', 'Docker'] }],
    },
  } as never);
  assert.deepEqual(list, ['React', 'Kotlin', 'Docker']);
});

test('editor sections are cards with collapse controls, sortable rows and contact icons', () => {
  const content = mainDocument(migrateMainPortfolio(emptyContent(), null))!.content;
  content.skills = [
    { id: 's1', name: 'Kotlin' },
    { id: 's2', name: 'Docker' },
  ];
  content.links = [
    {
      id: 'l1',
      label: 'Почта',
      url: 'mailto:a@b.co',
      kind: 'email',
      publishAllowed: true,
      visible: true,
    },
  ];
  const html = renderToStaticMarkup(createElement(ContentEditor, { content, onChange: () => {} }));
  assert.ok(html.includes('aria-label="Разделы редактора"'));
  assert.ok(html.includes('Свернуть раздел «Навыки»'));
  assert.ok(html.includes('aria-label="Изменить порядок: Kotlin"'));
  assert.ok(html.includes('aria-label="Переместить вниз: Kotlin"'));
  assert.ok(html.includes('aria-label="Редактировать контакт Почта"'));
  assert.ok(html.includes('a@b.co') && !html.includes('>mailto:'));
  assert.ok(html.includes('Пока пусто'));
  // Один элемент не получает ручку перестановки.
  assert.ok(!html.includes('Изменить порядок: Почта'));
});

test('tag dialog keeps Save semantics without trailing periods in validation copy', () => {
  const html = renderToStaticMarkup(
    createElement(TagEditor, {
      heading: 'Технологии',
      title: 'Технология',
      addLabel: 'Добавить технологию',
      removeLabel: 'Удалить технологию',
      listLabel: 'Технологии',
      items: [{ id: 'k', name: 'Kotlin' }],
      onAdd: () => {
        throw new Error('Технология уже добавлена');
      },
      onRemove: () => {},
    }),
  );
  assert.ok(html.includes('Kotlin'));
  assert.ok(html.indexOf('Отмена') < html.indexOf('Сохранить'));
});
