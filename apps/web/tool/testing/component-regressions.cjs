// Реальные компоненты в изолированном browser harness; GitHub transport синтетический.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const { build } = require('esbuild');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const web = path.resolve(__dirname, '../..');
const output = path.resolve(process.argv[2] || 'component-regressions.json');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'stackcard-component-regressions-'));

(async () => {
  let browser, server;
  try {
    await build({
      stdin: {
        contents: `
          import React, { useState } from 'react';
          import { createRoot } from 'react-dom/client';
          import { GitHubImporter } from './src/components/github-importer';
          import { ShareActions } from './src/components/share-actions';
          function App() {
            const [publicId, setPublicId] = useState('a'.repeat(32));
            const [imported, setImported] = useState('');
            return <main className="container stack">
              <ShareActions title="Synthetic portfolio" publicId={publicId}/>
              <button onClick={() => {
                const next = 'b'.repeat(32);
                history.pushState(null, '', '/d/' + next);
                setPublicId(next);
              }}>Следующий документ</button>
              <GitHubImporter ownerUid="synthetic-owner" username="octocat" projects={[]}
                onSettings={() => {}} onBack={() => {}}
                onImport={async sources => setImported(sources.map(s => s.name).join(', '))}/>
              <output>{imported ? 'Импорт сохранён: ' + imported : ''}</output>
            </main>;
          }
          createRoot(document.getElementById('root')).render(<App/>);
        `,
        resolveDir: web,
        loader: 'tsx',
      },
      bundle: true,
      format: 'esm',
      platform: 'browser',
      target: 'es2022',
      minify: true,
      jsx: 'automatic',
      define: { 'process.env.NODE_ENV': '"production"' },
      outfile: path.join(temporary, 'bundle.js'),
      tsconfig: path.join(web, 'tsconfig.json'),
    });
    server = http.createServer((request, response) => {
      const url = new URL(request.url, 'http://localhost').pathname;
      let file;
      if (url === '/bundle.js') file = path.join(temporary, 'bundle.js');
      else if (url === '/globals.css') file = path.join(web, 'src/app/globals.css');
      else if (/^\/(fonts|icons)\/[\w/.-]+$/.test(url) && !url.includes('..'))
        file = path.join(web, 'public', url);
      else if (url.startsWith('/d/')) {
        response.setHeader('Content-Type', 'text/html; charset=utf-8');
        return response.end(
          '<!doctype html><html lang="ru"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/globals.css"><div id="root"></div><script>window.process={env:{NODE_ENV:"production"}}</script><script type="module" src="/bundle.js"></script></html>',
        );
      }
      if (!file || !fs.existsSync(file)) {
        response.writeHead(404);
        return response.end();
      }
      const types = {
        '.js': 'application/javascript',
        '.css': 'text/css',
        '.svg': 'image/svg+xml',
        '.ttf': 'font/ttf',
        '.woff2': 'font/woff2',
      };
      response.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
      response.end(fs.readFileSync(file));
    });
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const origin = `http://127.0.0.1:${server.address().port}`;
    browser = await chromium.launch({
      headless: true,
      ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
    });
    const context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      reducedMotion: 'reduce',
    });
    await context.addInitScript(() => {
      Object.defineProperty(window, 'localStorage', {
        configurable: true,
        get() {
          throw new DOMException('Storage blocked', 'SecurityError');
        },
      });
      Object.defineProperty(navigator, 'share', { configurable: true, value: undefined });
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: {
          async writeText(value) {
            window.copiedUrl = value;
          },
        },
      });
    });
    await context.route('https://api.github.com/**', (route) =>
      route.fulfill({
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: 123,
            name: 'Synthetic project',
            full_name: 'octocat/synthetic',
            html_url: 'https://github.com/octocat/synthetic',
            updated_at: '2026-10-24T00:00:00Z',
            description: 'Synthetic audit fixture',
            language: 'TypeScript',
            stargazers_count: 0,
            forks_count: 0,
            fork: false,
            archived: false,
          },
        ]),
      }),
    );
    const errors = [];
    const page = await context.newPage();
    page.on('pageerror', (error) => {
      errors.push(error.message);
      console.error(error.message);
    });
    page.setDefaultTimeout(10000);
    await page.goto(`${origin}/d/${'a'.repeat(32)}`);
    const link = page.getByRole('textbox', { name: 'Постоянный адрес документа' });
    await page.waitForFunction(() =>
      document.querySelector('input[readonly]')?.value.endsWith('a'.repeat(32)),
    );
    await page.getByRole('button', { name: 'Копировать', exact: true }).click();
    assert.equal(await page.evaluate(() => window.copiedUrl), `${origin}/d/${'a'.repeat(32)}`);
    await page.getByRole('button', { name: 'Следующий документ', exact: true }).click();
    await page.waitForFunction(() =>
      document.querySelector('input[readonly]')?.value.endsWith('b'.repeat(32)),
    );
    assert.equal(await link.inputValue(), `${origin}/d/${'b'.repeat(32)}`);
    await page.getByRole('button', { name: 'Копировать', exact: true }).click();
    assert.equal(await page.evaluate(() => window.copiedUrl), `${origin}/d/${'b'.repeat(32)}`);
    await page.getByRole('checkbox').check();
    await page.getByRole('button', { name: 'Импортировать выбранные (1)', exact: true }).click();
    await page.getByText('Импорт сохранён: Synthetic project', { exact: true }).waitFor();
    for (const width of [320, 1440]) {
      await page.setViewportSize({ width, height: 844 });
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    }
    assert.deepEqual(errors, []);
    fs.writeFileSync(
      output,
      JSON.stringify(
        {
          environment:
            'Isolated real React components in Chrome; blocked localStorage getter; synthetic GitHub and clipboard',
          browser: await browser.version(),
          passed: [
            'Share URL and Copy update after same-instance document navigation',
            'GitHub loads and imports despite localStorage SecurityError',
            'No horizontal overflow at 320px and 1440px',
            'No uncaught browser exceptions',
          ],
          limitations: 'No Firebase, backend, actual GitHub HTTP or native clipboard acceptance.',
        },
        null,
        2,
      ),
    );
    console.log('Component browser regressions PASS: 4 checkpoints');
  } finally {
    await browser?.close();
    if (server) await new Promise((resolve) => server.close(resolve));
    fs.rmSync(temporary, { recursive: true, force: true });
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
