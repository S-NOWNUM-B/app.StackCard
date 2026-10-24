import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_stackcard/core/storage/local_storage.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/data/asset_portfolio_pdf_generator.dart';
import 'package:app_stackcard/features/portfolio_draft/data/firestore_developer_card_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/http_document_publication_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/data/synced_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/developer_card_qr.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Два native процесса, только demo SDK apps и отдельный Hive/outbox.
/// Credentials сохраняет сам Auth SDK; ordinary session/storage не открываются.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_MAIN_PORTFOLIO_ACCEPTANCE');
  const phase = String.fromEnvironment('MAIN_PORTFOLIO_PHASE');
  const run = String.fromEnvironment('MAIN_PORTFOLIO_RUN_ID');
  const host = String.fromEnvironment(
    'MAIN_PORTFOLIO_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  final options = FirebaseOptions(
    // Синтетический ключ нужной формы: iOS Installations проверяет длину до Emulator API.
    apiKey: 'A00000000000000000000000000000000000000',
    appId: Platform.isIOS
        ? '1:123456789:ios:0123456789abcdef'
        : '1:123456789:android:0123456789abcdef',
    iosBundleId: Platform.isIOS ? 'com.example.appStackcard' : null,
    messagingSenderId: '123456789',
    projectId: 'demo-stackcard-test',
  );
  testWidgets(
    'main survives native process restart, SDK ACK, HTTP Publish and withdrawal',
    (tester) async {
      expect(run, matches(r'^[0-9a-f]{32}$'));
      expect(phase, anyOf('seed', 'check'));
      expect(host, anyOf('10.0.2.2', '127.0.0.1', 'localhost'));
      final app = await Firebase.initializeApp(
        name: 'main-journey-$run',
        options: options,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      await auth.useAuthEmulator(host, 9099);
      final db = FirebaseFirestore.instanceFor(app: app);
      db.useFirestoreEmulator(host, 8085);
      await db.disableNetwork();
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/main-journey-$run');
      final journal = File('${directory.path}/journey.json');
      LocalStorage? storage;
      SyncedPortfolioDraftRepository? repository;
      ProviderContainer? container;
      FirebaseApp? observerApp;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            if (response.statusCode != 200) {
              final data = response.data;
              final error = data is Map ? data['error'] : null;
              debugPrint(
                'STACKCARD_MAIN_HTTP_FAILURE:${response.statusCode}:${error is Map ? error['code'] : 'unknown'}',
              );
            }
            handler.next(response);
          },
        ),
      );
      final ownerPassword = _password();
      var retainSeed = false;
      String? ownedUid;
      final checkpoints = <String>[];
      void passed(String name) {
        checkpoints.add(name);
        // Только названия этапов и PID; credentials/UID/token не выводятся.
        debugPrint(
          'STACKCARD_MAIN_JOURNEY:${jsonEncode({'phase': phase, 'pid': pid, 'checkpoint': name})}',
        );
      }

      try {
        if (phase == 'seed') {
          expect(auth.currentUser, isNull);
          expect(await directory.exists(), isFalse);
          ownedUid = (await auth.createUserWithEmailAndPassword(
            email: 'main.$run@example.invalid',
            password: ownerPassword,
          )).user!.uid;
        } else {
          // Проверка session restore до любого sign-in.
          expect(auth.currentUser?.email, 'main.$run@example.invalid');
          ownedUid = auth.currentUser!.uid;
          expect(await journal.exists(), isTrue);
          // Новая memory-only credential для возврата после UID-switch;
          // прежнюю SDK session восстановили до этой операции.
          await auth.currentUser!.updatePassword(ownerPassword);
          // Password rotation отзывает прежний auth_time; новый login нужен
          // перед verifyIdToken(checkRevoked:true), restore проверен выше.
          await auth.signInWithEmailAndPassword(
            email: 'main.$run@example.invalid',
            password: ownerPassword,
          );
        }
        final uid = ownedUid;
        storage = await LocalStorage.open(directory: directory);
        final metadata = HivePortfolioSyncMetadataStore(
          storage.portfolioDraft,
          ownerUid: uid,
        );
        repository = SyncedPortfolioDraftRepository(
          ownerUid: uid,
          local: LocalDraftAccounts(storage.portfolioDraft)
              .repositoryForUser(uid),
          metadata: metadata,
          remote: FirestorePortfolioDraftRepository(firestore: db, uid: uid),
          isActive: () => auth.currentUser?.uid == uid,
        );
        final publicationApi = HttpDocumentPublicationRepository(
          dio: dio,
          endpoint: Uri.parse('http://$host:3810/documentPublication'),
          allowDemoHttp: true,
          ownerUid: uid,
          token: (expectedUid) async {
            final user = auth.currentUser;
            if (user?.uid != expectedUid) return null;
            final token = await user!.getIdToken(true);
            return auth.currentUser?.uid == expectedUid ? token : null;
          },
        );
        final cards = FirestoreDeveloperCardRepository(
          firestore: db,
          ownerUid: uid,
          isActive: () => auth.currentUser?.uid == uid,
        );
        container = ProviderContainer(
          overrides: [
            documentLinkActionsProvider.overrideWithValue(
              const NativeDocumentLinkActions(),
            ),
            accountAuthRepositoryProvider.overrideWithValue(
              FirebaseAccountAuthRepository(auth: auth),
            ),
            portfolioDraftRepositoryProvider.overrideWithValue(repository),
            documentPublicationRepositoryFactoryProvider.overrideWithValue(
              (owner) => owner == uid ? publicationApi : null,
            ),
            developerCardRepositoryFactoryProvider.overrideWithValue(
              (owner) => owner == uid ? cards : null,
            ),
          ],
        );
        // Как mounted consumer: держать session stream активным и обрабатывать frames.
        container.listen(accountSessionProvider, (_, _) {});
        await _pumpUntil(
          tester,
          () => container!.read(accountSessionProvider).hasValue,
        );
        expect(container.read(accountSessionProvider).value?.uid, uid);
        final controller = container.read(
          portfolioDraftControllerProvider.notifier,
        );
        await controller.load();
        if (phase == 'seed') {
          expect(
            await controller.initializeMainPortfolio(
              newAccount: true,
              expectedRepository: repository,
            ),
            isTrue,
          );
          for (var step = 0; step < 4; step++) {
            expect(
              await controller.savePersonalizationStep(
                step: step,
                status: step == 3
                    ? PortfolioPersonalizationStatus.completed
                    : PortfolioPersonalizationStatus.inProgress,
                profile: step == 1
                    ? const PortfolioProfile(name: 'Native saved author')
                    : null,
                expectedRepository: repository,
              ),
              isTrue,
            );
          }
          final initial = (await repository.read())!.content!;
          final main = mainPortfolioDocument(initial)!;
          controller.updateNotes('PRIVATE_UNSAVED_NOTES');
          controller.updateContent(
            initial.copyWith(
              documents: [
                main.copyWith(
                  content: main.content.copyWith(
                    profile: const PortfolioProfile(
                      name: 'PRIVATE_EDITOR_BUFFER',
                    ),
                  ),
                ),
              ],
            ),
          );
          expect(
            await controller.saveProject(
              PortfolioProject(
                id: 'manual',
                title: 'Native manual',
                description: '',
                technologies: const ['Flutter'],
                liveUrl: 'https://example.com/saved',
              ),
              expectedRepository: repository,
            ),
            isTrue,
          );
          expect(
            await controller.importSelectedGitHubRepositories([
              GitHubProjectSource(
                repositoryId: 42,
                name: 'Native import',
                fullName: 'owner/native',
                htmlUrl: 'https://github.com/owner/native',
                stars: 0,
                forks: 0,
                isFork: false,
                archived: false,
                language: 'TypeScript',
                updatedAt: DateTime.utc(2026, 10, 21),
              ),
            ], expectedRepository: repository),
            isTrue,
          );
          var saved = (await repository.read())!;
          expect(
            mainPortfolioDocument(saved.content!)!.content.profile.name,
            'Native saved author',
          );
          expect(saved.notes, isEmpty);
          expect(
            mainPortfolioDocument(
              container.read(portfolioDraftControllerProvider).content!,
            )!.content.profile.name,
            'PRIVATE_EDITOR_BUFFER',
          );
          expect(
            await controller.saveMainPortfolio(
              main.copyWith(
                projects: [
                  for (final project in saved.content!.projects)
                    PortfolioProjectAttachment(projectId: project.id),
                ],
              ),
              expectedDocument: mainPortfolioDocument(saved.content!),
              expectedRepository: repository,
            ),
            isTrue,
          );
          saved = (await repository.read())!;
          expect(saved.pendingSync, isTrue);
          expect(repository.syncState.confirmedMutationId, isNull);
          await storage.portfolioDraft.flush();
          await journal.writeAsString(
            jsonEncode({
              'pid': pid,
              'uid': uid,
              'mutation': (await metadata.read())!.mutationId,
            }),
            flush: true,
          );
          // SharedPreferences.apply Auth SDK завершается асинхронно, как в existing restore suite.
          await Future<void>.delayed(const Duration(seconds: 2));
          retainSeed = true;
          passed('registration_optional4steps_scoped_save_offline_outbox');
          return;
        }

        final previous = jsonDecode(await journal.readAsString()) as Map;
        expect(pid, isNot(previous['pid']));
        expect(uid, previous['uid']);
        final restored = (await repository.read())!;
        expect(restored.pendingSync, isTrue);
        expect(restored.content!.projects, hasLength(2));
        expect(
          restored.content!.personalization.status,
          PortfolioPersonalizationStatus.completed,
        );
        expect(
          mainPortfolioDocument(restored.content!)!.content.profile.name,
          'Native saved author',
        );
        expect((await metadata.read())!.mutationId, previous['mutation']);
        passed('new_process_auth_hive_exact_outbox_restore');
        await db.enableNetwork();
        await repository.retry();
        await _until(
          () => repository!.syncState.status == PortfolioSyncStatus.synced,
        );
        expect(repository.syncState.confirmedMutationId, previous['mutation']);
        final server = await db
            .doc('accounts/$uid/drafts/current')
            .get(const GetOptions(source: Source.server));
        expect(server.metadata.isFromCache, isFalse);
        expect(server.metadata.hasPendingWrites, isFalse);
        expect(server.data()!['updatedAt'], isA<Timestamp>());
        expect(server.data()!['schemaVersion'], 7);
        expect((await repository.read())!.pendingSync, isFalse);
        passed('reconnect_actual_sdk_server_ack_cloud7');

        final durable = resolvedMainPortfolioContent(
          (await repository.read())!.content!,
        )!;
        final pdf = await AssetPortfolioPdfGenerator().generate(durable);
        expect(isPortfolioPdfBytes(pdf), isTrue);
        expect(latin1.decode(pdf), contains('https://example.com/saved'));
        passed('saved_basis_actual_pdf');
        final inventory = await publicationApi.inventory();
        final published = await publicationApi.mutate(
          DocumentPublicationMutation(
            action: DocumentPublicationAction.publish,
            operationId: _randomHex(16),
            documentId: restored.content!.mainPortfolioId!,
            expectedMutationId: repository.syncState.confirmedMutationId!,
            expectedVersion: 0,
            expectedGeneration: inventory.lifecycleGeneration,
          ),
        );
        expect(published.outcome, DocumentPublicationOutcome.completed);
        final publication = published.publication!;
        observerApp = await Firebase.initializeApp(
          name: 'main-observer-$run',
          options: options,
        );
        final anonymous = FirebaseFirestore.instanceFor(app: observerApp);
        anonymous.settings = const Settings(persistenceEnabled: false);
        anonymous.useFirestoreEmulator(host, 8085);
        final publicRef = anonymous.doc(
          'publicDocuments/${publication.publicId}',
        );
        final publicBefore = await publicRef.get(
          const GetOptions(source: Source.server),
        );
        expect(publicBefore.data()!['publishedAt'], isA<Timestamp>());
        final card = await _card(cards, publication);
        expect(card.name, 'Native saved author');
        expect(card.technologies, ['Flutter', 'TypeScript']);
        passed('authenticated_http_publish_anonymous_sdk_timestamp_card');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: StackCardTheme.light,
              home: DeveloperCardScreen(documentId: publication.documentId),
            ),
          ),
        );
        await _pumpUntil(
          tester,
          () => find.byType(DeveloperCardQr).evaluate().isNotEmpty,
        );
        expect(
          tester.widget<DeveloperCardQr>(find.byType(DeveloperCardQr)).url,
          publication.url,
        );
        if (const bool.fromEnvironment('RUN_NATIVE_SYSTEM_ACTIONS')) {
          // Host coordinator проверяет screenshot/системный UI и затем отвечает.
          await tester.scrollUntilVisible(
            find.byType(DeveloperCardQr),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await _systemStage('card', publication.url!);
          for (final action in ['share', 'open']) {
            final control = find.byKey(ValueKey('developerCard.$action'));
            await tester.scrollUntilVisible(
              control,
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            await tester.tap(control);
            await tester.pump(const Duration(seconds: 2));
            await _systemStage(action, publication.url!);
            await tester.pumpAndSettle();
          }
        }
        // Настоящий Android clipboard bridge, без открытия Share и отправки.
        final copy = find.byKey(const ValueKey('developerCard.copy'));
        await tester.scrollUntilVisible(
          copy,
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(copy);
        await _pumpUntil(
          tester,
          () =>
              find.text('Ссылка скопирована.').evaluate().isNotEmpty ||
              find
                  .text(
                    'Действие недоступно. Проверьте публикацию и повторите.',
                  )
                  .evaluate()
                  .isNotEmpty,
        );
        expect(
          find.text('Ссылка скопирована.'),
          findsOneWidget,
          reason:
              'Card copy must succeed after inventory revalidation; failure=${container.read(documentPublicationControllerProvider).failure?.kind.name}',
        );
        expect(
          (await Clipboard.getData('text/plain'))?.text,
          publication.url.toString(),
        );
        passed('native_card_render_qr_copy_bridge');
        final publications = container.read(
          documentPublicationControllerProvider.notifier,
        );

        final saved = (await repository.read())!;
        await repository.save(
          saved.content!,
          expectedRevision: saved.revision,
          notes: 'PRIVATE_SAVED_NOTE',
        );
        await _until(
          () => repository!.syncState.status == PortfolioSyncStatus.synced,
        );
        expect(
          (await publicRef.get(const GetOptions(source: Source.server))).data(),
          publicBefore.data(),
        );
        passed('private_save_does_not_republish');
        await auth.signOut();
        await auth.createUserWithEmailAndPassword(
          email: 'foreign.$run@example.invalid',
          password: _password(),
        );
        await _pumpUntil(tester, () {
          final session = container!.read(accountSessionProvider);
          return !session.isLoading &&
              session.value?.uid != uid &&
              find.byType(DeveloperCardQr).evaluate().isEmpty;
        });
        expect(find.byKey(const ValueKey('developerCard.copy')), findsNothing);
        await expectLater(
          db
              .doc('accounts/$uid/drafts/current')
              .get(const GetOptions(source: Source.server)),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
        await auth.currentUser!.delete();
        await auth.signInWithEmailAndPassword(
          email: 'main.$run@example.invalid',
          password: ownerPassword,
        );
        await _pumpUntil(
          tester,
          () => container!.read(accountSessionProvider).value?.uid == uid,
        );
        await repository.retry();
        await _until(
          () => repository!.syncState.status == PortfolioSyncStatus.synced,
        );
        await publications.load();
        await _pumpUntil(
          tester,
          () => find.byType(DeveloperCardQr).evaluate().isNotEmpty,
        );
        passed('native_uid_switch_hides_card_and_denies_previous_owner');
        await expectLater(
          anonymous
              .doc('accounts/$uid/drafts/current')
              .get(const GetOptions(source: Source.server)),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
        expect(
          await LocalDraftAccounts(storage.portfolioDraft)
              .repositoryForUser('other-owner')
              .read(),
          isNull,
        );
        passed('anonymous_private_denial_uid_local_isolation');

        expect(
          await publications.perform(
            action: DocumentPublicationAction.unpublish,
            documentId: publication.documentId,
          ),
          isTrue,
        );
        await _pumpUntil(
          tester,
          () => find.byType(DeveloperCardQr).evaluate().isEmpty,
        );
        expect(
          (await publicRef.get(const GetOptions(source: Source.server))).exists,
          isFalse,
        );
        passed('http_unpublish_removes_public_snapshot_and_open_qr');
        expect(
          await publications.perform(
            action: DocumentPublicationAction.deleteDocument,
            documentId: publication.documentId,
          ),
          isTrue,
        );
        expect(
          mainPortfolioDocument((await repository.read())!.content!),
          isNull,
        );
        expect(tester.takeException(), isNull);
        passed('trusted_delete_reconciles_saved_workspace');
        await tester.pumpWidget(const SizedBox.shrink());
        await anonymous.terminate();
      } finally {
        container?.dispose();
        await repository?.dispose();
        await storage?.close();
        dio.close(force: true);
        if (!retainSeed) {
          await db.enableNetwork();
          if (ownedUid != null && auth.currentUser?.uid == ownedUid) {
            // После trusted Publish direct draft delete закрыт Rules.
            // Disposable Firestore данные исчезают с demo emulator session.
            await auth.currentUser!.delete();
          }
          await db.terminate();
          await observerApp?.delete();
          await app.delete();
          if (ownedUid != null && await directory.exists()) {
            await directory.delete(recursive: true);
          }
        }
      }
    },
    skip: !enabled || !(Platform.isAndroid || Platform.isIOS),
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<void> _systemStage(String stage, Uri url) async {
  final client = HttpClient();
  try {
    final endpoint = Uri.http('10.0.2.2:3811', '/$stage', {'url': '$url'});
    final response = await (await client.getUrl(endpoint))
        .close()
        .timeout(const Duration(seconds: 90));
    expect(response.statusCode, 200);
    expect(await response.transform(utf8.decoder).join(), 'PASS');
  } finally {
    client.close(force: true);
  }
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Native SDK state deadline');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

String _password() => 'Aa!${_randomHex(24)}';

String _randomHex(int bytes) {
  final random = Random.secure();
  return List.generate(
    bytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

Future<DeveloperCard> _card(
  DeveloperCardRepository repository,
  DocumentPublication publication,
) async {
  final result = Completer<DeveloperCard>();
  final subscription = repository
      .watch(publication)
      .listen(
        (card) {
          if (!result.isCompleted) result.complete(card);
        },
        onError: (Object error) {
          // Firestore сначала отдаёт cache event; Card обязан его отвергнуть.
          if (error is! DeveloperCardFailure ||
              error.kind != DeveloperCardFailureKind.unavailable) {
            if (!result.isCompleted) result.completeError(error);
          }
        },
      );
  try {
    return await result.future.timeout(const Duration(seconds: 30));
  } finally {
    await subscription.cancel();
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Native UI state deadline');
    await tester.pump(const Duration(milliseconds: 100));
  }
}
