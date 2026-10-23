// Изолированный browser harness реальных компонентов; Firebase и owner storage не подключаются.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const http = require('node:http');
const assert = require('node:assert/strict');
const { build } = require('esbuild');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const web = path.resolve(__dirname, '../..');
const [fixture, output] = process.argv.slice(2);
if (!fixture || !output)
  throw new Error('Usage: node benchmark.cjs <workspace.json> <output.json>');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'stackcard-performance-'));

(async () => {
  const bundle = await build({
    stdin: {
      contents: `
        import React, { useState } from 'react';
        import { createRoot } from 'react-dom/client';
        import { ContentEditor } from './src/components/content-editor';
        import { AttachmentsEditor } from './src/components/project-editor';
        import { DocumentView } from './src/components/document-view';
        import { validateWorkspace, resolveDocument } from './src/lib/model';
        import { documentPreview } from './src/lib/preview';
        import { generatePortfolioPdf } from './src/lib/portfolio-pdf';
        const workspace = validateWorkspace(await (await fetch('/fixture.json')).json(), 'performance');
        const original = workspace.documents.find(d => d.id === workspace.mainPortfolioId);
        window.samples = [];
        window.measureEdit = () => {
          const start = performance.now();
          requestAnimationFrame(() => requestAnimationFrame(() => window.samples.push(performance.now() - start)));
        };
        function App() {
          const [document, setDocument] = useState(original);
          const [pdf, setPdf] = useState('');
          const isPublic = location.hash === '#public';
          const avatar = <img className="portrait" width="128" height="128" src="/images/demo-portrait.png" alt="Фото автора"/>;
          return <main className="container stack">
            {isPublic ? <DocumentView content={documentPreview(workspace, document)} kind="portfolio"
              modernPortfolio preview profilePhoto={avatar}/> : <ContentEditor content={document.content}
              onChange={content => { window.measureEdit(); setDocument({...document, content}); }} photo={avatar}
              projects={<AttachmentsEditor workspace={workspace} document={document} onChange={setDocument}
                onIconChange={() => {}} onProjects={() => {}}/>}/>}
            <button id="export" onClick={async () => {
              try {
              const start = performance.now();
              const response = await fetch('/images/demo-portrait.png');
              const bitmap = await createImageBitmap(await response.blob());
              const canvas = window.document.createElement('canvas');
              canvas.width = canvas.height = 512;
              canvas.getContext('2d').drawImage(bitmap, 0, 0, 512, 512);
              bitmap.close();
              const jpeg = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', .85));
              const avatarBytes = new Uint8Array(await jpeg.arrayBuffer());
              const blob = await generatePortfolioPdf(resolveDocument(workspace, document), {avatarBytes});
              window.pdf = {wallMs: performance.now()-start, bytes:blob.size, type:blob.type};
              setPdf('PDF готов');
              } catch (error) { window.pdfError = error.message; setPdf('Ошибка PDF'); }
            }}>Экспорт PDF</button><output>{pdf}</output>
          </main>;
        }
        createRoot(document.getElementById('root')).render(<App/>);
      `,
      resolveDir: web,
      loader: 'tsx',
    },
    bundle: true,
    splitting: true,
    format: 'esm',
    platform: 'browser',
    target: 'es2022',
    minify: true,
    jsx: 'automatic',
    define: { 'process.env.NODE_ENV': '"production"' },
    outdir: temporary,
    metafile: true,
    tsconfig: path.join(web, 'tsconfig.json'),
  });
  const pdfChunks = Object.entries(bundle.metafile.outputs)
    .filter(([, value]) =>
      Object.keys(value.inputs).some((input) => input.includes('portfolio-pdf-renderer')),
    )
    .map(([file]) => path.basename(file));
  assert(pdfChunks.length > 0, 'PDF renderer must have a separate chunk');
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost').pathname;
    if (url === '/') {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      return res.end(
        '<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/globals.css"><div id="root"></div><script>window.process={env:{NODE_ENV:"production"}}</script><script type="module" src="/stdin.js"></script></html>',
      );
    }
    let file;
    if (url === '/fixture.json') file = path.resolve(fixture);
    else if (url === '/globals.css') file = path.join(web, 'src/app/globals.css');
    else if (Object.keys(bundle.metafile.outputs).some((file) => url === '/' + path.basename(file)))
      file = path.join(temporary, path.basename(url));
    else if (/^\/(fonts|icons|images)\/[\w/.-]+$/.test(url) && !url.includes('..'))
      file = path.join(web, 'public', url);
    if (!file || !fs.existsSync(file)) {
      res.statusCode = 404;
      return res.end();
    }
    const mime = {
      '.css': 'text/css',
      '.js': 'application/javascript',
      '.json': 'application/json',
      '.svg': 'image/svg+xml',
      '.ttf': 'font/ttf',
      '.png': 'image/png',
    };
    res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
    res.end(fs.readFileSync(file));
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({
      headless: true,
      ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
    });
    const results = {
      environment: {
        browser: await browser.version(),
        mode: 'isolated production React component harness',
        platform: `${os.platform()} ${os.arch()}`,
        cpu: os.cpus()[0].model,
      },
      scenarios: [],
    };
    for (const width of [320, 390, 1440]) {
      for (const kind of ['editor', 'public']) {
        const page = await browser.newPage({ viewport: { width, height: 844 } });
        const errors = [],
          requests = [],
          failures = [];
        page.on('pageerror', (error) => {
          errors.push(error.message);
          console.error('PAGE', kind, width, error.stack);
        });
        page.on('request', (request) => requests.push(request.url()));
        page.on('response', (response) => {
          if (response.status() >= 400) failures.push(response.url());
        });
        const cdp = await page.context().newCDPSession(page);
        await cdp.send('Performance.enable');
        await cdp.send('HeapProfiler.enable');
        const started = performance.now();
        await page.goto(`http://127.0.0.1:${server.address().port}/#${kind}`);
        await page.getByRole('button', { name: 'Экспорт PDF', exact: true }).waitFor();
        await page.evaluate(() => document.fonts.ready);
        const mountWallMs = performance.now() - started;
        assert.equal(await page.getByText(/LEGACY_PRIVATE/).count(), 0);
        assert(
          !requests.some((url) => pdfChunks.some((chunk) => url.endsWith(chunk))),
          'PDF fetched before export',
        );
        if (kind === 'editor') {
          await page
            .getByRole('textbox', { name: 'Имя', exact: true })
            .pressSequentially(' проверка ввода', { delay: 35 });
          await page.waitForFunction(() => window.samples.length >= 14);
        }
        const layout = await page.evaluate(() => ({
          overflowPx: document.documentElement.scrollWidth - innerWidth,
          nodes: document.querySelectorAll('*').length,
          fontLoaded: document.fonts.check('16px Manrope'),
          avatarLoaded: [...document.images].some(
            (img) => img.src.includes('demo-portrait') && img.naturalWidth > 0,
          ),
          inputToTwoRafMs: window.samples,
          resourceBytes: performance
            .getEntriesByType('resource')
            .reduce((sum, r) => sum + r.transferSize, 0),
        }));
        assert(layout.overflowPx <= 1, `${kind}/${width} horizontal overflow ${layout.overflowPx}`);
        assert(layout.fontLoaded && layout.avatarLoaded);
        await page.screenshot({ path: `${output}.${kind}-${width}.png` });
        await page.evaluate(() => scrollTo(0, document.documentElement.scrollHeight));
        await cdp.send('HeapProfiler.collectGarbage');
        const metrics = (await cdp.send('Performance.getMetrics')).metrics;
        results.scenarios.push({
          width,
          kind,
          mountWallMs,
          ...layout,
          jsHeapUsedBytes: metrics.find((m) => m.name === 'JSHeapUsedSize').value,
          localFontRequests: requests.filter((url) => url.includes('/fonts/')).length,
          localSvgRequests: requests.filter((url) => url.endsWith('.svg')).length,
          pdfRequestsBeforeExport: 0,
        });
        if (width === 390 && kind === 'public') {
          await page.locator('#export').click();
          await page.waitForFunction(() => window.pdf || window.pdfError, null, { timeout: 60000 });
          assert.equal(await page.evaluate(() => window.pdfError), undefined);
          assert(requests.some((url) => pdfChunks.some((chunk) => url.endsWith(chunk))));
          results.pdf = await page.evaluate(() => window.pdf);
          assert.equal(results.pdf.type, 'application/pdf');
          assert(results.pdf.bytes > 1000);
        }
        assert.deepEqual(errors, []);
        assert.deepEqual(failures, []);
        await page.close();
      }
    }
    fs.writeFileSync(output, JSON.stringify(results, null, 2));
    console.log(JSON.stringify(results));
  } finally {
    await browser?.close();
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
})()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => {
    fs.rmSync(temporary, { recursive: true, force: true });
  });
