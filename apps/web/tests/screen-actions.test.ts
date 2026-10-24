import assert from 'node:assert/strict';
import test from 'node:test';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { GitHubImporter } from '../src/components/github-importer';
import { SiteFooter } from '../src/components/marketing';
import { ProductDemo } from '../src/components/product-demo';
import { ShareActions } from '../src/components/share-actions';
import DownloadPage from '../src/app/download/page';

test('GitHub import directs profile setup to Settings and keeps a configured source read-only', () => {
  for (const username of ['', 'octocat']) {
    const markup = renderToStaticMarkup(
      createElement(GitHubImporter, {
        ownerUid: 'owner',
        username,
        projects: [],
        onSettings: () => {},
        onBack: () => {},
        onImport: async () => {},
      }),
    );
    assert.match(markup, /Открыть настройки/);
    assert.match(markup, /Назад к проектам/);
    assert.doesNotMatch(markup, /placeholder="https:\/\/github\.com\/username"|>Сохранить</);
    if (username) {
      assert.match(markup, /github\.com\/octocat/);
      assert.match(markup, /Поиск по названию и описанию/);
      assert.match(markup, /Импортировать выбранные/);
    } else {
      assert.match(markup, /Добавьте GitHub-профиль в настройках/);
      assert.doesNotMatch(markup, /<input|Импортировать выбранные/);
    }
  }
});

test('footer offers one workspace entry and a distinct project-library destination', () => {
  const markup = renderToStaticMarkup(createElement(SiteFooter));
  assert.match(markup, /href="\/workspace">Личный кабинет</);
  assert.match(markup, /href="\/workspace#projects">Проекты</);
  assert.doesNotMatch(markup, /\/workspace#(?:base|resumes|portfolios)/);
});

test('product demo uses actual workspace destinations while preserving both output previews', () => {
  const markup = renderToStaticMarkup(createElement(ProductDemo));
  assert.match(markup, /href="\/workspace#home"/);
  assert.match(markup, /href="\/workspace#projects"/);
  assert.match(markup, /href="\/workspace#editor"/);
  assert.match(markup, /aria-label="Открыть редактор"/);
  assert.doesNotMatch(markup, /\/workspace#(?:resumes|portfolios)/);
  assert.match(markup, /aria-pressed="true">Портфолио</);
  assert.match(markup, /aria-pressed="false">Резюме</);
});

test('download page retains release status and browser entry without unavailable download actions', () => {
  const markup = renderToStaticMarkup(createElement(DownloadPage));
  assert.match(markup, /Android/);
  assert.match(markup, /iOS/);
  assert.equal(markup.match(/Публичного релиза пока нет/g)?.length, 2);
  assert.match(markup, /href="\/workspace"[^>]*>Открыть StackCard/);
  assert.doesNotMatch(markup, /Скачать для Android|Скачать для iOS/);
});

test('public share panel always exposes Copy without self-open or an unverified Share capability', () => {
  const markup = renderToStaticMarkup(
    createElement(ShareActions, { title: 'Portfolio', publicId: 'a'.repeat(32) }),
  );
  assert.match(markup, /Постоянный адрес документа/);
  assert.match(markup, />Копировать</);
  assert.doesNotMatch(markup, /<a|>Открыть<|>Поделиться</);
});
