import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_stackcard/app/local_runtime.dart';
import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/core/state/settings_repository.dart';
import 'package:app_stackcard/core/storage/local_storage.dart';
import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/data/synced_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:app_stackcard/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Opt-in dev acceptance with isolated SDK sessions and local storage.
/// Run with --no-uninstall; existing app data and user sessions are untouched.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_FIRESTORE_SYNC_ACCEPTANCE');
  const restorePhase = String.fromEnvironment('FIRESTORE_RESTORE_PHASE');

  testWidgets(
    'native Firestore GitHub draft sync, server LWW and private access',
    (tester) async {
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options.projectId, 'stackcard-dev-snownumb');
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final ownerEmail = 'phase8.owner.$stamp@example.invalid';
      final foreignEmail = 'phase8.foreign.$stamp@example.invalid';
      final password = _randomPassword();
      final directory = await Directory.systemTemp.createTemp(
        'stackcard-phase8-',
      );
      FirebaseApp? ownerApp;
      FirebaseApp? observerApp;
      FirebaseAuth? ownerAuth;
      FirebaseAuth? observerAuth;
      FirebaseFirestore? ownerFirestore;
      FirebaseFirestore? observerFirestore;
      LocalStorage? storage;
      SyncedPortfolioDraftRepository? repository;
      String? ownerUid;
      String? foreignUid;

      try {
        // Unique named apps avoid signing out or replacing the default session.
        ownerApp = await Firebase.initializeApp(
          name: 'phase8-owner-$stamp',
          options: options,
        );
        observerApp = await Firebase.initializeApp(
          name: 'phase8-observer-$stamp',
          options: options,
        );
        ownerAuth = FirebaseAuth.instanceFor(app: ownerApp);
        observerAuth = FirebaseAuth.instanceFor(app: observerApp);
        expect(ownerAuth.currentUser, isNull);
        expect(observerAuth.currentUser, isNull);
        final credential = await ownerAuth
            .createUserWithEmailAndPassword(
              email: ownerEmail,
              password: password,
            )
            .timeout(_networkTimeout);
        ownerUid = credential.user!.uid;
        ownerFirestore = FirebaseFirestore.instanceFor(app: ownerApp);
        observerFirestore = FirebaseFirestore.instanceFor(app: observerApp);
        observerFirestore.settings = const Settings(persistenceEnabled: false);
        final ownerDocument = ownerFirestore.doc(
          'accounts/$ownerUid/drafts/current',
        );
        final observerDocument = observerFirestore.doc(
          'accounts/$ownerUid/drafts/current',
        );

        await ownerFirestore.disableNetwork();
        storage = await LocalStorage.open(directory: directory);
        repository = _repository(storage, ownerFirestore, ownerUid);
        expect(await repository.read(), isNull);
        var content = _importedContent(
          PortfolioContent(
            profile: const PortfolioProfile(
              name: 'Disposable acceptance owner',
              headline: 'Offline draft',
            ),
          ),
        );
        final saved = await repository
            .save(content, expectedRevision: 0, notes: 'Private offline note')
            .timeout(const Duration(seconds: 10));
        expect(saved.content, content);
        expect(saved.pendingSync, isTrue);
        _expectImportedProject(saved.content!);
        expect(_storedDraftEnvelope(storage, saved.notes)['schemaVersion'], 3);
        expect(
          repository.syncState.status,
          anyOf(PortfolioSyncStatus.pending, PortfolioSyncStatus.error),
        );

        // Reopen the real Hive files while Firestore still has no network.
        // dispose must not wait for the SDK's offline write acknowledgement.
        await repository.dispose().timeout(const Duration(seconds: 10));
        repository = null;
        await storage.close();
        storage = await LocalStorage.open(directory: directory);
        repository = _repository(storage, ownerFirestore, ownerUid);
        final restored = await repository.read().timeout(
          const Duration(seconds: 10),
        );
        expect(restored?.notes, 'Private offline note');
        expect(restored?.content, content);
        expect(restored?.pendingSync, isTrue);
        _expectImportedProject(restored!.content!);
        expect(
          _storedDraftEnvelope(storage, restored.notes)['schemaVersion'],
          3,
        );

        await ownerFirestore.enableNetwork();
        await repository.retry();
        await _waitUntil(
          () => repository!.syncState.status == PortfolioSyncStatus.synced,
          reason: 'The server must acknowledge the restored local outbox',
        );
        final acknowledged = await ownerDocument
            .get(const GetOptions(source: Source.server))
            .timeout(_networkTimeout);
        expect(acknowledged.metadata.isFromCache, isFalse);
        expect(acknowledged.metadata.hasPendingWrites, isFalse);
        expect(acknowledged.data()?['notes'], 'Private offline note');
        expect(acknowledged.data()?['updatedAt'], isA<Timestamp>());
        expect(acknowledged.data()?['schemaVersion'], 2);
        final cloud = decodeCloudPortfolioDraft(
          acknowledged.data()!,
          ownerUid: ownerUid,
        );
        expect(cloud.content, content);
        _expectImportedProject(cloud.content!);
        expect((await repository.read())?.pendingSync, isFalse);

        // Source changes become durable only after the explicit review action.
        // A rename retains the stable repository ID and the manual overrides.
        final review = reviewGitHubProject(
          content,
          _githubSource(renamed: true),
        );
        expect(review.status, PortfolioGitHubReviewStatus.changesAvailable);
        final acceptedContent = acceptGitHubProjectChanges(
          content,
          review,
          validatedAt: _renamedValidatedAt,
        );
        final repeatedImport = addGitHubProject(
          acceptedContent,
          _githubSource(renamed: true),
          validatedAt: _renamedValidatedAt,
        );
        expect(repeatedImport.projects, hasLength(1));
        _expectImportedProject(repeatedImport, renamed: true);
        final beforeReviewSave = (await repository.read())!;
        final reviewed = await repository
            .save(
              repeatedImport,
              expectedRevision: beforeReviewSave.revision,
              notes: beforeReviewSave.notes,
            )
            .timeout(const Duration(seconds: 10));
        expect(reviewed.pendingSync, isTrue);
        await _waitUntil(
          () => repository!.syncState.status == PortfolioSyncStatus.synced,
          reason:
              'The reviewed source and manual overrides must reach the server',
        );
        final reviewedCloudSnapshot = await ownerDocument
            .get(const GetOptions(source: Source.server))
            .timeout(_networkTimeout);
        final reviewedCloud = decodeCloudPortfolioDraft(
          reviewedCloudSnapshot.data()!,
          ownerUid: ownerUid,
        );
        expect(reviewedCloudSnapshot.data()?['schemaVersion'], 2);
        expect(reviewedCloud.content, repeatedImport);
        _expectImportedProject(reviewedCloud.content!, renamed: true);
        content = repeatedImport;

        // A second SDK client for the same UID commits after the first device.
        await observerAuth
            .signInWithEmailAndPassword(email: ownerEmail, password: password)
            .timeout(_networkTimeout);
        expect(observerAuth.currentUser?.uid, ownerUid);
        final secondContent = content.copyWith(
          profile: content.profile.copyWith(headline: 'Second client wins'),
        );
        final secondRemote = FirestorePortfolioDraftRepository(
          firestore: observerFirestore,
          uid: ownerUid,
        );
        await secondRemote
            .write(
              CloudPortfolioDraft(
                ownerUid: ownerUid,
                mutationId: 'phase8-second-$stamp',
                // Cross-device local revision does not decide the winner.
                localRevision: 1,
                notes: 'Second client private note',
                content: secondContent,
              ),
            )
            .timeout(_networkTimeout);
        await _waitUntil(() async {
          final draft = await repository!.read();
          return draft?.notes == 'Second client private note' &&
              draft?.content == secondContent &&
              draft?.pendingSync == false;
        }, reason: 'The owner listener must hydrate the later server commit');
        final winner = await ownerDocument
            .get(const GetOptions(source: Source.server))
            .timeout(_networkTimeout);
        expect(winner.data()?['mutationId'], 'phase8-second-$stamp');
        expect(winner.data()?['notes'], 'Second client private note');
        _expectImportedProject(
          decodeCloudPortfolioDraft(
            winner.data()!,
            ownerUid: ownerUid,
          ).content!,
          renamed: true,
        );

        await observerAuth.signOut();
        await expectLater(
          observerDocument
              .get(const GetOptions(source: Source.server))
              .timeout(_networkTimeout),
          throwsA(_permissionDenied),
        );
        final foreign = await observerAuth
            .createUserWithEmailAndPassword(
              email: foreignEmail,
              password: password,
            )
            .timeout(_networkTimeout);
        foreignUid = foreign.user!.uid;
        expect(foreignUid, isNot(ownerUid));
        await expectLater(
          observerDocument
              .get(const GetOptions(source: Source.server))
              .timeout(_networkTimeout),
          throwsA(_permissionDenied),
        );
        await expectLater(
          observerDocument
              .set({
                ...winner.data()!,
                'notes': 'Foreign write must fail',
                'mutationId': 'phase8-forbidden-$stamp',
                'updatedAt': FieldValue.serverTimestamp(),
              })
              .timeout(_networkTimeout),
          throwsA(_permissionDenied),
        );
        final protected = await ownerDocument
            .get(const GetOptions(source: Source.server))
            .timeout(_networkTimeout);
        expect(protected.data()?['notes'], 'Second client private note');

        // Production transfer checks cloud occupancy on a fresh local device.
        await repository.dispose();
        repository = null;
        await storage.close();
        storage = null;
        storage = await LocalStorage.open(
          directory: Directory('${directory.path}/fresh-device'),
        );
        final occupiedRuntime = LocalRuntime(
          settings: const AppSettings(),
          settingsRepository: _AcceptanceSettingsRepository(),
          storage: storage,
          firestore: ownerFirestore,
          accountAuth: ownerAuth,
        );
        const guestNote = 'Guest must survive occupied cloud';
        await occupiedRuntime.draftAccounts.guestRepository.saveNotes(
          guestNote,
        );
        await expectLater(
          occupiedRuntime
              .transferGuestToUser(ownerUid)
              .timeout(_networkTimeout),
          throwsA(
            isA<PortfolioDraftFailure>().having(
              (failure) => failure.kind,
              'kind',
              PortfolioDraftFailureKind.conflict,
            ),
          ),
        );
        expect(
          (await occupiedRuntime.draftAccounts.guestRepository.read())?.notes,
          guestNote,
        );
        expect(await occupiedRuntime.draftAccounts.hasGuestDraft(), isTrue);
        expect(
          (await ownerDocument.get(const GetOptions(source: Source.server)))
              .data()?['notes'],
          'Second client private note',
        );

        // The same guest can explicitly claim an empty account in a transaction.
        final emptyRuntime = LocalRuntime(
          settings: const AppSettings(),
          settingsRepository: _AcceptanceSettingsRepository(),
          storage: storage,
          firestore: observerFirestore,
          accountAuth: observerAuth,
        );
        await emptyRuntime
            .transferGuestToUser(foreignUid)
            .timeout(_networkTimeout);
        expect(await emptyRuntime.draftAccounts.hasGuestDraft(), isFalse);
        final claimedDocument = observerFirestore.doc(
          'accounts/$foreignUid/drafts/current',
        );
        final claimed = await claimedDocument
            .get(const GetOptions(source: Source.server))
            .timeout(_networkTimeout);
        expect(claimed.data()?['notes'], guestNote);
        final accountRepository = emptyRuntime.repositoryForUser(foreignUid);
        expect(accountRepository, isA<SyncedPortfolioDraftRepository>());
        repository = accountRepository as SyncedPortfolioDraftRepository;
        final transferred = await repository.read().timeout(
          const Duration(seconds: 10),
        );
        expect(transferred?.notes, guestNote);
        expect(transferred?.pendingSync, isFalse);
        final transferMetadata = await HivePortfolioSyncMetadataStore(
          storage.portfolioDraft,
          ownerUid: foreignUid,
        ).read();
        expect(transferMetadata?.pending, isFalse);
        expect(transferMetadata?.mutationId, claimed.data()?['mutationId']);
        final afterRead = await claimedDocument
            .get(const GetOptions(source: Source.server))
            .timeout(_networkTimeout);
        expect(afterRead.data()?['mutationId'], claimed.data()?['mutationId']);
      } finally {
        // Cleanup is restricted to the exact synthetic identities created above.
        // Each step is attempted even if a Firestore request fails, so a failed
        // acceptance check does not prevent disposal or Auth account deletion.
        await _cleanUp([
          () async => repository?.dispose(),
          () async => storage?.close(),
          () async => ownerFirestore?.enableNetwork(),
          () async {
            if (ownerAuth != null &&
                ownerUid != null &&
                ownerFirestore != null) {
              _expectDisposableUser(
                ownerAuth.currentUser,
                ownerUid,
                ownerEmail,
              );
              await ownerFirestore
                  .doc('accounts/$ownerUid/drafts/current')
                  .delete();
            }
          },
          () async {
            if (ownerAuth != null && ownerUid != null) {
              _expectDisposableUser(
                ownerAuth.currentUser,
                ownerUid,
                ownerEmail,
              );
              await ownerAuth.currentUser!.delete();
            }
          },
          () async {
            if (observerAuth != null &&
                foreignUid != null &&
                observerFirestore != null) {
              _expectDisposableUser(
                observerAuth.currentUser,
                foreignUid,
                foreignEmail,
              );
              await observerFirestore
                  .doc('accounts/$foreignUid/drafts/current')
                  .delete();
            }
          },
          () async {
            if (observerAuth != null && foreignUid != null) {
              _expectDisposableUser(
                observerAuth.currentUser,
                foreignUid,
                foreignEmail,
              );
              await observerAuth.currentUser!.delete();
            }
          },
          () async => observerAuth?.signOut(),
          () async => ownerFirestore?.terminate(),
          () async => observerFirestore?.terminate(),
          () async => observerApp?.delete(),
          () async => ownerApp?.delete(),
          () async => directory.delete(recursive: true),
        ]);
      }
    },
    skip: !enabled || !Platform.isAndroid || restorePhase.isNotEmpty,
    timeout: const Timeout(Duration(minutes: 8)),
  );

  // Seed/check run in separate native processes. Only Firebase Auth persists
  // the credentials; Hive persists the exact pending snapshot and mutation.
  testWidgets(
    'native Firestore outbox survives a new process',
    (tester) async {
      expect(restorePhase, anyOf('seed', 'check'));
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options.projectId, 'stackcard-dev-snownumb');
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/stackcard-phase8-restore');
      final app = await Firebase.initializeApp(
        name: 'stackcard-phase8-restore',
        options: options,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      FirebaseFirestore? firestore;
      LocalStorage? storage;
      SyncedPortfolioDraftRepository? repository;
      String? ownedUid;
      String? ownedEmail;
      var retainSeed = false;
      var createdDirectory = false;
      try {
        if (restorePhase == 'seed') {
          expect(
            auth.currentUser,
            isNull,
            reason: 'Finish the previous isolated seed/check pair first',
          );
          expect(
            await directory.exists(),
            isFalse,
            reason: 'Never replace a previous isolated restore outbox',
          );
          final email =
              'phase8.restore.${DateTime.now().microsecondsSinceEpoch}@example.invalid';
          final credential = await auth
              .createUserWithEmailAndPassword(
                email: email,
                password: _randomPassword(),
              )
              .timeout(_networkTimeout);
          ownedUid = credential.user!.uid;
          ownedEmail = email;
        } else {
          // Inspect the SDK-restored identity before any sign-in operation.
          final initialUser = auth.currentUser;
          expect(initialUser, isNotNull);
          expect(
            initialUser!.email,
            matches(r'^phase8\.restore\.\d+@example\.invalid$'),
          );
          ownedUid = initialUser.uid;
          ownedEmail = initialUser.email!;
          expect(await directory.exists(), isTrue);
        }

        firestore = FirebaseFirestore.instanceFor(app: app);
        await firestore.disableNetwork();
        storage = await LocalStorage.open(directory: directory);
        createdDirectory = restorePhase == 'seed';
        repository = _repository(storage, firestore, ownedUid);
        if (restorePhase == 'seed') {
          expect(await repository.read(), isNull);
          final saved = await repository
              .save(_restoreContent(), expectedRevision: 0, notes: _restoreNote)
              .timeout(const Duration(seconds: 10));
          expect(saved.pendingSync, isTrue);
          await storage.portfolioDraft.flush();
          // The test runner force-stops Android without lifecycle callbacks.
          // Flush the SDK's asynchronous Auth SharedPreferences.apply() first.
          await Future<void>.delayed(const Duration(seconds: 2));
          retainSeed = true;
        } else {
          final restored = await repository.read().timeout(
            const Duration(seconds: 10),
          );
          expect(restored?.notes, _restoreNote);
          expect(restored?.content, _restoreContent());
          expect(restored?.pendingSync, isTrue);
          await firestore.enableNetwork();
          await repository.retry();
          await _waitUntil(
            () => repository!.syncState.status == PortfolioSyncStatus.synced,
            reason: 'The new process must deliver the persisted outbox',
          );
          final acknowledged = await firestore
              .doc('accounts/$ownedUid/drafts/current')
              .get(const GetOptions(source: Source.server))
              .timeout(_networkTimeout);
          expect(acknowledged.metadata.isFromCache, isFalse);
          expect(acknowledged.metadata.hasPendingWrites, isFalse);
          expect(acknowledged.data()?['notes'], _restoreNote);
          expect(acknowledged.data()?['updatedAt'], isA<Timestamp>());
          expect((await repository.read())?.pendingSync, isFalse);
        }
      } finally {
        await _cleanUp([
          () async => repository?.dispose(),
          () async => storage?.close(),
          if (!retainSeed) ...[
            () async => firestore?.enableNetwork(),
            () async {
              if (ownedUid != null && ownedEmail != null && firestore != null) {
                _expectRestoreUser(auth.currentUser, ownedUid, ownedEmail);
                await firestore
                    .doc('accounts/$ownedUid/drafts/current')
                    .delete();
              }
            },
            () async {
              if (ownedUid != null && ownedEmail != null) {
                _expectRestoreUser(auth.currentUser, ownedUid, ownedEmail);
                await auth.currentUser!.delete();
              }
            },
            () async => firestore?.terminate(),
            () async => app.delete(),
            () async {
              if ((ownedUid != null || createdDirectory) &&
                  await directory.exists()) {
                await directory.delete(recursive: true);
              }
            },
          ],
        ]);
        // A successful seed intentionally retains its isolated SDK instance,
        // account and directory until check runs in the next native process.
      }
    },
    skip: !enabled || !Platform.isAndroid || restorePhase.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

const _networkTimeout = Duration(seconds: 45);
const _restoreNote = 'Phase 8 offline process restore';

PortfolioContent _restoreContent() => _importedContent(
  PortfolioContent(
    profile: const PortfolioProfile(
      name: 'Disposable restore owner',
      headline: 'Pending through process stop',
    ),
  ),
);

const _githubRepositoryId = 431234567;
const _curatedDescription = 'Curated description survives source updates';
const _curatedLiveUrl = 'https://example.invalid/native-portfolio';
final _initialValidatedAt = DateTime.utc(2026, 10, 4, 1);
final _renamedValidatedAt = DateTime.utc(2026, 10, 4, 2);

GitHubProjectSource _githubSource({bool renamed = false}) =>
    GitHubProjectSource(
      repositoryId: _githubRepositoryId,
      name: renamed ? 'native-demo-renamed' : 'native-demo',
      fullName: renamed
          ? 'stackcard-acceptance/native-demo-renamed'
          : 'stackcard-acceptance/native-demo',
      htmlUrl: renamed
          ? 'https://github.com/stackcard-acceptance/native-demo-renamed'
          : 'https://github.com/stackcard-acceptance/native-demo',
      description: renamed
          ? 'Changed source description'
          : 'Original source description',
      language: renamed ? 'TypeScript' : 'Dart',
      stars: renamed ? 3 : 1,
      forks: 0,
      isFork: false,
      archived: false,
      updatedAt: DateTime.utc(2026, 10, renamed ? 4 : 3),
    );

PortfolioContent _importedContent(PortfolioContent base) {
  final imported = addGitHubProject(
    base,
    _githubSource(),
    validatedAt: _initialValidatedAt,
  );
  final project = imported.projects.single;
  return imported.copyWith(
    projects: [
      project.withUserEdits(
        project.copyWith(
          description: _curatedDescription,
          liveUrl: _curatedLiveUrl,
          featured: true,
        ),
      ),
    ],
  );
}

void _expectImportedProject(PortfolioContent content, {bool renamed = false}) {
  expect(content.projects, hasLength(1));
  final project = content.projects.single;
  expect(project.id, 'github-$_githubRepositoryId');
  expect(project.githubRepositoryId, _githubRepositoryId);
  expect(project.source, PortfolioProjectSource.github);
  expect(project.title, renamed ? 'native-demo-renamed' : 'native-demo');
  expect(project.description, _curatedDescription);
  expect(project.liveUrl, _curatedLiveUrl);
  expect(project.featured, isTrue);
  expect(
    project.githubMetadata?.acceptedSource,
    _githubSource(renamed: renamed),
  );
  expect(project.githubMetadata?.overrideFields, {
    PortfolioGitHubField.description,
  });
  expect(
    project.lastGitHubSyncAt,
    renamed ? _renamedValidatedAt : _initialValidatedAt,
  );
}

Map<String, dynamic> _storedDraftEnvelope(LocalStorage storage, String notes) =>
    storage.portfolioDraft.values
        .whereType<String>()
        .map(jsonDecode)
        .whereType<Map<String, dynamic>>()
        .singleWhere((record) => record['notes'] == notes);

Future<void> _cleanUp(List<Future<void> Function()> actions) async {
  Object? firstError;
  StackTrace? firstStack;
  for (final action in actions) {
    try {
      await action().timeout(_networkTimeout);
    } catch (error, stack) {
      firstError ??= error;
      firstStack ??= stack;
    }
  }
  if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
}

SyncedPortfolioDraftRepository _repository(
  LocalStorage storage,
  FirebaseFirestore firestore,
  String uid,
) => SyncedPortfolioDraftRepository(
  ownerUid: uid,
  local: LocalDraftAccounts(storage.portfolioDraft).repositoryForUser(uid),
  metadata: HivePortfolioSyncMetadataStore(
    storage.portfolioDraft,
    ownerUid: uid,
  ),
  remote: FirestorePortfolioDraftRepository(firestore: firestore, uid: uid),
);

Future<void> _waitUntil(
  FutureOr<bool> Function() predicate, {
  required String reason,
}) async {
  final deadline = DateTime.now().add(_networkTimeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail(reason);
}

Matcher get _permissionDenied => isA<FirebaseException>().having(
  (failure) => failure.code,
  'code',
  'permission-denied',
);

String _randomPassword() {
  final random = Random.secure();
  return List.generate(24, (_) => random.nextInt(36).toRadixString(36)).join();
}

void _expectDisposableUser(User? user, String uid, String email) {
  expect(user?.uid, uid, reason: 'Cleanup may only delete its own test UID');
  expect(user?.email, email);
  expect(email, matches(r'^phase8\.(owner|foreign)\.\d+@example\.invalid$'));
}

void _expectRestoreUser(User? user, String uid, String email) {
  expect(user?.uid, uid, reason: 'Cleanup may only delete its own restore UID');
  expect(user?.email, email);
  expect(email, matches(r'^phase8\.restore\.\d+@example\.invalid$'));
}

final class _AcceptanceSettingsRepository implements SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {}
}
