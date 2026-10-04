import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/state/app_settings.dart';
import '../core/state/settings_repository.dart';
import '../core/storage/local_storage.dart';
import '../features/github_import/data/hive_github_response_cache.dart';
import '../features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import '../features/portfolio_draft/data/local_draft_accounts.dart';
import '../features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import '../features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import '../features/portfolio_draft/data/synced_portfolio_draft_repository.dart';
import '../features/portfolio_draft/domain/portfolio_draft_repository.dart';
import '../features/portfolio_draft/domain/portfolio_draft.dart';
import '../features/portfolio_draft/domain/portfolio_sync.dart';
import '../features/auth/auth.dart';
import '../firebase_options.dart';
import '../features/settings/data/shared_preferences_settings_repository.dart';

/// Composition root открывает disk-адаптеры до первого экрана приложения.
final class LocalRuntime {
  LocalRuntime({
    required this.settings,
    required this.settingsRepository,
    required this.storage,
    this.authRepository,
    this.firestore,
    this.accountAuth,
  });

  final AppSettings settings;
  final SettingsRepository settingsRepository;
  final LocalStorage storage;
  final AccountAuthRepository? authRepository;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? accountAuth;

  late final githubCache = HiveGitHubResponseCache(storage.githubResponses);
  late final draftAccounts = LocalDraftAccounts(storage.portfolioDraft);
  late final HivePortfolioDraftRepository draftRepository =
      draftAccounts.guestRepository;

  PortfolioDraftRepository repositoryForUser(String? uid) {
    if (uid == null) return draftAccounts.guestRepository;
    final local = draftAccounts.repositoryForUser(uid);
    final database = firestore;
    final auth = accountAuth;
    if (database == null || auth == null) return local;
    return SyncedPortfolioDraftRepository(
      ownerUid: uid,
      local: local,
      metadata: HivePortfolioSyncMetadataStore(
        storage.portfolioDraft,
        ownerUid: uid,
      ),
      remote: FirestorePortfolioDraftRepository(firestore: database, uid: uid),
      isActive: () =>
          storage.portfolioDraft.isOpen && auth.currentUser?.uid == uid,
    );
  }

  Future<void> transferGuestToUser(String uid) async {
    final database = firestore;
    final auth = accountAuth;
    if (database == null || auth == null) {
      return draftAccounts.transferGuestToUser(uid);
    }
    void requireOwner() {
      if (auth.currentUser?.uid != uid) {
        throw const PortfolioDraftFailure(
          PortfolioDraftFailureKind.unavailable,
        );
      }
    }

    requireOwner();
    final remote = FirestorePortfolioDraftRepository(
      firestore: database,
      uid: uid,
    );
    await HivePortfolioSyncMetadataStore(
      storage.portfolioDraft,
      ownerUid: uid,
    ).read();
    // A cache miss on a fresh/offline device does not prove cloud emptiness.
    // The transaction below still checks again to close the creation race.
    final pendingTransfer = await draftAccounts.hasPendingTransferForUser(uid);
    if (!pendingTransfer && await remote.hasDraftOnServer()) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.conflict);
    }
    requireOwner();
    await draftAccounts.transferGuestToUser(
      uid,
      beforeCommit: (source, transferId) async {
        requireOwner();
        await remote.claimGuestDraft(
          CloudPortfolioDraft(
            ownerUid: uid,
            mutationId: transferId,
            localRevision: source.revision < 1 ? 1 : source.revision,
            notes: source.notes,
            content: source.content,
          ),
        );
        requireOwner();
        return PortfolioSyncRecord(
          mutationId: transferId,
          pending: false,
          draft: PortfolioDraft(
            notes: source.notes,
            revision: source.revision,
            updatedAt: source.updatedAt,
            pendingSync: false,
            content: source.content,
          ),
        );
      },
    );
  }

  static Future<LocalRuntime> load({
    Directory? directory,
    SettingsRepository? settingsRepository,
    bool configureAuth = false,
  }) async {
    final repository =
        settingsRepository ??
        SharedPreferencesSettingsRepository(SharedPreferencesAsync());
    final settings = await repository.load();
    final storage = await LocalStorage.open(directory: directory);
    try {
      AccountAuthRepository? authRepository;
      FirebaseFirestore? firestore;
      FirebaseAuth? accountAuth;
      if (configureAuth) {
        final app = Firebase.apps.isEmpty
            ? await Firebase.initializeApp(
                options: DefaultFirebaseOptions.currentPlatform,
              )
            : Firebase.app();
        final auth = FirebaseAuth.instanceFor(app: app);
        accountAuth = auth;
        const emulatorHost = String.fromEnvironment(
          'FIREBASE_AUTH_EMULATOR_HOST',
        );
        if (emulatorHost.isNotEmpty) {
          const port = int.fromEnvironment(
            'FIREBASE_AUTH_EMULATOR_PORT',
            defaultValue: 9099,
          );
          await auth.useAuthEmulator(emulatorHost, port);
        }
        authRepository = FirebaseAccountAuthRepository(
          auth: auth,
          googleClientId: Platform.isIOS
              ? DefaultFirebaseOptions.currentPlatform.iosClientId
              : null,
        );
        firestore = FirebaseFirestore.instanceFor(app: app);
        const firestoreHost = String.fromEnvironment('FIRESTORE_EMULATOR_HOST');
        if (firestoreHost.isNotEmpty) {
          const firestorePort = int.fromEnvironment(
            'FIRESTORE_EMULATOR_PORT',
            defaultValue: 8080,
          );
          firestore.useFirestoreEmulator(firestoreHost, firestorePort);
        }
      }
      return LocalRuntime(
        settings: settings,
        settingsRepository: repository,
        storage: storage,
        authRepository: authRepository,
        firestore: firestore,
        accountAuth: accountAuth,
      );
    } catch (_) {
      await storage.close();
      rethrow;
    }
  }
}
