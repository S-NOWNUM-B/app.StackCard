import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Auth implements AccountAuthRepository {
  _Auth(this.user);
  AuthUser? user;
  int signOuts = 0;
  @override
  Stream<AuthUser?> watchSession() => Stream.value(user);
  @override
  Future<void> signOut() async {
    signOuts++;
    user = null;
  }

  @override
  Future<void> signInEmail(String e, String p) async {}
  @override
  Future<void> registerEmail(String e, String p) async {}
  @override
  Future<void> sendPasswordReset(String e) async {}
  @override
  Future<void> signInGoogle() async {}
}

class _Management implements AccountManagementRepository {
  final actions = <String>[];
  @override
  Future<AccountSecurity> readSecurity(String uid) async {
    actions.add('read:$uid');
    return AccountSecurity(
      uid: uid,
      email: 'login@example.com',
      emailVerified: true,
      providers: {'password'},
    );
  }

  @override
  Future<void> reauthenticatePassword(String uid, String password) async {
    actions.add('reauth:$uid');
  }

  @override
  Future<void> reauthenticateGoogle(String uid) async {
    actions.add('google:$uid');
  }

  @override
  Future<void> sendVerification(String uid) async {}
  @override
  Future<void> requestEmailChange(String uid, String e) async {}
  @override
  Future<void> changePassword(String uid, String p) async {}
  @override
  Future<void> linkPassword(String uid, String e, String p) async {}
  @override
  Future<void> linkGoogle(String uid) async {}
  @override
  Future<void> unlinkProvider(String uid, String p) async {}
}

class _Journal implements AccountDeletionJournal {
  _Journal(this.request);
  AccountDeletionRequest? request;
  int clears = 0;
  @override
  Future<AccountDeletionRequest?> read() async => request;
  @override
  Future<void> write(AccountDeletionRequest r) async => request = r;
  @override
  Future<void> clear() async {
    clears++;
    request = null;
  }
}

class _Backend implements DocumentPublicationRepository {
  DocumentPublicationOutcome outcome = DocumentPublicationOutcome.pending;
  String action = 'deleteAccount';
  final calls = <String>[];
  String? key;
  @override
  Future<DocumentPublicationInventory> inventory() async =>
      DocumentPublicationInventory(publications: [], lifecycleGeneration: 7);
  @override
  Future<DocumentPublicationOperation> recoverAccountDeletion({
    required String ownerUid,
    required String operationId,
    required String recoveryKey,
    bool retry = false,
  }) async {
    calls.add('recover:$ownerUid:$retry');
    key = recoveryKey;
    return DocumentPublicationOperation(
      outcome: outcome,
      operationId: operationId,
      action: action,
      lifecycleGeneration: 8,
    );
  }

  @override
  Future<DocumentPublicationOperation> deleteAccount({
    required String operationId,
    required int expectedGeneration,
    required String recoveryKey,
  }) async {
    calls.add('delete:$expectedGeneration');
    key = recoveryKey;
    return DocumentPublicationOperation(
      outcome: outcome,
      operationId: operationId,
      action: action,
      lifecycleGeneration: 8,
    );
  }

  @override
  Future<DocumentPublicationOperation> status(String operationId) async {
    calls.add('status');
    return DocumentPublicationOperation(
      outcome: outcome,
      operationId: operationId,
      action: action,
    );
  }

  @override
  Future<DocumentPublicationOperation> mutate(
    DocumentPublicationMutation mutation,
  ) async => throw UnimplementedError();
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  _Auth auth,
  _Management management,
  _Journal journal,
  _Backend backend,
  List<String> cleanup, {
  String? pending,
  String initialLocation = '/settings/account',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/settings/account',
        builder: (_, _) => const SettingsAccountScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const Text('Hub')),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      accountAuthRepositoryProvider.overrideWithValue(auth),
      accountManagementRepositoryProvider.overrideWithValue(management),
      accountDeletionJournalFactoryProvider.overrideWithValue((_) => journal),
      documentPublicationRepositoryFactoryProvider.overrideWithValue(
        (_) => backend,
      ),
      accountDeletionInitialOwnerProvider.overrideWithValue(pending),
      accountConfirmedDeletionCleanupProvider.overrideWithValue((uid) async {
        cleanup.add(uid);
      }),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: StackCardTheme.dark,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  final key = List.filled(64, 'a').join();
  testWidgets('sign-in exposes pending deletion recovery after restart', (
    tester,
  ) async {
    final backend = _Backend();
    final journal = _Journal(
      AccountDeletionRequest(
        operationId: 'pending',
        expectedGeneration: 7,
        recoveryKey: key,
      ),
    );
    await _open(
      tester,
      _Auth(null),
      _Management(),
      journal,
      backend,
      [],
      pending: 'owner',
      initialLocation: '/sign-in',
    );
    await _tap(tester, find.byKey(const Key('account.deletionRecovery')));
    expect(find.byType(SettingsAccountScreen), findsOneWidget);
    expect(find.text('Проверить удаление'), findsOneWidget);
    await _tap(tester, find.text('Повторить'));
    expect(backend.calls, ['recover:owner:true']);
    expect(journal.clears, 0);
  });
  testWidgets(
    'signed-out pending deletion recovers by receipt without auth SDK or Firebase token',
    (tester) async {
      final auth = _Auth(null),
          management = _Management(),
          journal = _Journal(
            AccountDeletionRequest(
              operationId: 'delete-op',
              expectedGeneration: 7,
              recoveryKey: key,
            ),
          ),
          backend = _Backend();
      final cleanup = <String>[];
      final container = await _open(
        tester,
        auth,
        management,
        journal,
        backend,
        cleanup,
        pending: 'deleted-owner',
      );
      expect(management.actions, isEmpty);
      expect(find.text('Проверить удаление'), findsOneWidget);
      await _tap(tester, find.text('Проверить удаление'));
      expect(backend.calls, ['recover:deleted-owner:false']);
      expect(backend.key, key);
      expect(journal.clears, 0);
      expect(cleanup, isEmpty);
      backend.outcome = DocumentPublicationOutcome.completed;
      await _tap(tester, find.text('Проверить удаление'));
      expect(cleanup, ['deleted-owner']);
      expect(journal.clears, 1);
      expect(auth.signOuts, 1);
      expect(container.read(accountPendingDeletionOwnerProvider), isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'completed operation with a different action never authorizes local account cleanup',
    (tester) async {
      final auth = _Auth(null),
          management = _Management(),
          journal = _Journal(
            AccountDeletionRequest(
              operationId: 'other-op',
              expectedGeneration: 7,
              recoveryKey: key,
            ),
          );
      final backend = _Backend()
        ..outcome = DocumentPublicationOutcome.completed
        ..action = 'publish';
      final cleanup = <String>[];
      await _open(
        tester,
        auth,
        management,
        journal,
        backend,
        cleanup,
        pending: 'owner',
      );
      await _tap(tester, find.text('Проверить удаление'));
      expect(cleanup, isEmpty);
      expect(journal.clears, 0);
      expect(auth.signOuts, 0);
      expect(find.textContaining('Результат неизвестен'), findsOneWidget);
    },
  );
  testWidgets(
    'new deletion confirms reauth and persists recovery key before pending response',
    (tester) async {
      final auth = _Auth(const AuthUser(uid: 'owner')),
          management = _Management(),
          journal = _Journal(null),
          backend = _Backend();
      final cleanup = <String>[];
      await _open(tester, auth, management, journal, backend, cleanup);
      await _tap(tester, find.byKey(const Key('settings.account.delete')));
      await _tap(tester, find.text('Удалить аккаунт').last);
      await tester.enterText(find.byType(TextFormField), 'current-secret');
      await _tap(tester, find.text('Подтвердить'));
      expect(management.actions, contains('reauth:owner'));
      expect(backend.calls, ['delete:7']);
      expect(journal.request, isNotNull);
      expect(journal.request!.recoveryKey, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(journal.request!.recoveryKey, backend.key);
      expect(cleanup, isEmpty);
      expect(auth.signOuts, 0);
      expect(find.textContaining('Удаление выполняется'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
