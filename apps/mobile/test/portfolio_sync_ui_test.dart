import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final status in [
    PortfolioSyncStatus.pending,
    PortfolioSyncStatus.synced,
    PortfolioSyncStatus.error,
  ]) {
    testWidgets('Notes display the actual $status cloud state', (tester) async {
      final repository = _SyncRepository(_draft('Saved'));
      repository.setSync(status);
      await _open(tester, repository);
      final text = tester.widget<Text>(find.byKey(_syncStatus)).data!;
      expect(text, switch (status) {
        PortfolioSyncStatus.pending =>
          'Сохранено на устройстве · ожидает синхронизации',
        PortfolioSyncStatus.synced => 'Синхронизировано с аккаунтом',
        _ => 'Не удалось синхронизировать',
      });
      expect(find.textContaining('пока не подключена'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Cloud retry sends only an explicit action without losing input',
    (tester) async {
      final repository = _SyncRepository(_draft('Saved'));
      repository.setSync(PortfolioSyncStatus.error);
      await _open(tester, repository);
      await tester.enterText(_notesField, 'Unsaved private input');
      await tester.pump();
      expect(repository.retries, 0);
      await tester.ensureVisible(find.byKey(_syncRetry));
      await tester.tap(find.byKey(_syncRetry));
      await tester.pumpAndSettle();
      expect(repository.retries, 1);
      expect(
        tester.widget<Text>(find.byKey(_syncStatus)).data,
        'Синхронизировано с аккаунтом',
      );
      expect(_notes(tester), 'Unsaved private input');
      expect(repository.savedNotes, isEmpty);
    },
  );

  testWidgets(
    'Remote updates retain dirty notes and offer explicit save or reload',
    (tester) async {
      final repository = _SyncRepository(
        _draft('Original', content: _content('Original')),
      );
      await _open(tester, repository);
      await tester.enterText(_notesField, 'My unsaved notes');
      await tester.pump();
      repository.receive(
        _draft('Other device', revision: 2, content: _content('Remote')),
      );
      await tester.pumpAndSettle();
      expect(_notes(tester), 'My unsaved notes');
      expect(
        find.byKey(const ValueKey('portfolio_remote_update')),
        findsOneWidget,
      );
      expect(find.text('Сохранить мою версию'), findsOneWidget);
      expect(repository.savedNotes, isEmpty);
      await tester.ensureVisible(find.byKey(_notesSave));
      await tester.tap(find.byKey(_notesSave));
      await tester.pumpAndSettle();
      expect(repository.savedNotes, ['My unsaved notes']);
      expect(repository.expectedRevisions, [2]);
      expect(repository.current!.content, _content('Original'));
      expect(
        find.byKey(const ValueKey('portfolio_remote_update')),
        findsNothing,
      );
      expect(_notes(tester), 'My unsaved notes');
    },
  );

  testWidgets('Reload accepts remote input only after discard confirmation', (
    tester,
  ) async {
    final repository = _SyncRepository(_draft('Original'));
    await _open(tester, repository);
    await tester.enterText(_notesField, 'Keep until confirmed');
    await tester.pump();
    repository.receive(_draft('Remote', revision: 2));
    await tester.pumpAndSettle();
    final reload = find.byKey(const ValueKey('portfolio_draft_reload'));
    await tester.ensureVisible(reload);
    await tester.tap(reload);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(_notes(tester), 'Keep until confirmed');
    await tester.tap(reload);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть сохранённое'));
    await tester.pumpAndSettle();
    expect(_notes(tester), 'Remote');
    expect(find.byKey(const ValueKey('portfolio_remote_update')), findsNothing);
    expect(repository.savedNotes, isEmpty);
  });

  test(
    'Metadata acknowledgments preserve dirty input without conflict warning',
    () async {
      final repository = _SyncRepository(_draft('Stored', pending: true));
      final container = _scope(repository);
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      await controller.load();
      controller.editNotes('Dirty');
      repository.receive(_draft('Stored', pending: false));
      await _flush(container);
      final state = container.read(portfolioDraftControllerProvider);
      expect(state.notes, 'Dirty');
      expect(state.draft!.pendingSync, isFalse);
      expect(state.remoteUpdateAvailable, isFalse);
      expect(state.canSave, isTrue);
    },
  );

  test(
    'Clean notes and Builder content follow remote durable changes',
    () async {
      final repository = _SyncRepository(
        _draft('Stored', content: _content('Stored')),
      );
      final container = _scope(repository);
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      await controller.load();
      repository.receive(
        _draft('Remote', revision: 2, content: _content('Remote')),
      );
      await _flush(container);
      final state = container.read(portfolioDraftControllerProvider);
      expect(state.notes, 'Remote');
      expect(state.content, _content('Remote'));
      expect(state.hasUnsavedChanges, isFalse);
      expect(state.remoteUpdateAvailable, isFalse);
    },
  );

  test(
    'A durable event during initial read wins over its earlier snapshot',
    () async {
      final oldRead = Completer<PortfolioDraft?>();
      final repository = _SyncRepository(_draft('Old'))..readResult = oldRead;
      final container = _scope(repository);
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      final load = controller.load();
      repository.receive(_draft('Fresh remote', revision: 2));
      await Future<void>.delayed(Duration.zero);
      oldRead.complete(_draft('Old'));
      await load;
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'Fresh remote',
      );
    },
  );

  test(
    'UID changes isolate draft and cloud status and cancel old subscriptions',
    () async {
      final auth = _AccountAuth();
      final first = _SyncRepository(_draft('Account A'));
      final second = _SyncRepository(_draft('Account B'));
      first.setSync(PortfolioSyncStatus.synced);
      second.setSync(PortfolioSyncStatus.error);
      final container = ProviderContainer(
        overrides: [
          accountAuthRepositoryProvider.overrideWithValue(auth),
          portfolioDraftRepositoryFactoryProvider.overrideWithValue(
            (uid) => uid == 'a' ? first : second,
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.close);
      container.listen(portfolioDraftControllerProvider, (_, _) {});
      container.listen(portfolioSyncStateProvider, (_, _) {});
      await _flush(container);
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'Account A',
      );
      container
          .read(portfolioDraftControllerProvider.notifier)
          .editNotes('Private A');
      auth.switchTo('b');
      await _flush(container);
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'Account B',
      );
      expect(
        container.read(portfolioSyncStateProvider).status,
        PortfolioSyncStatus.error,
      );
      expect(first.disposals, 1);
      expect(first.draftCancellations, 1);
      first.receive(_draft('Stale A update'));
      first.setSync(PortfolioSyncStatus.synced);
      await _flush(container);
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'Account B',
      );
      expect(
        container.read(portfolioSyncStateProvider).status,
        PortfolioSyncStatus.error,
      );
    },
  );

  test(
    'An auth emission for the same UID retains the repository and dirty input',
    () async {
      final auth = _AccountAuth();
      final repository = _SyncRepository(_draft('Stored'));
      var creations = 0;
      final container = ProviderContainer(
        overrides: [
          accountAuthRepositoryProvider.overrideWithValue(auth),
          portfolioDraftRepositoryFactoryProvider.overrideWithValue((uid) {
            creations++;
            return repository;
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.close);
      container.listen(portfolioDraftControllerProvider, (_, _) {});
      await _flush(container);
      container
          .read(portfolioDraftControllerProvider.notifier)
          .editNotes('Unsaved work');
      auth.switchTo('a');
      await _flush(container);
      expect(creations, 1);
      expect(repository.disposals, 0);
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'Unsaved work',
      );
      expect(
        container.read(portfolioDraftControllerProvider).hasUnsavedChanges,
        isTrue,
      );
    },
  );

  testWidgets('Configured guests clearly show device-only persistence', (
    tester,
  ) async {
    final repository = _PlainRepository();
    final auth = _AccountAuth()..user = null;
    addTearDown(auth.close);
    await tester.pumpWidget(
      StackCardApp(
        initialLocation: '/portfolio-draft',
        providerOverrides: [
          accountAuthRepositoryProvider.overrideWithValue(auth),
          accountSessionProvider.overrideWith((ref) => Stream.value(null)),
          guestAccessProvider.overrideWith(() => _GuestAccess()),
          portfolioDraftRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/portfolio-draft');
    await tester.pumpAndSettle();
    expect(find.text('Только на этом устройстве'), findsOneWidget);
    expect(find.byKey(_syncRetry), findsNothing);
  });

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    for (final size in [const Size(320, 640), const Size(844, 390)]) {
      testWidgets(
        'Sync error and remote conflict support $theme $size large text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final repository = _SyncRepository(_draft('Stored'));
          repository.setSync(PortfolioSyncStatus.error);
          await tester.pumpWidget(
            StackCardApp(
              initialThemeMode: theme,
              initialLocation: '/portfolio-draft',
              providerOverrides: [
                portfolioDraftRepositoryProvider.overrideWithValue(repository),
              ],
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(_notesField, 'Newer unsaved input');
          repository.receive(_draft('Other device', revision: 2));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(_syncRetry));
          expect(find.byKey(_syncRetry), findsOneWidget);
          expect(find.text('Сохранить мою версию'), findsOneWidget);
          expect(_notes(tester), 'Newer unsaved input');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

const _syncStatus = ValueKey('portfolio_sync_status');
const _syncRetry = ValueKey('portfolio_sync_retry');
const _notesSave = ValueKey('portfolio_draft_save');
final _notesField = find.descendant(
  of: find.byKey(const ValueKey('portfolio_draft_notes')),
  matching: find.byType(TextFormField),
);

String _notes(WidgetTester tester) =>
    tester.widget<TextFormField>(_notesField).controller!.text;

Future<void> _open(
  WidgetTester tester,
  PortfolioDraftRepository repository,
) async {
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: '/portfolio-draft',
      providerOverrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _scope(PortfolioDraftRepository repository) {
  final container = ProviderContainer(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  container.listen(portfolioDraftControllerProvider, (_, _) {});
  return container;
}

Future<void> _flush(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await container.pump();
  await Future<void>.delayed(Duration.zero);
  await container.pump();
}

PortfolioContent _content(String name) =>
    PortfolioContent(profile: PortfolioProfile(name: name));

PortfolioDraft _draft(
  String notes, {
  int revision = 1,
  PortfolioContent? content,
  bool pending = false,
}) => PortfolioDraft(
  notes: notes,
  revision: revision,
  updatedAt: DateTime.utc(2026, 10, 4),
  pendingSync: pending,
  content: content,
);

class _SyncRepository implements SyncPortfolioDraftRepository {
  _SyncRepository(this.current) {
    addTearDown(() async {
      await drafts.close();
      await syncs.close();
    });
  }
  PortfolioDraft? current;
  Completer<PortfolioDraft?>? readResult;
  int retries = 0;
  int disposals = 0;
  int draftCancellations = 0;
  final savedNotes = <String>[];
  final expectedRevisions = <int>[];
  late final drafts = StreamController<PortfolioDraft?>.broadcast(
    onCancel: () => draftCancellations++,
  );
  final syncs = StreamController<PortfolioSyncState>.broadcast();
  @override
  PortfolioSyncState syncState = const PortfolioSyncState(
    status: PortfolioSyncStatus.synced,
  );

  void receive(PortfolioDraft? draft) {
    current = draft;
    drafts.add(draft);
  }

  void setSync(PortfolioSyncStatus status) {
    syncState = PortfolioSyncState(
      status: status,
      failure: status == PortfolioSyncStatus.error
          ? const PortfolioSyncFailure(PortfolioSyncFailureKind.network)
          : null,
    );
    syncs.add(syncState);
  }

  @override
  Stream<PortfolioDraft?> watchDraft() => drafts.stream;
  @override
  Stream<PortfolioSyncState> watchSyncState() => Stream.multi((controller) {
    controller.add(syncState);
    final subscription = syncs.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });
  @override
  Future<PortfolioDraft?> read() async =>
      readResult == null ? current : await readResult!.future;
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    expectedRevisions.add(expectedRevision);
    return _save(notes, content);
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) async =>
      _save(notes, current?.content);

  PortfolioDraft _save(String notes, PortfolioContent? content) {
    savedNotes.add(notes);
    final draft = _draft(
      notes,
      revision: (current?.revision ?? 0) + 1,
      content: content,
      pending: true,
    );
    receive(draft);
    setSync(PortfolioSyncStatus.pending);
    return draft;
  }

  @override
  Future<void> retry() async {
    retries++;
    setSync(PortfolioSyncStatus.synced);
  }

  @override
  Future<void> dispose() async => disposals++;
}

class _PlainRepository implements PortfolioDraftRepository {
  @override
  Future<PortfolioDraft?> read() async => null;
  @override
  Future<PortfolioDraft> saveNotes(String notes) async => _draft(notes);
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async => _draft(notes, content: content);
}

class _GuestAccess extends GuestAccessController {
  @override
  bool build() => true;
}

class _AccountAuth implements AccountAuthRepository {
  AuthUser? user = const AuthUser(uid: 'a');
  final sessions = StreamController<AuthUser?>.broadcast();
  void switchTo(String uid) {
    user = AuthUser(uid: uid);
    sessions.add(user);
  }

  Future<void> close() => sessions.close();
  @override
  Stream<AuthUser?> watchSession() => Stream.multi((controller) {
    controller.add(user);
    final subscription = sessions.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });
  @override
  Future<void> signOut() async {}
  @override
  Future<void> signInEmail(String email, String password) async {}
  @override
  Future<void> registerEmail(String email, String password) async {}
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}
