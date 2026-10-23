// Только disposable demo emulators; реальный Next runtime, Auth/Firestore SDK и Node API.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { createServer } = require('node:net');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const web = path.resolve(__dirname, '../..');
const backend = path.resolve(web, '../../firebase/functions');
const output = path.resolve(process.argv[2] || 'phase17-browser.json');
assert.equal(process.env.GCLOUD_PROJECT, 'demo-stackcard-test');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8085');
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9099');
const origin = 'http://127.0.0.1:3800';
const api = 'http://127.0.0.1:3810/documentPublication';
const env = {
  ...process.env,
  FUNCTIONS_EMULATOR: 'true',
  BACKEND_PORT: '3810',
  PUBLIC_WEB_ORIGIN: origin,
  PUBLIC_STORAGE_BUCKET: '',
  CONTACT_APP_CHECK_APP_ID: '',
  CONTACT_RATE_HMAC_KEY: '',
  NEXT_PUBLIC_FIREBASE_API_KEY: 'demo-key',
  NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN: 'demo-stackcard-test.firebaseapp.com',
  NEXT_PUBLIC_FIREBASE_PROJECT_ID: 'demo-stackcard-test',
  NEXT_PUBLIC_FIREBASE_APP_ID: 'demo-app',
  NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET: '',
  NEXT_PUBLIC_PUBLICATION_API_URL: api,
  NEXT_PUBLIC_CONTACT_INBOX_API_URL: '',
  NEXT_PUBLIC_APP_CHECK_SITE_KEY: '',
  NEXT_PUBLIC_WEB_ORIGIN: origin,
  NEXT_PUBLIC_USE_EMULATORS: 'true',
  NEXT_PUBLIC_AUTH_EMULATOR_URL: 'http://127.0.0.1:9099',
  NEXT_PUBLIC_FIRESTORE_EMULATOR_HOST: '127.0.0.1',
  NEXT_PUBLIC_FIRESTORE_EMULATOR_PORT: '8085',
  NEXT_PUBLIC_STORAGE_EMULATOR_HOST: '127.0.0.1',
  NEXT_PUBLIC_STORAGE_EMULATOR_PORT: '9199',
};
const children = [];
const running = (child) => child.exitCode === null && child.signalCode === null;
async function vacant(port) {
  const probe = createServer();
  await new Promise((resolve, reject) => {
    probe.once('error', reject);
    probe.listen(port, '127.0.0.1', resolve);
  });
  await new Promise((resolve) => probe.close(resolve));
}
function launch(script, args, cwd, log) {
  const fd = fs.openSync(log, 'w');
  const child = spawn(process.execPath, [script, ...args], { cwd, env, stdio: ['ignore', fd, fd] });
  fs.closeSync(fd);
  children.push(child);
  return child;
}
async function ready(url, child) {
  const until = Date.now() + 30000;
  while (Date.now() < until) {
    if (!running(child))
      throw new Error(`Local server exited: ${child.exitCode ?? child.signalCode}`);
    try {
      if ((await fetch(url)).ok) return;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Local server unavailable: ${url}`);
}

(async () => {
  let browser, page;
  const nextEnv = fs.readFileSync(path.join(web, 'next-env.d.ts'));
  try {
    await Promise.all([vacant(3800), vacant(3810)]);
    if (!process.argv.includes('--skip-build')) {
      const build = launch(
        path.join(web, 'node_modules/next/dist/bin/next'),
        ['build', '--webpack'],
        web,
        `${output}.build.log`,
      );
      const code = await new Promise((resolve) => build.once('exit', resolve));
      assert.equal(code, 0, 'Next production build');
    }
    const server = launch(path.join(backend, 'src/server.mjs'), [], backend, `${output}.api.log`);
    const next = launch(
      path.join(web, 'node_modules/next/dist/bin/next'),
      ['start', '-H', '127.0.0.1', '-p', '3800'],
      web,
      `${output}.next.log`,
    );
    await Promise.all([ready('http://127.0.0.1:3810/health', server), ready(origin, next)]);
    browser = await chromium.launch({
      headless: true,
      ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
    });
    const context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      reducedMotion: 'reduce',
    });
    const blockedHosts = [],
      errors = [],
      passed = [];
    const localOnly = (route) => {
      const url = new URL(route.request().url());
      if (!['127.0.0.1', 'localhost'].includes(url.hostname)) {
        blockedHosts.push(url.hostname);
        return route.abort();
      }
      return route.continue();
    };
    await context.route('**/*', localOnly);
    await context.addInitScript(() => {
      // Clipboard — граница браузера, без системного меню или отправки кому-либо.
      Object.defineProperty(navigator, 'share', { value: undefined, configurable: true });
      Object.defineProperty(navigator, 'clipboard', {
        value: {
          async writeText(value) {
            window.sharedUrl = value;
          },
        },
        configurable: true,
      });
    });
    page = await context.newPage();
    page.setDefaultTimeout(15000);
    page.on('pageerror', (error) => errors.push(error.message));
    let token;
    page.on('response', async (response) => {
      if (response.url().includes('accounts:signUp') && response.ok()) {
        token = (await response.json()).idToken;
      }
    });
    await page.goto(`${origin}/workspace/editor`);
    await page.waitForURL('**/sign-in?**');
    passed.push('signed-out owner route redirects with returnTo');
    await page.goto(`${origin}/sign-up`);
    await page
      .getByRole('textbox', { name: 'Почта', exact: true })
      .fill(`journey-${Date.now()}@example.test`);
    await page.getByLabel('Пароль', { exact: true }).fill('Testing#7392Brick');
    await page.getByLabel('Подтверждение пароля', { exact: true }).fill('Testing#7392Brick');
    await page.getByRole('button', { name: 'Создать аккаунт', exact: true }).click();
    await page.getByText('Шаг 1 из 4', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Далее', exact: true }).click();
    await page.getByText('Шаг 2 из 4', { exact: true }).waitFor();
    await page.getByRole('textbox', { name: 'Имя', exact: true }).fill('Browser author');
    await page.getByRole('button', { name: 'Далее', exact: true }).click();
    await page.getByText('Шаг 3 из 4', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Далее', exact: true }).click();
    await page.getByText('Шаг 4 из 4', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Завершить', exact: true }).click();
    await page.getByRole('heading', { name: 'Browser author', exact: true }).waitFor();
    passed.push('registration and four optional onboarding steps reach saved Home');
    const navigation = page.getByRole('navigation', { name: 'Рабочая область' });
    await navigation.getByRole('button', { name: 'Проекты', exact: true }).click();
    await page.getByRole('button', { name: 'Создать проект', exact: true }).click();
    await page.getByRole('textbox', { name: 'Название', exact: true }).fill('Journey project');
    await page
      .getByRole('textbox', { name: 'Сайт проекта', exact: true })
      .fill('https://example.com/journey');
    await page.getByRole('button', { name: 'Сохранить', exact: true }).click();
    await page.getByText('Сохранено', { exact: true }).waitFor();
    await navigation.getByRole('button', { name: 'Редактор', exact: true }).click();
    await page.getByRole('button', { name: 'Добавить проект', exact: true }).click();
    await page.getByRole('button', { name: 'Journey project', exact: true }).click();
    await page.getByRole('button', { name: 'Сохранить', exact: true }).click();
    await page.getByText('Сохранено', { exact: true }).waitFor();
    await page.getByRole('textbox', { name: 'Имя', exact: true }).fill('PRIVATE_BUFFER');
    await navigation.getByRole('button', { name: 'Главная', exact: true }).click();
    const confirmation = page.getByRole('dialog');
    await confirmation.getByRole('button', { name: 'Отмена', exact: true }).waitFor();
    await page.keyboard.press('Escape');
    assert.equal(
      await page.getByRole('textbox', { name: 'Имя', exact: true }).inputValue(),
      'PRIVATE_BUFFER',
    );
    await navigation.getByRole('button', { name: 'Главная', exact: true }).click();
    await confirmation.getByRole('button', { name: 'Подтвердить', exact: true }).click();
    await page.getByRole('heading', { name: 'Browser author', exact: true }).waitFor();
    assert.equal(await page.getByText('PRIVATE_BUFFER', { exact: true }).count(), 0);
    const inventoryReady = page.waitForResponse(
      (response) =>
        response.url() === api &&
        response.request().method() === 'POST' &&
        response.request().postDataJSON().action === 'inventory' &&
        response.status() === 200,
      { timeout: 30000 },
    );
    await page.reload();
    await (await inventoryReady).finished();
    await page.getByRole('heading', { name: 'Journey project', exact: true }).waitFor();
    passed.push(
      'scoped project Save, attachment, keyboard cancel/discard and page restart preserve saved main',
    );
    const download = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Скачать портфолио', exact: true }).click();
    await (await download).saveAs(`${output}.pdf`);
    assert.equal(fs.readFileSync(`${output}.pdf`).subarray(0, 5).toString(), '%PDF-');
    passed.push('saved Home exports a genuine PDF');
    await page.getByRole('button', { name: 'Поделиться', exact: true }).click();
    await page.getByRole('dialog', { name: 'Опубликовать портфолио?', exact: true }).waitFor();
    const publicationResponse = page.waitForResponse(
      (response) =>
        response.url() === api &&
        response.request().method() === 'POST' &&
        response.request().postDataJSON().action === 'publish' &&
        response.status() === 200,
    );
    await page
      .getByRole('dialog')
      .getByRole('button', { name: 'Подтвердить', exact: true })
      .click();
    const published = await (await publicationResponse).json();
    await page.waitForFunction(() => !!window.sharedUrl);
    assert.equal(await page.evaluate(() => window.sharedUrl), published.publication.url);
    const anonymous = await browser.newContext();
    await anonymous.route('**/*', localOnly);
    const publicPage = await anonymous.newPage();
    await publicPage.goto(published.publication.url);
    await publicPage.getByRole('heading', { name: 'Browser author', exact: true }).waitFor();
    await publicPage.getByRole('heading', { name: 'Journey project', exact: true }).waitFor();
    passed.push('explicit Publish verifies Auth token and anonymous Next SSR reads public schema2');
    await navigation.getByRole('button', { name: 'Редактор', exact: true }).click();
    await page.getByRole('textbox', { name: 'Имя', exact: true }).fill('Newer saved author');
    await page.getByRole('button', { name: 'Сохранить', exact: true }).click();
    await page.getByText('Сохранено', { exact: true }).waitFor();
    await publicPage.reload();
    await publicPage.getByRole('heading', { name: 'Browser author', exact: true }).waitFor();
    assert(token);
    const response = await fetch(api, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', origin, authorization: `Bearer ${token}` },
      body: JSON.stringify({
        action: 'unpublish',
        operationId: `browser-withdraw-${Date.now()}`,
        documentId: published.publication.documentId,
        expectedVersion: published.publication.version,
        expectedGeneration: published.lifecycleGeneration,
      }),
    });
    assert.equal(response.status, 200);
    const withdrawn = await publicPage.reload();
    assert.equal(withdrawn.status(), 404);
    passed.push(
      'later private Save leaves publication unchanged; authenticated withdrawal makes anonymous route 404',
    );
    for (const width of [320, 1440]) {
      await page.setViewportSize({ width, height: 844 });
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    }
    await page.screenshot({ path: `${output}.png` });
    await page.getByRole('button', { name: 'Настройки', exact: true }).click();
    await page.getByRole('button', { name: 'Выйти', exact: true }).click();
    await page.waitForURL('**/sign-in?**');
    await page.goto(`${origin}/workspace/editor`);
    await page.waitForURL('**/sign-in?**');
    passed.push('logout removes private access and deep-link guard remains active');
    assert.deepEqual(blockedHosts, []);
    assert.deepEqual(errors, []);
    fs.writeFileSync(
      output,
      JSON.stringify(
        {
          environment:
            'Next production + Chrome + disposable Auth/Firestore emulators + standalone Node API',
          browser: await browser.version(),
          passed,
          clipboard: 'stub',
          github: 'covered separately by Dart/controller and HTTP suites',
          limitations:
            'No native device, physical QR/share, live backend or device performance acceptance.',
        },
        null,
        2,
      ),
    );
    console.log(`Browser journey PASS: ${passed.length} checkpoints`);
  } catch (error) {
    if (page) {
      fs.writeFileSync(
        `${output}.failure.txt`,
        (await page.locator('body').innerText()).slice(0, 12000),
      );
      await page.screenshot({ path: `${output}.failure.png` });
    }
    throw error;
  } finally {
    try {
      await browser?.close();
    } finally {
      for (const child of children) if (running(child)) child.kill('SIGTERM');
      await Promise.all(
        children.map((child) =>
          running(child) ? new Promise((resolve) => child.once('exit', resolve)) : undefined,
        ),
      );
      fs.writeFileSync(path.join(web, 'next-env.d.ts'), nextEnv);
    }
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
