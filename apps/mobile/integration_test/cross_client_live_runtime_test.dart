import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/core/storage/local_storage.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/data/synced_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:app_stackcard/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Live Spark SDK acceptance; browser владеет вторым клиентом и этапами bridge.
/// Только заранее созданные disposable identities, отдельные named apps/Hive.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_LIVE_CROSS_CLIENT_ACCEPTANCE');
  const run = String.fromEnvironment('LIVE_SYNC_RUN_ID');
  const ownerEmail = String.fromEnvironment('LIVE_SYNC_OWNER_EMAIL');
  const ownerPassword = String.fromEnvironment('LIVE_SYNC_OWNER_PASSWORD');
  const ownerUid = String.fromEnvironment('LIVE_SYNC_OWNER_UID');
  const foreignEmail = String.fromEnvironment('LIVE_SYNC_FOREIGN_EMAIL');
  const foreignPassword = String.fromEnvironment('LIVE_SYNC_FOREIGN_PASSWORD');
  const foreignUid = String.fromEnvironment('LIVE_SYNC_FOREIGN_UID');

  testWidgets(
    'live web and Android roundtrip, durable offline outbox and UID isolation',
    (tester) async {
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(run), isTrue);
      expect(ownerEmail == 'live-sync.a.$run@example.invalid', isTrue);
      expect(foreignEmail == 'live-sync.b.$run@example.invalid', isTrue);
      expect(ownerPassword.isNotEmpty && foreignPassword.isNotEmpty, isTrue);
      expect(_validUid(ownerUid) && _validUid(foreignUid), isTrue);
      expect(ownerUid != foreignUid, isTrue);
      expect(
        const [
          bool.hasEnvironment('FIREBASE_AUTH_EMULATOR_HOST'),
          bool.hasEnvironment('FIREBASE_AUTH_EMULATOR_PORT'),
          bool.hasEnvironment('FIRESTORE_EMULATOR_HOST'),
          bool.hasEnvironment('FIRESTORE_EMULATOR_PORT'),
          bool.hasEnvironment('STORAGE_EMULATOR_HOST'),
          bool.hasEnvironment('STORAGE_EMULATOR_PORT'),
          bool.hasEnvironment('FIREBASE_STORAGE_EMULATOR_HOST'),
        ].any((present) => present),
        isFalse,
      );
      final options = DefaultFirebaseOptions.android;
      expect(options.projectId, 'stackcard-dev-snownumb');
      // Default SDK session только читается; обычные Hive/settings не открываются.
      final defaultApp = await Firebase.initializeApp(options: options);
      final defaultAuth = FirebaseAuth.instanceFor(app: defaultApp);
      final defaultUid = (await defaultAuth.authStateChanges().first)?.uid;
      expect(defaultUid != ownerUid && defaultUid != foreignUid, isTrue);

      FirebaseApp? app;
      FirebaseAuth? auth;
      FirebaseFirestore? db;
      LocalStorage? storage;
      SyncedPortfolioDraftRepository? repository;
      SyncedPortfolioDraftRepository? foreignRepository;
      Directory? directory;
      var ownsDirectory = false;

      try {
        app = await Firebase.initializeApp(
          name: 'live-cross-client-$run',
          options: options,
        );
        auth = FirebaseAuth.instanceFor(app: app);
        expect(auth.currentUser, isNull);
        final account = FirebaseAccountAuthRepository(auth: auth);
        await account.signInEmail(ownerEmail, ownerPassword).timeout(_network);
        _expectIdentity(auth, ownerUid, ownerEmail);
        db = FirebaseFirestore.instanceFor(app: app);
        db.settings = const Settings(persistenceEnabled: false);
        final support = await getApplicationSupportDirectory();
        directory = Directory('${support.path}/live-cross-client-$run');
        expect(await directory.exists(), isFalse);
        await directory.create();
        ownsDirectory = true;
        storage = await LocalStorage.open(directory: directory);
        final ownerAuth = auth;
        repository = _repository(storage, db, ownerAuth, ownerUid);
        await repository.read();
        var current = await _waitDraft(
          repository,
          (draft) =>
              _profile(draft).name == 'Live web seed $run' &&
              _profile(draft).headline == 'Web initial $run' &&
              !draft.pendingSync,
        );
        final seedContent = current.content!;
        final seedNotes = current.notes;
        final initial = await _serverDraft(db, ownerUid);
        expect(initial.content, seedContent);
        expect(initial.notes, seedNotes);
        _checkpoint('native_read_actual_web_seed');
        await _stage(run, 'native-read-web');

        final androidContent = _withMainProfile(
          seedContent,
          headline: 'Android cloud ack $run',
        );
        final saved = await repository
            .save(
              androidContent,
              expectedRevision: current.revision,
              notes: seedNotes,
            )
            .timeout(_local);
        expect(saved.pendingSync, isTrue);
        await _waitSynced(repository);
        final acknowledged = await _serverDraft(db, ownerUid);
        expect(acknowledged.content, androidContent);
        expect(acknowledged.notes, seedNotes);
        expect(
          acknowledged.mutationId,
          repository.syncState.confirmedMutationId,
        );
        _checkpoint('native_save_actual_server_ack');
        await _stage(run, 'native-saved');

        current = await _waitDraft(
          repository,
          (draft) =>
              _profile(draft).name == 'Web roundtrip $run' &&
              !draft.pendingSync,
        );
        final roundtripContent = current.content!;
        final roundtripMain = mainPortfolioDocument(roundtripContent)!;
        final previousMain = mainPortfolioDocument(androidContent)!;
        expect(
          roundtripMain.updatedAt.isBefore(previousMain.updatedAt),
          isFalse,
        );
        // Explicit web Save обновляет timestamp main; остальные поля неизменны.
        expect(
          roundtripContent,
          _withMainProfile(
            androidContent,
            name: 'Web roundtrip $run',
            updatedAt: roundtripMain.updatedAt,
          ),
        );
        expect(current.notes, seedNotes);
        _checkpoint('native_listener_actual_web_roundtrip');

        await db.disableNetwork();
        final offlineContent = _withMainProfile(
          roundtripContent,
          headline: 'Android offline restore $run',
        );
        final offline = await repository
            .save(
              offlineContent,
              expectedRevision: current.revision,
              notes: seedNotes,
            )
            .timeout(_local);
        expect(offline.pendingSync, isTrue);
        final beforeRestart = (await HivePortfolioSyncMetadataStore(
          storage.portfolioDraft,
          ownerUid: ownerUid,
        ).read())!;
        expect(beforeRestart.pending, isTrue);
        await repository.dispose().timeout(_local);
        repository = null;
        await storage.close().timeout(_local);
        storage = null;
        // Тот же SDK остаётся offline; reopen проверяет настоящие Hive bytes.
        storage = await LocalStorage.open(directory: directory);
        repository = _repository(storage, db, ownerAuth, ownerUid);
        final restored = (await repository.read().timeout(_local))!;
        final restoredRecord = (await HivePortfolioSyncMetadataStore(
          storage.portfolioDraft,
          ownerUid: ownerUid,
        ).read())!;
        expect(restored.pendingSync, isTrue);
        expect(restored.content, offlineContent);
        expect(restored.notes, seedNotes);
        expect(restored.revision, offline.revision);
        expect(restoredRecord.pending, isTrue);
        expect(restoredRecord.mutationId, beforeRestart.mutationId);
        expect(restoredRecord.draft.content, beforeRestart.draft.content);
        expect(restoredRecord.draft.notes, beforeRestart.draft.notes);
        expect(restoredRecord.draft.revision, beforeRestart.draft.revision);
        expect(restoredRecord.draft.updatedAt, beforeRestart.draft.updatedAt);
        _checkpoint('native_offline_exact_hive_outbox_restore');
        await _stage(run, 'native-offline');
        await db.enableNetwork();
        await repository.retry();
        await _waitSynced(repository);
        final reconnected = await _serverDraft(db, ownerUid);
        expect(reconnected.content, offlineContent);
        expect(reconnected.notes, seedNotes);
        expect(reconnected.mutationId, beforeRestart.mutationId);
        expect((await repository.read())!.pendingSync, isFalse);
        _checkpoint('native_reconnected_actual_server_ack');
        await _stage(run, 'native-reconnected');

        await account.signOut().timeout(_network);
        await account
            .signInEmail(foreignEmail, foreignPassword)
            .timeout(_network);
        _expectIdentity(auth, foreignUid, foreignEmail);
        await expectLater(
          repository.read(),
          throwsA(
            isA<PortfolioDraftFailure>().having(
              (failure) => failure.kind,
              'kind',
              PortfolioDraftFailureKind.unavailable,
            ),
          ),
        );
        // Auth UID меняется раньше credentials активного Firestore transport.
        // Сначала подтверждаем B настоящим разрешённым server read его draft.
        final cloudB = await _waitServerIdentity(
          db,
          auth,
          foreignUid,
          foreignEmail,
        );
        final cloudBProfile = mainPortfolioDocument(cloudB.content!)!
            .content
            .profile;
        expect(cloudBProfile.name, 'Foreign web $run');
        expect(cloudBProfile.headline, 'Foreign initial $run');
        _checkpoint('native_server_b_identity_proven');
        await expectLater(
          db
              .doc('accounts/$ownerUid/drafts/current')
              .get(const GetOptions(source: Source.server))
              .timeout(_network),
          throwsA(
            isA<FirebaseException>().having(
              (error) => error.code,
              'code',
              'permission-denied',
            ),
          ),
        );
        foreignRepository = _repository(storage, db, ownerAuth, foreignUid);
        await foreignRepository.read();
        await _waitSynced(foreignRepository);
        final foreign = (await foreignRepository.read())!;
        expect(foreign.content, isNotNull);
        expect(_profile(foreign).name, 'Foreign web $run');
        expect(_profile(foreign).headline, 'Foreign initial $run');
        expect(foreign.content, cloudB.content);
        expect(foreign.notes, cloudB.notes);
        expect(foreign.content == offlineContent, isFalse);
        if (seedNotes.isNotEmpty) {
          expect(foreign.notes == seedNotes, isFalse);
        }
        // Локальный A envelope также не изменился при чтении B.
        final isolatedA = await LocalDraftAccounts(storage.portfolioDraft)
            .repositoryForUser(ownerUid)
            .read();
        expect(isolatedA!.content, offlineContent);
        expect(isolatedA.notes, seedNotes);
        _checkpoint('native_uid_switch_actual_rules_and_local_isolation');
        await _stage(run, 'native-isolation');
      } finally {
        // Сначала останавливаем все writers, затем удаляем только exact A/B.
        final ownerRepoClosed = await _attempt(
          () async => repository?.dispose(),
        );
        final foreignRepoClosed = await _attempt(
          () async => foreignRepository?.dispose(),
        );
        final storageClosed = await _attempt(() async => storage?.close());
        final writerStopped = await _attempt(() async => db?.terminate());
        final signedOut = await _attempt(() async => auth?.signOut());
        final appDeleted = await _attempt(() async => app?.delete());
        final ownerCleanup = await _deleteDisposableAccount(
          options: options,
          appName: 'live-cross-client-cleanup-a-$run',
          uid: ownerUid,
          email: ownerEmail,
          password: ownerPassword,
          writerStopped: writerStopped,
        );
        final foreignCleanup = await _deleteDisposableAccount(
          options: options,
          appName: 'live-cross-client-cleanup-b-$run',
          uid: foreignUid,
          email: foreignEmail,
          password: foreignPassword,
          writerStopped: writerStopped,
        );
        final filesDeleted = await _attempt(() async {
          if (ownsDirectory && storageClosed) {
            await directory!.delete(recursive: true);
          }
        });
        final cleanup = {
          'repositoriesClosed': ownerRepoClosed && foreignRepoClosed,
          'storageClosed': storageClosed,
          'writerStopped': writerStopped,
          'namedSignedOut': signedOut,
          'namedAppDeleted': appDeleted,
          'ownerDraftAbsent': ownerCleanup.draftAbsent,
          'ownerAuthDeleted': ownerCleanup.authDeleted,
          'ownerSdkClosed': ownerCleanup.sdkClosed,
          'foreignDraftAbsent': foreignCleanup.draftAbsent,
          'foreignAuthDeleted': foreignCleanup.authDeleted,
          'foreignSdkClosed': foreignCleanup.sdkClosed,
          'isolatedFilesDeleted': filesDeleted,
          'defaultSessionPreserved': defaultAuth.currentUser?.uid == defaultUid,
        };
        debugPrint(
          'STACKCARD_LIVE_SYNC:${jsonEncode({'checkpoint': 'cleanup', 'pid': pid, 'phase': 'cleanup', ...cleanup})}',
        );
        expect(
          cleanup.values.every((value) => value),
          isTrue,
          reason:
              'Disposable cleanup incomplete; use the private run manifest.',
        );
      }
      _checkpoint('all_pass');
      expect(tester.takeException(), isNull);
    },
    skip: !enabled || !Platform.isAndroid,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

const _network = Duration(seconds: 60);
const _local = Duration(seconds: 10);

bool _validUid(String uid) =>
    uid.isNotEmpty && uid.length <= 128 && !uid.contains('/');

void _expectIdentity(FirebaseAuth auth, String uid, String email) {
  expect(auth.currentUser?.uid == uid, isTrue);
  expect(auth.currentUser?.email == email, isTrue);
}

SyncedPortfolioDraftRepository _repository(
  LocalStorage storage,
  FirebaseFirestore db,
  FirebaseAuth auth,
  String uid,
) => SyncedPortfolioDraftRepository(
  ownerUid: uid,
  local: LocalDraftAccounts(storage.portfolioDraft).repositoryForUser(uid),
  metadata: HivePortfolioSyncMetadataStore(
    storage.portfolioDraft,
    ownerUid: uid,
  ),
  remote: FirestorePortfolioDraftRepository(firestore: db, uid: uid),
  isActive: () => auth.currentUser?.uid == uid,
);

PortfolioProfile _profile(PortfolioDraft draft) =>
    mainPortfolioDocument(draft.content!)!.content.profile;

PortfolioContent _withMainProfile(
  PortfolioContent workspace, {
  String? name,
  String? headline,
  DateTime? updatedAt,
}) {
  final main = mainPortfolioDocument(workspace)!;
  return workspace.copyWith(
    documents: [
      for (final document in workspace.documents)
        if (document.id == main.id)
          document.copyWith(
            updatedAt: updatedAt,
            content: document.content.copyWith(
              profile: document.content.profile.copyWith(
                name: name,
                headline: headline,
              ),
            ),
          )
        else
          document,
    ],
  );
}

Future<CloudPortfolioDraft> _serverDraft(
  FirebaseFirestore db,
  String uid, {
  Duration timeout = _network,
}) async {
  final snapshot = await db
      .doc('accounts/$uid/drafts/current')
      .get(const GetOptions(source: Source.server))
      .timeout(timeout);
  expect(snapshot.exists, isTrue);
  expect(snapshot.metadata.isFromCache, isFalse);
  expect(snapshot.metadata.hasPendingWrites, isFalse);
  expect(snapshot.data()?['schemaVersion'], 7);
  expect(snapshot.data()?['updatedAt'], isA<Timestamp>());
  return decodeCloudPortfolioDraft(snapshot.data()!, ownerUid: uid);
}

Future<CloudPortfolioDraft> _waitServerIdentity(
  FirebaseFirestore db,
  FirebaseAuth auth,
  String uid,
  String email,
) async {
  final deadline = DateTime.now().add(_network);
  while (true) {
    _expectIdentity(auth, uid, email);
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw TestFailure(
        'Firestore did not confirm the switched server identity.',
      );
    }
    try {
      final draft = await _serverDraft(db, uid, timeout: remaining);
      _expectIdentity(auth, uid, email);
      return draft;
    } on FirebaseException catch (error) {
      _expectIdentity(auth, uid, email);
      // Только старый transport credential допускает повтор own-B запроса.
      // Network, timeout, invalid data и успех foreign-A никогда не маскируем.
      if (error.code != 'permission-denied') rethrow;
    }
  }
}

Future<PortfolioDraft> _waitDraft(
  SyncedPortfolioDraftRepository repository,
  bool Function(PortfolioDraft) matches,
) async {
  final deadline = DateTime.now().add(_network);
  while (DateTime.now().isBefore(deadline)) {
    final draft = await repository.read().timeout(_local);
    if (draft?.content != null && matches(draft!)) return draft;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TestFailure('Live SDK listener did not reach the expected snapshot.');
}

Future<void> _waitSynced(SyncedPortfolioDraftRepository repository) async {
  final deadline = DateTime.now().add(_network);
  while (DateTime.now().isBefore(deadline)) {
    if (repository.syncState.status == PortfolioSyncStatus.synced) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TestFailure('Live SDK did not acknowledge the current outbox.');
}

Future<void> _stage(String run, String stage) async {
  expect(const {
    'native-read-web',
    'native-saved',
    'native-offline',
    'native-reconnected',
    'native-isolation',
  }, contains(stage));
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 180);
  try {
    await (() async {
      final request = await client.getUrl(
        Uri.http('10.0.2.2:3815', '/$run/$stage'),
      );
      request.followRedirects = false;
      final response = await request.close();
      expect(response.statusCode, 200);
      await response.drain<void>();
    })().timeout(const Duration(seconds: 180));
  } finally {
    client.close(force: true);
  }
}

void _checkpoint(String checkpoint) => debugPrint(
  'STACKCARD_LIVE_SYNC:${jsonEncode({'checkpoint': checkpoint, 'pid': pid, 'phase': 'native'})}',
);

Future<bool> _attempt(Future<void> Function() action) async {
  try {
    await action().timeout(_network);
    return true;
  } catch (_) {
    // Credentials, UID и SDK error payload не попадают в log.
    return false;
  }
}

Future<({bool draftAbsent, bool authDeleted, bool sdkClosed})>
_deleteDisposableAccount({
  required FirebaseOptions options,
  required String appName,
  required String uid,
  required String email,
  required String password,
  required bool writerStopped,
}) async {
  FirebaseApp? app;
  FirebaseAuth? auth;
  FirebaseFirestore? db;
  var draftAbsent = false;
  var authDeleted = false;
  var sdkClosed = true;
  try {
    if (!writerStopped) {
      return (draftAbsent: false, authDeleted: false, sdkClosed: true);
    }
    app = await Firebase.initializeApp(name: appName, options: options);
    auth = FirebaseAuth.instanceFor(app: app);
    expect(auth.currentUser, isNull);
    await FirebaseAccountAuthRepository(auth: auth)
        .signInEmail(email, password)
        .timeout(_network);
    _expectIdentity(auth, uid, email);
    db = FirebaseFirestore.instanceFor(app: app);
    db.settings = const Settings(persistenceEnabled: false);
    final account = await db
        .doc('accounts/$uid')
        .get(const GetOptions(source: Source.server))
        .timeout(_network);
    // Root lifecycle/publication records требуют trusted cleanup; их не трогаем.
    expect(account.exists, isFalse);
    _expectIdentity(auth, uid, email);
    final draft = db.doc('accounts/$uid/drafts/current');
    await draft.delete().timeout(_network);
    final deleted = await draft
        .get(const GetOptions(source: Source.server))
        .timeout(_network);
    draftAbsent =
        !deleted.exists &&
        !deleted.metadata.isFromCache &&
        !deleted.metadata.hasPendingWrites;
    expect(draftAbsent, isTrue);
    _expectIdentity(auth, uid, email);
    await auth.currentUser!.delete().timeout(_network);
    authDeleted = auth.currentUser == null;
  } catch (_) {
    // false statuses требуют отдельной cleanup ведущего по private manifest.
  } finally {
    final signedOut = await _attempt(() async => auth?.signOut());
    final terminated = await _attempt(() async => db?.terminate());
    final appDeleted = await _attempt(() async => app?.delete());
    sdkClosed = signedOut && terminated && appDeleted;
  }
  return (
    draftAbsent: draftAbsent,
    authDeleted: authDeleted,
    sdkClosed: sdkClosed,
  );
}
