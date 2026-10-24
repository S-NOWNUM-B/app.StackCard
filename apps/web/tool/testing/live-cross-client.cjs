// Opt-in проверка настоящего Firebase: только новые disposable accounts, без писем и публикации.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const http = require('node:http');
const { spawn } = require('node:child_process');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const web = path.resolve(__dirname, '../..');
const mobile = path.resolve(web, '../mobile');
const device = process.env.ANDROID_DEVICE;
assert.match(device || '', /^emulator-\d+$/, 'ANDROID_DEVICE must select an Android emulator');
const properties = path.join(mobile, 'android/local.properties');
const sdk =
  process.env.ANDROID_HOME ||
  process.env.ANDROID_SDK_ROOT ||
  (fs.existsSync(properties) &&
    fs
      .readFileSync(properties, 'utf8')
      .split('\n')
      .find((line) => line.startsWith('sdk.dir='))
      ?.slice(8));
const adb = process.env.ADB_BIN || (sdk && path.join(sdk, 'platform-tools/adb'));
assert(adb && fs.existsSync(adb), 'Configure Android SDK or ADB_BIN');
require(path.join(web, 'node_modules/@next/env')).loadEnvConfig(web);
assert.equal(process.env.RUN_LIVE_CROSS_CLIENT_ACCEPTANCE, 'true');
assert.equal(process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID, 'stackcard-dev-snownumb');
assert.notEqual(process.env.NEXT_PUBLIC_USE_EMULATORS, 'true');
assert(!process.env.FIRESTORE_EMULATOR_HOST && !process.env.FIREBASE_AUTH_EMULATOR_HOST);
const project = 'stackcard-dev-snownumb';
const key = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
assert(key);
const origin = 'http://127.0.0.1:3900';
const run = crypto.randomBytes(16).toString('hex');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'stackcard-live-sync-'));
fs.chmodSync(dir, 0o700);
const defines = path.join(dir, 'defines.json');
const report = {
  project,
  run,
  passed: [],
  cleanup: false,
  google: 'deferred by user',
  emailDelivery: 'no test mailbox',
};
const fixtures = ['a', 'b'].map((label) => ({
  email: `live-sync.${label}.${run}@example.invalid`,
  password: `${crypto.randomBytes(27).toString('base64url')}Aa1!`,
}));
const stages = [
  'native-read-web',
  'native-saved',
  'native-offline',
  'native-reconnected',
  'native-isolation',
];
const children = [];
let browser,
  page,
  bridge,
  currentStage = 'bootstrap',
  stageIndex = 0,
  fatal,
  nativeProcess,
  nativeCleanup;
const diagnostics = [];
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
function writeDefines() {
  fs.writeFileSync(
    defines,
    JSON.stringify({
      RUN_LIVE_CROSS_CLIENT_ACCEPTANCE: 'true',
      LIVE_SYNC_RUN_ID: run,
      LIVE_SYNC_OWNER_EMAIL: fixtures[0].email,
      LIVE_SYNC_OWNER_PASSWORD: fixtures[0].password,
      LIVE_SYNC_OWNER_UID: fixtures[0].uid || '',
      LIVE_SYNC_FOREIGN_EMAIL: fixtures[1].email,
      LIVE_SYNC_FOREIGN_PASSWORD: fixtures[1].password,
      LIVE_SYNC_FOREIGN_UID: fixtures[1].uid || '',
    }),
    { mode: 0o600 },
  );
}
function mark(check) {
  report.passed.push(check);
  console.log(`STACKCARD_LIVE_WEB:${check}`);
}
function launch(command, args, cwd, name) {
  const fd = fs.openSync(path.join(dir, name), 'w', 0o600);
  const child = spawn(command, args, { cwd, env: process.env, stdio: ['ignore', fd, fd] });
  fs.closeSync(fd);
  children.push(child);
  return child;
}
async function ready(child) {
  for (let n = 0; n < 120; n++) {
    if (child.exitCode !== null) throw new Error('Next exited');
    try {
      if ((await fetch(origin)).ok) return;
    } catch {}
    await delay(250);
  }
  throw new Error('Next timeout');
}
async function register(fixture) {
  await page.goto(`${origin}/sign-up`);
  await page.getByRole('textbox', { name: 'Почта', exact: true }).fill(fixture.email);
  await page.getByLabel('Пароль', { exact: true }).fill(fixture.password);
  await page.getByLabel('Подтверждение пароля', { exact: true }).fill(fixture.password);
  const response = page.waitForResponse((r) =>
    r.url().includes('identitytoolkit.googleapis.com/v1/accounts:signUp'),
  );
  await page.getByRole('button', { name: 'Создать аккаунт', exact: true }).click();
  const reply = await response;
  assert.equal(reply.status(), 200, 'Real account registration');
  const account = await reply.json();
  assert.equal(account.email, fixture.email);
  assert(account.localId && account.idToken);
  fixture.uid = account.localId;
  fixture.token = account.idToken;
  writeDefines();
  await page.getByText('Шаг 1 из 4', { exact: true }).waitFor();
}
async function onboard(name, headline) {
  await page.getByRole('button', { name: 'Далее', exact: true }).click();
  await page.getByText('Шаг 2 из 4', { exact: true }).waitFor();
  await page.getByRole('textbox', { name: 'Имя', exact: true }).fill(name);
  await page.getByRole('textbox', { name: 'Должность', exact: true }).fill(headline);
  await page.getByRole('button', { name: 'Далее', exact: true }).click();
  await page.getByText('Шаг 3 из 4', { exact: true }).waitFor();
  await page.getByRole('button', { name: 'Далее', exact: true }).click();
  await page.getByText('Шаг 4 из 4', { exact: true }).waitFor();
  await page.getByRole('button', { name: 'Завершить', exact: true }).click();
  await page.getByRole('heading', { name, exact: true }).waitFor();
}
async function signOut() {
  await page.goto(`${origin}/workspace#settings`);
  await page.getByRole('button', { name: 'Выйти', exact: true }).click();
  await page.waitForURL('**/sign-in**');
}
async function signIn(fixture) {
  await page.goto(`${origin}/sign-in`);
  await page.getByRole('textbox', { name: 'Почта', exact: true }).fill(fixture.email);
  await page.getByLabel('Пароль', { exact: true }).fill(fixture.password);
  await page.getByRole('button', { name: 'Войти', exact: true }).click();
  await page.waitForURL('**/workspace**');
}
async function editor(name, headline) {
  await page.goto(`${origin}/workspace/editor`);
  await page.getByRole('textbox', { name: 'Имя', exact: true }).waitFor();
  assert.equal(await page.getByRole('textbox', { name: 'Имя', exact: true }).inputValue(), name);
  assert.equal(
    await page.getByRole('textbox', { name: 'Должность', exact: true }).inputValue(),
    headline,
  );
}
async function stage(name) {
  currentStage = name;
  if (name === 'native-read-web') mark('real-android-read-web-save');
  if (name === 'native-saved') {
    await editor(`Live web seed ${run}`, `Android cloud ack ${run}`);
    await page.getByRole('textbox', { name: 'Имя', exact: true }).fill(`Web roundtrip ${run}`);
    await page.getByRole('button', { name: 'Сохранить', exact: true }).click();
    await page.getByText('Сохранено', { exact: true }).waitFor();
    mark('real-web-read-android-and-save-roundtrip');
  }
  if (name === 'native-offline') {
    await editor(`Web roundtrip ${run}`, `Android cloud ack ${run}`);
    mark('android-offline-save-stays-local-before-ack');
  }
  if (name === 'native-reconnected') {
    await editor(`Web roundtrip ${run}`, `Android offline restore ${run}`);
    await signOut();
    await signIn(fixtures[1]);
    await editor(`Foreign web ${run}`, `Foreign initial ${run}`);
    await signOut();
    await signIn(fixtures[0]);
    await editor(`Web roundtrip ${run}`, `Android offline restore ${run}`);
    mark('real-web-read-durable-android-outbox-and-account-isolation');
  }
  if (name === 'native-isolation') mark('real-android-account-isolation-and-foreign-rules-denial');
}
// Cleanup использует только UID, возвращённые signUp этого запуска, и не зависит от trusted API.
async function cleanup(fixture) {
  if (!fixture.uid) return;
  assert(/^live-sync\.[ab]\.[a-f0-9]{32}@example\.invalid$/.test(fixture.email));
  assert(fixture.email.includes(run));
  const result = await page.evaluate(
    async ({ fixture, key, project, nativeProof }) => {
      const auth = async (action, body) => {
        const r = await fetch(
          `https://identitytoolkit.googleapis.com/v1/accounts:${action}?key=${key}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
          },
        );
        return { status: r.status, body: await r.json() };
      };
      const lookup = await auth('lookup', { idToken: fixture.token });
      if (lookup.status === 400 && lookup.body.error?.message === 'USER_NOT_FOUND')
        return nativeProof;
      const user = lookup.body.users?.[0];
      if (lookup.status !== 200 || user?.localId !== fixture.uid || user?.email !== fixture.email)
        return false;
      const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/accounts/${encodeURIComponent(fixture.uid)}`;
      const headers = { Authorization: `Bearer ${fixture.token}` };
      if ((await fetch(base, { headers })).status !== 404) return false;
      const deletion = await fetch(`${base}/drafts/current`, { method: 'DELETE', headers });
      if (![200, 204, 404].includes(deletion.status)) return false;
      if ((await fetch(`${base}/drafts/current`, { headers })).status !== 404) return false;
      if ((await auth('delete', { idToken: fixture.token })).status !== 200) return false;
      const absent = await auth('lookup', { idToken: fixture.token });
      return absent.status === 400 && absent.body.error?.message === 'USER_NOT_FOUND';
    },
    {
      fixture: { uid: fixture.uid, email: fixture.email, token: fixture.token },
      key,
      project,
      nativeProof: !!(
        nativeCleanup?.writerStopped &&
        (fixture === fixtures[0]
          ? nativeCleanup.ownerDraftAbsent && nativeCleanup.ownerAuthDeleted
          : nativeCleanup.foreignDraftAbsent && nativeCleanup.foreignAuthDeleted)
      ),
    },
  );
  assert.equal(result, true, 'Disposable identity cleanup verified');
}
(async () => {
  try {
    assert(
      fs.existsSync(path.join(mobile, 'integration_test/cross_client_live_runtime_test.dart')),
    );
    // Порты нельзя занимать поверх чужого процесса.
    for (const port of [3900, 3815]) {
      const probe = http.createServer();
      await new Promise((resolve, reject) => {
        probe.once('error', reject);
        probe.listen(port, '127.0.0.1', resolve);
      });
      await new Promise((resolve) => probe.close(resolve));
    }
    const next = launch(
      process.execPath,
      [path.join(web, 'node_modules/next/dist/bin/next'), 'start', '-H', '127.0.0.1', '-p', '3900'],
      web,
      'next.log',
    );
    await ready(next);
    browser = await chromium.launch({
      headless: true,
      ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
    });
    const context = await browser.newContext({
      viewport: { width: 1440, height: 1000 },
      reducedMotion: 'reduce',
    });
    const allowed = new Set([
      '127.0.0.1:3900',
      'identitytoolkit.googleapis.com',
      'securetoken.googleapis.com',
      'firestore.googleapis.com',
      `${project}.firebaseapp.com`,
      'www.googleapis.com',
    ]);
    await context.route('**/*', (route) =>
      allowed.has(new URL(route.request().url()).host) ? route.continue() : route.abort(),
    );
    page = await context.newPage();
    page.on('pageerror', (error) =>
      diagnostics.push({ type: 'pageerror', message: error.message }),
    );
    page.on('response', (response) => {
      if (response.status() >= 400)
        diagnostics.push({ status: response.status(), url: response.url().split('?')[0] });
    });
    page.setDefaultTimeout(45000);
    writeDefines();
    currentStage = 'register-owner';
    await register(fixtures[0]);
    await onboard(`Live web seed ${run}`, `Web initial ${run}`);
    await signOut();
    currentStage = 'register-foreign';
    await register(fixtures[1]);
    await onboard(`Foreign web ${run}`, `Foreign initial ${run}`);
    await signOut();
    await signIn(fixtures[0]);
    await editor(`Live web seed ${run}`, `Web initial ${run}`);
    mark('real-web-registration-onboarding-sign-in-and-server-restore');
    writeDefines();
    bridge = http.createServer(async (req, res) => {
      const expected = stages[stageIndex];
      if (req.method !== 'GET' || !expected || req.url !== `/${run}/${expected}`) {
        res.writeHead(404).end();
        return;
      }
      stageIndex++;
      try {
        await stage(expected);
        res.writeHead(200).end('ok');
      } catch (e) {
        fatal = e;
        res.writeHead(500).end('failed');
      }
    });
    await new Promise((resolve, reject) => {
      bridge.once('error', reject);
      bridge.listen(3815, '127.0.0.1', resolve);
    });
    currentStage = 'android-drive';
    const native = launch(
      process.env.FLUTTER_BIN || 'flutter',
      [
        'drive',
        '--no-uninstall-first',
        '--keep-app-running',
        '--no-dds',
        '--driver=test_driver/integration_test.dart',
        '--target=integration_test/cross_client_live_runtime_test.dart',
        '-d',
        device,
        `--dart-define-from-file=${defines}`,
      ],
      mobile,
      'android.log',
    );
    nativeProcess = native;
    const code = await new Promise((resolve, reject) => {
      const deadline = setTimeout(
        () => {
          native.kill('SIGTERM');
          reject(new Error('Native timeout'));
        },
        12 * 60 * 1000,
      );
      native.once('error', (e) => {
        clearTimeout(deadline);
        reject(e);
      });
      native.once('exit', (n) => {
        clearTimeout(deadline);
        resolve(n);
      });
    });
    if (fatal) throw fatal;
    assert.equal(code, 0, 'Native live harness');
    assert.equal(stageIndex, stages.length);
    mark('android-live-harness-completed');
  } catch (e) {
    report.failure = { stage: currentStage, type: e.name };
    fs.writeFileSync(path.join(dir, 'failure.log'), e.stack || String(e), { mode: 0o600 });
    if (page && !page.isClosed()) {
      fs.writeFileSync(
        path.join(dir, 'page.txt'),
        await page
          .locator('body')
          .innerText()
          .catch(() => ''),
        { mode: 0o600 },
      );
      fs.writeFileSync(
        path.join(dir, 'browser.json'),
        JSON.stringify({ url: page.url(), diagnostics }),
        { mode: 0o600 },
      );
    }
    process.exitCode = 1;
  } finally {
    try {
      if (nativeProcess) {
        if (nativeProcess.exitCode === null && nativeProcess.signalCode === null) {
          nativeProcess.kill('SIGTERM');
          await Promise.race([
            new Promise((resolve) => nativeProcess.once('exit', resolve)),
            delay(5000),
          ]);
          if (nativeProcess.exitCode === null && nativeProcess.signalCode === null)
            nativeProcess.kill('SIGKILL');
        }
        // drive --keep-app-running не останавливает SDK writer при аварии driver.
        const stop = spawn(
          adb,
          ['-s', device, 'shell', 'am', 'force-stop', 'dev.snownumb.stackcard'],
          { stdio: 'ignore' },
        );
        const stopped = await new Promise((resolve, reject) => {
          stop.once('error', reject);
          stop.once('exit', resolve);
        });
        assert.equal(stopped, 0, 'Test APK writer stopped before fallback cleanup');
        const markers = fs
          .readFileSync(path.join(dir, 'android.log'), 'utf8')
          .split('\n')
          .flatMap((line) => {
            const match = line.match(/STACKCARD_LIVE_SYNC:(\{.*\})/);
            if (!match) return [];
            try {
              return [JSON.parse(match[1])];
            } catch {
              return [];
            }
          });
        nativeCleanup = markers.find((marker) => marker.checkpoint === 'cleanup');
        report.native = markers;
      }
      if (fixtures.some((f) => f.uid)) {
        if (!page || page.isClosed()) throw new Error('Cleanup browser unavailable');
        await page.goto(origin);
        const cleaned = await Promise.allSettled(fixtures.map(cleanup));
        assert(
          cleaned.every((result) => result.status === 'fulfilled'),
          'Every disposable identity cleaned',
        );
      }
      report.cleanup = true;
      if (fs.existsSync(defines)) fs.unlinkSync(defines);
    } catch {
      report.cleanup = false;
      process.exitCode = 1;
    }
    if (nativeProcess) {
      try {
        const restore = launch(
          process.env.FLUTTER_BIN || 'flutter',
          ['build', 'apk', '--debug', '--target', 'lib/main.dart'],
          mobile,
          'restore.log',
        );
        const code = await new Promise((resolve, reject) => {
          const deadline = setTimeout(
            () => {
              restore.kill('SIGTERM');
              reject(new Error('Restore timeout'));
            },
            8 * 60 * 1000,
          );
          restore.once('error', (e) => {
            clearTimeout(deadline);
            reject(e);
          });
          restore.once('exit', (n) => {
            clearTimeout(deadline);
            resolve(n);
          });
        });
        assert.equal(code, 0, 'Ordinary main.dart debug build');
        const install = spawn(
          adb,
          [
            '-s',
            device,
            'install',
            '-r',
            path.join(mobile, 'build/app/outputs/flutter-apk/app-debug.apk'),
          ],
          { stdio: 'ignore' },
        );
        assert.equal(
          await new Promise((resolve, reject) => {
            install.once('error', reject);
            install.once('exit', resolve);
          }),
          0,
          'Ordinary APK restored without data clear',
        );
        report.ordinaryAppRestored = true;
      } catch {
        report.ordinaryAppRestored = false;
        process.exitCode = 1;
      }
    }
    if (bridge) await new Promise((resolve) => bridge.close(resolve));
    if (browser) await browser.close();
    for (const child of children) if (child.exitCode === null) child.kill('SIGTERM');
    fs.writeFileSync(path.join(dir, 'report.json'), JSON.stringify(report, null, 2), {
      mode: 0o600,
    });
    console.log(JSON.stringify({ ...report, diagnostics: dir }));
  }
})();
