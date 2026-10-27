import 'dart:async';
import 'dart:typed_data';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/synced_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

// Регрессии ревью main editor: потеря облачного draft, ложный dirty,
// tombstone, устаревший чистый редактор, сдвиг часов и dialogs при text2.
void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('fresh synced device', () {
    var boxIndex = 0;

    Future<(SyncedPortfolioDraftRepository, _Remote)> synced(
      WidgetTester tester,
    ) async {
      final box = (await tester.runAsync(
        () => Hive.openBox<dynamic>(
          'editor-regression-${boxIndex++}',
          bytes: Uint8List(0),
        ),
      ))!;
      final remote = _Remote();
      final repository = SyncedPortfolioDraftRepository(
        ownerUid: 'u1',
        local: LocalDraftAccounts(box).repositoryForUser('u1'),
        metadata: HivePortfolioSyncMetadataStore(box, ownerUid: 'u1'),
        remote: remote,
      );
      addTearDown(() async {
        await repository.dispose();
        await tester.runAsync(box.close);
      });
      return (repository, remote);
    }

    testWidgets('waits for the server instead of overwriting the cloud draft', (
      tester,
    ) async {
      final (repository, remote) = await synced(tester);
      final container = await _open(tester, repository, settle: false);
      await _settleAsync(tester);

      // Пустой Hive нового устройства не подтверждает пустой аккаунт.
      expect(remote.writes, isEmpty);
      expect(find.text('Загрузка'), findsOneWidget);
      remote.emit(null, fromCache: true);
      await _settleAsync(tester);
      expect(remote.writes, isEmpty);

      remote.emit(
        CloudPortfolioDraft(
          ownerUid: 'u1',
          mutationId: 'cloud-existing',
          localRevision: 7,
          notes: 'cloud notes',
          content: _workspace(name: 'Облако'),
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
      );
      await _settleAsync(tester);

      expect(remote.writes, isEmpty);
      expect(_value(tester, 'main.editor.name'), 'Облако');
      final saved = container.read(portfolioDraftControllerProvider).draft;
      expect(saved?.notes, 'cloud notes');
      expect(
        mainPortfolioDocument(saved!.content!)!.content.profile.name,
        'Облако',
      );
    });

    testWidgets('initializes main after the server confirms an empty account', (
      tester,
    ) async {
      final (repository, remote) = await synced(tester);
      await _open(tester, repository, settle: false);
      await _settleAsync(tester);
      expect(remote.writes, isEmpty);

      remote.emit(null);
      await _settleAsync(tester);

      expect(remote.writes, hasLength(1));
      expect(remote.writes.single.content?.mainPortfolioId, isNotNull);
      expect(find.byKey(const Key('main.editor.name')), findsOneWidget);
    });
  });

  testWidgets('focusing a field without typing keeps the editor clean', (
    tester,
  ) async {
    final container = await _open(tester, await _repository(name: 'Стас'));
    final field = find.descendant(
      of: find.byKey(const Key('main.editor.name')),
      matching: find.byType(TextFormField),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('main.editor.headline')),
        matching: find.byType(TextFormField),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(portfolioDraftControllerProvider).hasUnsavedChanges,
      isFalse,
    );
    expect(find.text('Есть несохранённые изменения'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tombstone of an absent document leaves the editor savable', (
    tester,
  ) async {
    final repository = await _repository(name: 'Стас');
    final container = await _open(tester, repository);
    container
        .read(portfolioDraftControllerProvider.notifier)
        .acceptConfirmedDocumentDeletion(
          'long-gone',
          expectedRepository: repository,
        );
    await tester.pumpAndSettle();

    final state = container.read(portfolioDraftControllerProvider);
    expect(state.remoteUpdateAvailable, isFalse);
    expect(state.hasUnsavedChanges, isFalse);
    expect(find.textContaining('Сохранённая версия изменилась'), findsNothing);

    await _enter(tester, 'name', 'Новое имя');
    await tester.tap(find.byKey(const Key('main.editor.save')));
    await tester.pumpAndSettle();
    final saved = (await repository.read())!.content!;
    expect(mainPortfolioDocument(saved)!.content.profile.name, 'Новое имя');
  });

  testWidgets('clean editor follows a saved main change without a conflict', (
    tester,
  ) async {
    final repository = await _repository(
      name: 'Стас',
      projects: [_project],
      attachments: const [PortfolioProjectAttachment(projectId: 'p1')],
    );
    final container = await _open(tester, repository);
    final row = find.byKey(
      const Key('main.editor.project.p1'),
      skipOffstage: false,
    );
    await _ensureVisible(tester, row);
    expect(tester.widget(row), isNot(isA<SizedBox>()));

    final deleted = await container
        .read(portfolioDraftControllerProvider.notifier)
        .deleteProject(_project, expectedRepository: repository);
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.textContaining('Сохранённая версия изменилась'), findsNothing);
    expect(row, findsNothing);
    await _enter(tester, 'name', 'После удаления');
    await tester.tap(find.byKey(const Key('main.editor.save')));
    await tester.pumpAndSettle();
    final saved = (await repository.read())!.content!;
    expect(
      mainPortfolioDocument(saved)!.content.profile.name,
      'После удаления',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dirty editor keeps input and conflict; dialogs scroll at text2',
    (tester) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(320, 640);
      final repository = await _repository(
        name: 'Стас',
        projects: [_project],
        attachments: const [PortfolioProjectAttachment(projectId: 'p1')],
      );
      final container = await _open(tester, repository, textScale: 2);
      await _enter(tester, 'name', 'Ввод');

      await container
          .read(portfolioDraftControllerProvider.notifier)
          .deleteProject(_project, expectedRepository: repository);
      await tester.pumpAndSettle();

      expect(_value(tester, 'main.editor.name'), 'Ввод');
      expect(
        find.byKey(const Key('main.editor.project.p1'), skipOffstage: false),
        findsOneWidget,
      );
      final reload = find.text('Открыть сохранённую версию');
      await _ensureVisible(tester, reload);
      await tester.tap(reload);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop(false);
      await tester.pumpAndSettle();
      expect(_value(tester, 'main.editor.name'), 'Ввод');

      final leave = container.read(mainPortfolioEditorNavigationProvider)!;
      unawaited(leave());
      await tester.pumpAndSettle();
      expect(find.text('Сохранить изменения?'), findsOneWidget);
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('save succeeds when the device clock is before createdAt', (
    tester,
  ) async {
    final future = DateTime.now().toUtc().add(const Duration(days: 2));
    final repository = await _repository(name: 'Стас', createdAt: future);
    final container = await _open(tester, repository);
    await _enter(tester, 'name', 'Часы');
    await tester.tap(find.byKey(const Key('main.editor.save')));
    await tester.pumpAndSettle();

    expect(find.text('Изменения сохранены'), findsOneWidget);
    final main = mainPortfolioDocument((await repository.read())!.content!)!;
    expect(main.content.profile.name, 'Часы');
    expect(main.updatedAt.isBefore(main.createdAt), isFalse);

    final stepSaved = await container
        .read(portfolioDraftControllerProvider.notifier)
        .savePersonalizationStep(
          step: 1,
          status: PortfolioPersonalizationStatus.inProgress,
          profile: const PortfolioProfile(name: 'Шаг'),
          expectedRepository: repository,
        );
    expect(stepSaved, isTrue);
  });
}

final _project = PortfolioProject(
  id: 'p1',
  title: 'Проект',
  description: '',
  technologies: const [],
);

PortfolioContent _workspace({
  String name = '',
  DateTime? createdAt,
  List<PortfolioProject> projects = const [],
  List<PortfolioProjectAttachment> attachments = const [],
}) {
  final created = createdAt ?? DateTime.utc(2026, 10, 11);
  return PortfolioContent(
    mainPortfolioId: 'main',
    projects: projects,
    documents: [
      PortfolioDocument(
        id: 'main',
        title: 'Основное',
        kind: PortfolioDocumentKind.portfolio,
        createdAt: created,
        updatedAt: created,
        content: PortfolioContent(profile: PortfolioProfile(name: name)),
        projects: attachments,
      ),
    ],
  );
}

Future<MemoryPortfolioDraftRepository> _repository({
  String name = '',
  DateTime? createdAt,
  List<PortfolioProject> projects = const [],
  List<PortfolioProjectAttachment> attachments = const [],
}) async {
  final repository = MemoryPortfolioDraftRepository();
  await repository.save(
    _workspace(
      name: name,
      createdAt: createdAt,
      projects: projects,
      attachments: attachments,
    ),
    expectedRevision: 0,
    notes: '',
  );
  return repository;
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  PortfolioDraftRepository repository, {
  double textScale = 1,
  bool settle = true,
}) async {
  final container = ProviderContainer(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/editor',
    routes: [
      GoRoute(
        path: '/editor',
        builder: (_, _) => const MainPortfolioEditorScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Главная')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: StackCardTheme.light,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return container;
}

/// Hive и outbox работают на реальном event loop; loading indicator не даёт
/// pumpAndSettle, поэтому кадры прокачиваются ограниченно.
Future<void> _settleAsync(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _ensureVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const Key('main.editor.scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  if (finder.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: scrollable,
      maxScrolls: 200,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String field, String value) async {
  final finder = find.descendant(
    of: find.byKey(ValueKey('main.editor.$field')),
    matching: find.byType(TextFormField),
  );
  await _ensureVisible(tester, finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

String _value(WidgetTester tester, String key) => tester
    .widget<TextFormField>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextFormField),
      ),
    )
    .controller!
    .text;

final class _Remote implements RemotePortfolioDraftRepository {
  final writes = <CloudPortfolioDraft>[];
  final _events = StreamController<DraftRemoteEvent>.broadcast();

  void emit(CloudPortfolioDraft? draft, {bool fromCache = false}) =>
      _events.add(
        DraftRemoteEvent(
          draft: draft,
          fromCache: fromCache,
          hasPendingWrites: false,
        ),
      );

  @override
  Stream<DraftRemoteEvent> watch() => _events.stream;

  @override
  Future<void> write(CloudPortfolioDraft draft) async => writes.add(draft);
}
