import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { emptyContent } from '../src/lib/model';
import {
  applyVacancyOrder,
  buildVacancyExportContent,
  matchVacancy,
} from '../src/lib/vacancy-match';

const read = (path: string) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
// Комментарии не код: сканируем только исполняемый текст
const code = (path: string) => read(path).replace(/\/\/.*$/gm, '');
// Любое обращение к хранилищам, сети или Firebase в подборе означало бы утечку текста вакансии.
const forbidden =
  /localStorage|sessionStorage|indexedDB|document\.cookie|sendBeacon|XMLHttpRequest|\bfetch\(|from '[^']*firebase[^']*'|saveDraft|recordHistory|draft-repository|portfolio-history/;

test('домен и экран подбора не обращаются к хранилищам, сети и Firebase', () => {
  for (const path of ['src/lib/vacancy-match.ts', 'src/components/vacancy-match-view.tsx'])
    assert.doesNotMatch(code(path), forbidden, path);
});

test('текст вакансии живёт только в экране подбора, а не в кабинете', () => {
  const workspace = read('src/components/workspace.tsx');
  assert.doesNotMatch(workspace, /vacancyText|setVacancy|vacancyDraft/);
  // Кабинет получает от экрана только порядок и готовое содержимое для PDF
  assert.match(read('src/components/vacancy-match-view.tsx'), /useState\(''\)/);
});

test('подбор не трогает глобальные хранилища и сеть', () => {
  const names = ['localStorage', 'sessionStorage', 'indexedDB', 'fetch'] as const;
  const saved = names.map(
    (name) => [name, Object.getOwnPropertyDescriptor(globalThis, name)] as const,
  );
  const touched: string[] = [];
  for (const name of names)
    Object.defineProperty(globalThis, name, {
      configurable: true,
      get() {
        touched.push(name);
        throw new Error(`обращение к ${name}`);
      },
    });
  try {
    const marker = 'СЕКРЕТНАЯ-МЕТКА-7731';
    const content = emptyContent();
    const match = matchVacancy({ vacancyText: `${marker} React, Docker, Kubernetes`, content });
    const exported = buildVacancyExportContent(content, {
      projectOrder: match.projectOrder,
      includedProjects: new Set(),
      sectionOrder: match.sectionOrder,
      includedSections: new Set(match.sectionOrder),
    });
    // Результат не содержит исходный текст вакансии
    assert.doesNotMatch(JSON.stringify(match), /СЕКРЕТНАЯ|7731/);
    assert.doesNotMatch(JSON.stringify(exported), /СЕКРЕТНАЯ|7731/);
    const document = {
      id: 'main',
      title: 'Портфолио',
      kind: 'portfolio' as const,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
      content,
      projects: [],
      attachedResumeId: null,
    };
    assert.doesNotMatch(
      JSON.stringify(
        applyVacancyOrder(document, { projects: match.projectOrder, sections: match.sectionOrder }),
      ),
      /СЕКРЕТНАЯ|7731/,
    );
  } finally {
    for (const [name, descriptor] of saved)
      if (descriptor) Object.defineProperty(globalThis, name, descriptor);
      else delete (globalThis as Record<string, unknown>)[name];
  }
  assert.deepEqual(touched, []);
});
