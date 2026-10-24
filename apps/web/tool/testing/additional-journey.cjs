// Дополнительные сценарии на isolated demo stack, без обычных аккаунтов и live почты.
const assert = require('node:assert/strict');
const fs = require('node:fs');

module.exports = async function additionalJourney({
  page,
  browser,
  context,
  localOnly,
  errors,
  blockedHosts,
  origin,
  api,
  output,
  backend,
}) {
  const { initializeApp, deleteApp } = require(
    require.resolve('firebase-admin/app', { paths: [backend] }),
  );
  const { getFirestore, FieldValue } = require(
    require.resolve('firebase-admin/firestore', { paths: [backend] }),
  );
  const { getAuth } = require(require.resolve('firebase-admin/auth', { paths: [backend] }));
  const { getStorage } = require(require.resolve('firebase-admin/storage', { paths: [backend] }));
  assert.equal(process.env.FIREBASE_STORAGE_EMULATOR_HOST, '127.0.0.1:9199');
  const admin = initializeApp(
    { projectId: 'demo-stackcard-test', storageBucket: 'demo-stackcard-test.appspot.com' },
    `web-additional-${Date.now()}`,
  );
  const database = getFirestore(admin);
  const auth = getAuth(admin),
    bucket = getStorage(admin).bucket();
  const passed = [];
  const email = `additional-${Date.now()}@example.test`;
  const originalPassword = 'Testing#7392Brick';
  const nextPassword = 'Updated#8651Stone';
  let ownerUid,
    ownerToken,
    createdPublicId,
    createdMalformed = false;
  page.on('response', async (response) => {
    if (response.url().includes('accounts:signUp') && response.ok()) {
      const signedIn = await response.json();
      ownerUid = signedIn.localId;
      ownerToken = signedIn.idToken;
    }
  });
  try {
    await page.goto(`${origin}/sign-up`);
    await page.getByRole('textbox', { name: 'Почта', exact: true }).fill(email);
    await page.getByLabel('Пароль', { exact: true }).fill(originalPassword);
    await page.getByLabel('Подтверждение пароля', { exact: true }).fill(originalPassword);
    await page.getByRole('button', { name: 'Создать аккаунт', exact: true }).click();
    for (let step = 1; step <= 4; step++) {
      await page.getByText(`Шаг ${step} из 4`, { exact: true }).waitFor();
      if (step === 2)
        await page.getByRole('textbox', { name: 'Имя', exact: true }).fill('Additional author');
      await page
        .getByRole('button', { name: step === 4 ? 'Завершить' : 'Далее', exact: true })
        .click();
    }
    await page.getByRole('heading', { name: 'Additional author', exact: true }).waitFor();
    assert(ownerUid);
    const draftRef = database.doc(`accounts/${ownerUid}/drafts/current`);
    const original = (await draftRef.get()).data();
    const main = original.content.documents.find(
      (document) => document.id === original.content.mainPortfolioId,
    );
    main.content.links = [
      {
        id: 'contact-email',
        label: 'Почта автора',
        url: 'mailto:author@example.test',
        kind: 'email',
        publishAllowed: true,
        visible: true,
      },
    ];
    main.content.profile.bio = 'PRIVATE_BIO_SENTINEL';
    main.content.profile.locationText = 'PRIVATE_CITY_SENTINEL';
    main.content.profile.publishLocation = false;
    main.content.blocks = main.content.blocks.map((block) =>
      ['about', 'location'].includes(block.kind) ? { ...block, visible: false } : block,
    );
    original.notes = 'PRIVATE_NOTES_SENTINEL';
    original.mutationId = `additional-fixture-${Date.now()}`;
    original.localRevision++;
    original.updatedAt = FieldValue.serverTimestamp();
    await draftRef.set(original);
    const inventoryReady = page.waitForResponse(
      (response) =>
        response.url() === api &&
        response.request().method() === 'POST' &&
        response.request().postDataJSON().action === 'inventory' &&
        response.status() === 200,
    );
    await page.reload();
    await (await inventoryReady).finished();
    await page.getByRole('button', { name: 'Поделиться', exact: true }).click();
    await page.getByRole('dialog', { name: 'Опубликовать портфолио?', exact: true }).waitFor();
    const publication = page.waitForResponse(
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
    const publicationResult = await (await publication).json();
    const published = publicationResult.publication;
    createdPublicId = published.publicId;
    const anonymous = await browser.newContext({ viewport: { width: 390, height: 844 } });
    await anonymous.route('**/*', localOnly);
    const publicPage = await anonymous.newPage();
    publicPage.on('pageerror', (error) => errors.push(error.message));
    await publicPage.goto(published.url);
    await publicPage.getByRole('heading', { name: 'Additional author', exact: true }).waitFor();
    const publicHtml = await publicPage.content();
    for (const privateValue of [
      ownerUid,
      'PRIVATE_BIO_SENTINEL',
      'PRIVATE_CITY_SENTINEL',
      'PRIVATE_NOTES_SENTINEL',
    ])
      assert(!publicHtml.includes(privateValue), privateValue);
    await publicPage.getByRole('heading', { name: 'Связаться с автором', exact: true }).waitFor();
    passed.push(
      'anonymous SSR projects only approved contact; hidden bio/city/private notes/owner UID absent from HTML',
    );
    const contactApi = api.replace('documentPublication', 'contactInbox');
    const submissions = [];
    let loseAck = true;
    await anonymous.route(contactApi, async (route) => {
      if (route.request().method() !== 'POST') return route.continue();
      submissions.push(route.request().postDataJSON());
      if (loseAck) {
        loseAck = false;
        const response = await route.fetch();
        assert.equal(response.status(), 200);
        assert.deepEqual(Object.keys(await response.json()).sort(), ['requestId', 'status']);
        await route.abort('failed');
      } else await route.continue();
    });
    await publicPage
      .getByRole('textbox', { name: 'Ваше имя', exact: true })
      .fill('Additional reader');
    await publicPage
      .getByRole('textbox', { name: 'Ваша почта', exact: true })
      .fill('reader@example.test');
    await publicPage
      .getByRole('textbox', { name: 'Сообщение', exact: true })
      .fill('Captured contact message');
    await publicPage.getByRole('button', { name: 'Отправить обращение', exact: true }).click();
    await publicPage
      .getByText('Результат отправки неизвестен. Повторите отправку с этой страницы.', {
        exact: true,
      })
      .waitFor();
    await publicPage
      .getByRole('textbox', { name: 'Сообщение', exact: true })
      .fill('Newer unsent contact input');
    await publicPage.getByRole('button', { name: 'Повторить отправку', exact: true }).click();
    await publicPage
      .getByText('Обращение доставлено во входящие автора. Более поздний текст остался в форме.', {
        exact: true,
      })
      .waitFor();
    assert.equal(
      await publicPage.getByRole('textbox', { name: 'Сообщение', exact: true }).inputValue(),
      'Newer unsent contact input',
    );
    assert.equal(submissions.length, 2);
    assert.deepEqual(submissions[0], submissions[1]);
    const requests = await database.collection(`accounts/${ownerUid}/contactRequests`).get();
    assert.equal(requests.size, 1);
    assert.equal(requests.docs[0].data().message, 'Captured contact message');
    passed.push(
      'actual Contact POST commits before lost ACK; retry preserves requestId/payload, creates one Inbox record and retains newer input',
    );
    await page.getByRole('button', { name: 'Настройки', exact: true }).click();
    await page.getByRole('button', { name: 'Входящие', exact: true }).click();
    await page.getByText('Additional reader · Новое', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Открыть обращение', exact: true }).click();
    await page.getByText('Captured contact message', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Отметить прочитанным', exact: true }).click();
    await page.getByText(/^Прочитано /).waitFor();
    assert((await requests.docs[0].ref.get()).data().readAt);
    assert.equal((await draftRef.get()).data().mutationId, original.mutationId);
    assert.equal((await draftRef.get()).data().notes, 'PRIVATE_NOTES_SENTINEL');
    await page.screenshot({ path: `${output}.inbox.png` });
    passed.push('owner Inbox loads saved request and marks read without modifying private draft');
    const withdrawal = await fetch(api, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        origin,
        authorization: `Bearer ${ownerToken}`,
      },
      body: JSON.stringify({
        action: 'unpublish',
        documentId: published.documentId,
        operationId: `additional-withdraw-${Date.now()}`,
        expectedVersion: published.version,
        expectedGeneration: publicationResult.lifecycleGeneration,
      }),
    });
    assert.equal(withdrawal.status, 200);
    await publicPage.getByRole('button', { name: 'Отправить обращение', exact: true }).click();
    await publicPage
      .getByText('Документ больше не принимает обращения.', { exact: true })
      .waitFor();
    assert.equal(
      await publicPage.getByRole('textbox', { name: 'Сообщение', exact: true }).inputValue(),
      'Newer unsent contact input',
    );
    assert.equal((await database.collection(`accounts/${ownerUid}/contactRequests`).get()).size, 1);
    passed.push(
      'already-open Contact form refuses a withdrawn publication and preserves unsent input without creating another Inbox request',
    );
    const unknownId = 'e'.repeat(32);
    const missing = await publicPage.goto(`${origin}/d/${unknownId}`);
    assert.equal(missing.status(), 404);
    const robots = await publicPage
      .locator('meta[name="robots"]')
      .evaluateAll((elements) => elements.map((element) => element.getAttribute('content')));
    assert(robots.length > 0 && robots.every((value) => value.includes('noindex')));
    const malformedId = 'f'.repeat(32);
    assert.equal((await database.doc(`publicDocuments/${malformedId}`).get()).exists, false);
    await database
      .doc(`publicDocuments/${malformedId}`)
      .set({ schemaVersion: 999, private: 'PRIVATE_MALFORMED_SENTINEL' });
    createdMalformed = true;
    const malformed = await publicPage.goto(`${origin}/d/${malformedId}`);
    assert.equal(malformed.status(), 404);
    assert(!(await publicPage.content()).includes('PRIVATE_MALFORMED_SENTINEL'));
    passed.push(
      'missing and malformed public snapshots return404/noindex without exposing rejected fields',
    );
    await page.getByRole('button', { name: 'К входящим', exact: true }).click();
    await page.getByRole('button', { name: 'К настройкам', exact: true }).click();
    await page.getByRole('button', { name: 'Выйти', exact: true }).click();
    await page.waitForURL('**/sign-in?**');
    const returnTo = '/workspace#inbox';
    await page.goto(`${origin}/reset-password?returnTo=${encodeURIComponent(returnTo)}`);
    await page.getByRole('textbox', { name: 'Почта', exact: true }).fill(email);
    await page.getByRole('button', { name: 'Отправить письмо', exact: true }).click();
    await page.getByRole('heading', { name: 'Проверьте почту', exact: true }).waitFor();
    assert.equal(
      await page
        .getByRole('link', { name: 'Вернуться ко входу', exact: true })
        .getAttribute('href'),
      `/sign-in?returnTo=${encodeURIComponent(returnTo)}`,
    );
    const oob = await (
      await fetch('http://127.0.0.1:9099/emulator/v1/projects/demo-stackcard-test/oobCodes')
    ).json();
    const code = oob.oobCodes.find(
      (item) => item.email === email && item.requestType === 'PASSWORD_RESET',
    ).oobCode;
    const resetEndpoint =
      'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:resetPassword?key=demo-key';
    const reset = await fetch(resetEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ oobCode: code, newPassword: nextPassword }),
    });
    assert.equal(reset.status, 200);
    const replay = await fetch(resetEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ oobCode: code, newPassword: nextPassword }),
    });
    assert.equal(replay.status, 400);
    await page.getByRole('link', { name: 'Вернуться ко входу', exact: true }).click();
    await page.getByRole('textbox', { name: 'Почта', exact: true }).fill(email);
    await page.getByLabel('Пароль', { exact: true }).fill(originalPassword);
    await page.getByRole('button', { name: 'Войти', exact: true }).click();
    await page
      .getByText('Не удалось выполнить действие. Проверьте данные и повторите попытку.', {
        exact: true,
      })
      .waitFor();
    assert.equal(
      await page.getByRole('textbox', { name: 'Почта', exact: true }).inputValue(),
      email,
    );
    await page.getByLabel('Пароль', { exact: true }).fill(nextPassword);
    await page.getByRole('button', { name: 'Войти', exact: true }).click();
    await page.getByRole('heading', { name: 'Входящие', exact: true }).waitFor();
    await page.getByText('Additional reader', { exact: true }).waitFor();
    passed.push(
      'browser password reset requests actual emulator OOB; code redeems once, old password fails, new password restores Inbox returnTo and saved data',
    );
    await page.getByRole('button', { name: 'К настройкам', exact: true }).click();
    await page.getByRole('button', { name: 'Выйти', exact: true }).click();
    await page.waitForURL('**/sign-in?**');
    await page.goto(`${origin}/reset-password?returnTo=${encodeURIComponent(returnTo)}`);
    await page
      .getByRole('textbox', { name: 'Почта', exact: true })
      .fill(`unknown-${Date.now()}@example.test`);
    await page.getByRole('button', { name: 'Отправить письмо', exact: true }).click();
    await page.getByRole('heading', { name: 'Проверьте почту', exact: true }).waitFor();
    await page.screenshot({ path: `${output}.reset.png` });
    passed.push(
      'unknown reset email uses the same accepted UI without disclosing account existence',
    );
    await page.getByRole('link', { name: 'Вернуться ко входу', exact: true }).click();
    await page.getByRole('textbox', { name: 'Почта', exact: true }).fill(email);
    await page.getByLabel('Пароль', { exact: true }).fill(nextPassword);
    await page.getByRole('button', { name: 'Войти', exact: true }).click();
    await page.getByRole('heading', { name: 'Входящие', exact: true }).waitFor();
    await page.getByRole('button', { name: 'К настройкам', exact: true }).click();
    await page.getByText('Изменить пароль', { exact: true }).click();
    const changedPassword = 'Changed#9127Granite';
    const currentPassword = page.getByLabel(/^Текущий пароль для подтверждения действий/);
    const newPassword = page.getByLabel('Новый пароль', { exact: true });
    const passwordForm = page.locator('form').filter({ has: newPassword });
    await currentPassword.fill('Incorrect#4821Password');
    await newPassword.fill(changedPassword);
    await page.getByLabel('Подтверждение нового пароля', { exact: true }).fill(changedPassword);
    await passwordForm.getByRole('button', { name: 'Сохранить', exact: true }).click();
    await page
      .getByText('Не удалось подтвердить вход. Проверьте текущий пароль.', { exact: true })
      .waitFor();
    const passwordSignIn =
      'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key';
    const rejectedChange = await fetch(passwordSignIn, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: changedPassword, returnSecureToken: true }),
    });
    assert.equal(rejectedChange.status, 400);
    await currentPassword.fill(nextPassword);
    await newPassword.fill(changedPassword);
    await page.getByLabel('Подтверждение нового пароля', { exact: true }).fill(changedPassword);
    await passwordForm.getByRole('button', { name: 'Сохранить', exact: true }).click();
    await page.getByText('Пароль изменён.', { exact: true }).waitFor();
    assert.equal(await currentPassword.inputValue(), '');
    assert.equal(await newPassword.inputValue(), '');
    assert.equal((await auth.getUser(ownerUid)).uid, ownerUid);
    await page.getByRole('button', { name: 'Выйти', exact: true }).click();
    await page.waitForURL('**/sign-in?**');
    await page.getByRole('textbox', { name: 'Почта', exact: true }).fill(email);
    await page.getByLabel('Пароль', { exact: true }).fill(nextPassword);
    await page.getByRole('button', { name: 'Войти', exact: true }).click();
    await page
      .getByText('Не удалось выполнить действие. Проверьте данные и повторите попытку.', {
        exact: true,
      })
      .waitFor();
    await page.getByLabel('Пароль', { exact: true }).fill(changedPassword);
    await page.getByRole('button', { name: 'Войти', exact: true }).click();
    await page.getByRole('heading', { name: 'Аккаунт и безопасность', exact: true }).waitFor();
    passed.push(
      'AccountSettings wrong reauthentication cannot change password; correct reauthentication updates it, clears password inputs and supports only new credentials with unchanged UID',
    );
    const changedEmail = `updated-${Date.now()}@example.test`;
    await page.getByText('Изменить почту для входа', { exact: true }).click();
    await currentPassword.fill(changedPassword);
    await page.getByLabel('Новая почта для входа', { exact: true }).fill(changedEmail);
    await page.getByRole('button', { name: 'Отправить подтверждение', exact: true }).click();
    await page
      .getByText(
        'Письмо отправлено на новый адрес. Почта для входа изменится после подтверждения.',
        { exact: true },
      )
      .waitFor();
    assert.equal((await auth.getUser(ownerUid)).email, email);
    const emailCodes = (
      await (
        await fetch('http://127.0.0.1:9099/emulator/v1/projects/demo-stackcard-test/oobCodes')
      ).json()
    ).oobCodes;
    const emailCode = emailCodes.find(
      (item) =>
        item.requestType === 'VERIFY_AND_CHANGE_EMAIL' &&
        (item.email === changedEmail || item.newEmail === changedEmail),
    );
    assert(emailCode);
    const applyEndpoint =
      'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:update?key=demo-key';
    const applyEmail = await fetch(applyEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ oobCode: emailCode.oobCode }),
    });
    assert.equal(applyEmail.status, 200);
    const updatedOwner = await auth.getUser(ownerUid);
    assert.equal(updatedOwner.email, changedEmail);
    assert.equal(updatedOwner.uid, ownerUid);
    await page.getByRole('button', { name: 'Обновить статус', exact: true }).click();
    await page.getByText(changedEmail, { exact: true }).first().waitFor();
    await page.getByRole('button', { name: 'Выйти', exact: true }).click();
    await page.waitForURL('**/sign-in?**');
    await page.getByRole('textbox', { name: 'Почта', exact: true }).fill(email);
    await page.getByLabel('Пароль', { exact: true }).fill(changedPassword);
    await page.getByRole('button', { name: 'Войти', exact: true }).click();
    await page
      .getByText('Не удалось выполнить действие. Проверьте данные и повторите попытку.', {
        exact: true,
      })
      .waitFor();
    await page.getByRole('textbox', { name: 'Почта', exact: true }).fill(changedEmail);
    const changedLogin = page.waitForResponse(
      (response) => response.url().includes('accounts:signInWithPassword') && response.ok(),
    );
    await page.getByRole('button', { name: 'Войти', exact: true }).click();
    assert.equal((await (await changedLogin).json()).localId, ownerUid);
    await page.getByRole('heading', { name: 'Аккаунт и безопасность', exact: true }).waitFor();
    assert.equal((await draftRef.get()).data().notes, 'PRIVATE_NOTES_SENTINEL');
    await page.screenshot({ path: `${output}.account.png` });
    passed.push(
      'verifyBeforeUpdateEmail leaves old email active until actual OOB redeem; only new email signs in afterward with the same UID and saved private workspace',
    );
    const orphan = bucket.file(`accounts/${ownerUid}/acceptance-orphan.txt`);
    await orphan.save('Synthetic acceptance cleanup fixture');
    assert.equal((await orphan.exists())[0], true);
    let deletionRequest, recoveryRequest;
    let deletionCommitted;
    const committed = new Promise((resolve) => {
      deletionCommitted = resolve;
    });
    await page.route(api, async (route) => {
      if (route.request().method() !== 'POST') return route.continue();
      const body = route.request().postDataJSON();
      if (body.action === 'deleteAccount') {
        assert.equal(deletionRequest, undefined);
        deletionRequest = body;
        const journal = await page.evaluate(
          (uid) =>
            JSON.parse(localStorage.getItem('stackcard.delete-account.' + encodeURIComponent(uid))),
          ownerUid,
        );
        assert.equal(journal.operationId, body.operationId);
        assert.equal(journal.recoveryKey, body.recoveryKey);
        const response = await route.fetch();
        assert.equal(response.status(), 200);
        assert.equal((await response.json()).status, 'completed');
        await assert.rejects(
          () => auth.getUser(ownerUid),
          (error) => error.code === 'auth/user-not-found',
        );
        deletionCommitted();
        return route.abort('failed');
      }
      if (body.action === 'deletionStatus') {
        recoveryRequest = body;
        assert.equal(route.request().headers().authorization, undefined);
      }
      return route.continue();
    });
    await currentPassword.fill(changedPassword);
    await page.getByLabel('Введите УДАЛИТЬ для подтверждения', { exact: true }).fill('УДАЛИТЬ');
    await page.getByRole('button', { name: 'Удалить аккаунт', exact: true }).click();
    let deadline;
    try {
      await Promise.race([
        committed,
        new Promise((_, reject) => {
          deadline = setTimeout(
            () => reject(new Error('DeleteAccount did not commit within15seconds')),
            15000,
          );
        }),
      ]);
    } finally {
      clearTimeout(deadline);
    }
    await page
      .getByText(
        'Не удалось выполнить действие. Проверьте подключение и настройки сервиса, затем повторите.',
        { exact: true },
      )
      .waitFor();
    await page.reload();
    await page.goto(`${origin}/account-deletion`);
    await page.getByRole('button', { name: 'Проверить статус', exact: true }).click();
    await page
      .getByText('Сервис подтвердил удаление аккаунта и снятие документов с публикации.', {
        exact: true,
      })
      .waitFor();
    assert.equal(recoveryRequest.operationId, deletionRequest.operationId);
    assert.equal(recoveryRequest.recoveryKey, deletionRequest.recoveryKey);
    assert.equal(recoveryRequest.ownerUid, ownerUid);
    assert.equal((await draftRef.get()).exists, false);
    assert.equal((await orphan.exists())[0], false);
    assert.equal((await database.collection(`accounts/${ownerUid}/contactRequests`).get()).size, 0);
    assert.equal(
      await page.evaluate(
        (uid) => localStorage.getItem('stackcard.delete-account.' + encodeURIComponent(uid)),
        ownerUid,
      ),
      null,
    );
    await page.reload();
    await page
      .getByText('В этом браузере нет сохранённого запроса удаления.', { exact: true })
      .waitFor();
    await page.screenshot({ path: `${output}.deletion.png` });
    passed.push(
      'AccountSettings deletion persists receipt before real HTTP; Auth identity, draft, Inbox and Storage orphan are deleted before deliberately lost ACK; reload recovers the same unsigned deletionStatus and clears the journal',
    );
    assert.deepEqual(blockedHosts, []);
    assert.deepEqual(errors, []);
    fs.writeFileSync(
      output,
      JSON.stringify(
        {
          environment:
            'Next production + Chrome + demo Auth/Firestore + actual Node Contact/Publication; disposable fixtures only',
          browser: await browser.version(),
          passed,
          boundaries: {
            account:
              'Actual AccountSettings SDK reauthentication/password/email mutation; emulator OOB redeemed through official REST. Actual Auth/Firestore/Storage deletion and restricted recovery; only final HTTP ACK intentionally dropped.',
            reset:
              'Browser requests actual SDK reset email; emulator OOB inspected and redeemed through official Auth REST; no real mailbox/hosted action page.',
            contact:
              'Actual backend and Inbox; only first HTTP ACK intentionally dropped; App Check bypass restricted to demo emulator.',
            public:
              'Anonymous actual SSR and privacy projection; malformed snapshot seeded by demo Admin SDK.',
          },
          limitations:
            'No live Google OAuth, real email delivery, production App Check/hosting, native sharing/QR or physical device acceptance.',
        },
        null,
        2,
      ),
    );
    console.log(`Additional browser journey PASS: ${passed.length} checkpoints`);
  } finally {
    try {
      if (ownerUid) {
        await auth.deleteUser(ownerUid).catch((error) => {
          if (error.code !== 'auth/user-not-found') throw error;
        });
        await database.recursiveDelete(database.doc(`accounts/${ownerUid}`));
        await bucket.deleteFiles({ prefix: `accounts/${ownerUid}/`, force: true });
      }
      if (createdPublicId) {
        await database.doc(`publicDocuments/${createdPublicId}`).delete();
        await bucket.deleteFiles({ prefix: `publicMedia/${createdPublicId}/`, force: true });
      }
      if (createdMalformed) await database.doc('publicDocuments/' + 'f'.repeat(32)).delete();
    } finally {
      await deleteApp(admin);
    }
  }
};
