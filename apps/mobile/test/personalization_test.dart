import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:app_stackcard/shared/widgets/stackcard_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Accounts
    implements AccountAuthRepository, AccountAuthCreationRepository {
  final sessions = StreamController<AuthUser?>.broadcast();
  AuthUser? user = const AuthUser(uid: 'owner', email: 'private@example.dev');
  bool isNew = true;
  Completer<void>? pending;

  @override
  Stream<AuthUser?> watchSession() async* {
    yield user;
    yield* sessions.stream;
  }

  @override
  Future<void> signInEmail(String email, String password) async {}
  @override
  Future<void> registerEmail(String email, String password) async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<AccountAuthResult> registerEmailWithResult(
    String email,
    String password,
  ) async {
    if (pending != null) await pending!.future;
    return AccountAuthResult(uid: 'owner', isNewUser: isNew);
  }

  @override
  Future<AccountAuthResult> signInGoogleWithResult() =>
      registerEmailWithResult('', '');
}

class _Workspace implements PortfolioDraftRepository {
  final store = MemoryPortfolioDraftRepository();
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<PortfolioDraft?> read() => store.read();
  @override
  Future<PortfolioDraft> saveNotes(String notes) => store.saveNotes(notes);
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    if (pending != null) await pending!.future;
    if (fail) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.unavailable);
    }
    return store.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Accounts accounts,
  _Workspace repository, {
  bool newAccount = true,
  double scale = 1,
  Map<String, _Workspace>? otherRepositories,
}) async {
  final others = otherRepositories ?? <String, _Workspace>{};
  final container = ProviderContainer(
    overrides: [
      accountAuthRepositoryProvider.overrideWithValue(accounts),
      portfolioDraftRepositoryFactoryProvider.overrideWithValue(
        (uid) => uid == 'owner'
            ? repository
            : others.putIfAbsent(uid ?? '', _Workspace.new),
      ),
    ],
  );
  if (newAccount) {
    container.read(pendingPersonalizationUidProvider.notifier).request('owner');
  }
  final router = GoRouter(
    initialLocation: '/personalization',
    routes: [
      GoRoute(
        path: '/personalization',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
            final session = ref.watch(accountSessionProvider);
            return session.isLoading
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : const PersonalizationScreen();
          },
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) =>
            const Scaffold(body: Text('Главная готова')),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    container.dispose();
    await accounts.sessions.close();
  });
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
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final field = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextFormField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

void main() {
  test('Only explicit new-account outcomes queue personalization', () async {
    final accounts = _Accounts();
    final container = ProviderContainer(
      overrides: [accountAuthRepositoryProvider.overrideWithValue(accounts)],
    );
    addTearDown(() async {
      container.dispose();
      await accounts.sessions.close();
    });
    final controller = container.read(accountAuthControllerProvider.notifier);
    accounts.isNew = false;
    expect(await controller.signInGoogle(), isTrue);
    expect(container.read(pendingPersonalizationUidProvider), isNull);
    accounts.isNew = true;
    expect(await controller.signInGoogle(), isTrue);
    expect(container.read(pendingPersonalizationUidProvider), 'owner');
    container
        .read(pendingPersonalizationUidProvider.notifier)
        .complete('other');
    expect(container.read(pendingPersonalizationUidProvider), 'owner');
    container
        .read(pendingPersonalizationUidProvider.notifier)
        .complete('owner');
    expect(
      await controller.registerEmail('private@example.dev', 'phrase'),
      isTrue,
    );
    expect(container.read(pendingPersonalizationUidProvider), 'owner');
  });

  testWidgets(
    'Next allows four empty steps without public identity or contact',
    (tester) async {
      final repository = _Workspace();
      final container = await _pump(tester, _Accounts(), repository);
      expect(container.read(pendingPersonalizationUidProvider), isNull);
      expect(find.text('Шаг 1 из 4'), findsOneWidget);
      expect(find.text('Пропустить'), findsNothing);
      expect(
        tester
            .widget<StackCardButton>(
              find.byKey(const Key('personalization.back')),
            )
            .onPressed,
        isNull,
      );
      for (var step = 0; step < 4; step++) {
        await _tap(tester, 'personalization.next');
      }
      expect(find.text('Главная готова'), findsOneWidget);
      final workspace = (await repository.read())!.content!;
      expect(
        workspace.personalization.status,
        PortfolioPersonalizationStatus.completed,
      );
      expect(workspace.githubUsername, isEmpty);
      final profile = resolvedMainPortfolioContent(workspace)!.profile;
      expect(profile.name, isEmpty);
      expect(profile.headline, isEmpty);
      expect(profile.avatarPath, isEmpty);
      expect(
        mainPortfolioDocument(workspace)!.content.profile.publishLocation,
        isFalse,
      );
      expect(workspace.links, isEmpty);
    },
  );

  testWidgets('GitHub validates and normalizes; Next and Back persist fields', (
    tester,
  ) async {
    final repository = _Workspace();
    await _pump(tester, _Accounts(), repository);
    expect(
      tester
          .widget<StackCardInput>(
            find.byKey(const Key('personalization.github')),
          )
          .label,
      'GitHub-профиль',
    );
    await _enter(
      tester,
      'personalization.github',
      'https://github.com/owner/repository',
    );
    await _tap(tester, 'personalization.next');
    expect(
      find.text(
        'Введите имя пользователя или ссылку вида https://github.com/username',
      ),
      findsOneWidget,
    );
    expect(find.text('Шаг 1 из 4'), findsOneWidget);
    await _enter(
      tester,
      'personalization.github',
      'https://github.com/LINESKL',
    );
    expect(
      find.text(
        'Введите имя пользователя или ссылку вида https://github.com/username',
      ),
      findsNothing,
    );
    await _tap(tester, 'personalization.next');
    await _enter(tester, 'personalization.name', 'Стас');
    await _enter(tester, 'personalization.headline', 'Разработчик');
    await _enter(tester, 'personalization.location', 'Алматы / Казахстан');
    await _tap(tester, 'personalization.next');
    expect(find.byKey(const Key('personalization.location')), findsNothing);
    await _enter(tester, 'personalization.bio', 'Создаю приложения');
    await _tap(tester, 'personalization.back');
    expect(find.text('Шаг 2 из 4'), findsOneWidget);
    expect(find.text('Алматы / Казахстан'), findsOneWidget);
    final workspace = (await repository.read())!.content!;
    expect(workspace.githubUsername, 'lineskl');
    expect(workspace.projects, isEmpty);
    final profile = resolvedMainPortfolioContent(workspace)!.profile;
    expect(profile.name, 'Стас');
    expect(profile.bio, 'Создаю приложения');
    expect(profile.locationText, 'Алматы / Казахстан');
    expect(profile.publishLocation, isTrue);
    expect(workspace.links, isEmpty);
  });

  testWidgets(
    'A fresh session resumes the explicit saved step with empty profile',
    (tester) async {
      final repository = _Workspace();
      await _pump(tester, _Accounts(), repository);
      await _tap(tester, 'personalization.next');
      await _tap(tester, 'personalization.next');
      await tester.pumpWidget(const SizedBox());
      final saved = (await repository.read())!.content!;
      expect(saved.personalization.step, 2);
      await _pump(tester, _Accounts(), repository, newAccount: false);
      expect(find.text('Шаг 3 из 4'), findsOneWidget);
    },
  );

  testWidgets('Completed empty personalization opens Home on next session', (
    tester,
  ) async {
    final repository = _Workspace();
    await _pump(tester, _Accounts(), repository);
    for (var step = 0; step < 4; step++) {
      await _tap(tester, 'personalization.next');
    }
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, _Accounts(), repository, newAccount: false);
    expect(find.text('Главная готова'), findsOneWidget);
    expect(find.byKey(const Key('personalization.step')), findsNothing);
  });

  testWidgets('Next advances while keeping valid entered optional fields', (
    tester,
  ) async {
    final repository = _Workspace();
    await _pump(tester, _Accounts(), repository);
    await _enter(tester, 'personalization.github', 'SNOWNUMB');
    await _tap(tester, 'personalization.next');
    await _enter(tester, 'personalization.name', 'Стас');
    await _tap(tester, 'personalization.next');
    final workspace = (await repository.read())!.content!;
    expect(workspace.githubUsername, 'snownumb');
    expect(resolvedMainPortfolioContent(workspace)!.profile.name, 'Стас');
    expect(workspace.personalization.step, 2);
  });

  testWidgets(
    'Next with an unchanged resumed city preserves stored legacy privacy',
    (tester) async {
      final repository = _Workspace();
      final container = await _pump(tester, _Accounts(), repository);
      await container
          .read(portfolioDraftControllerProvider.notifier)
          .savePersonalizationStep(
            step: 1,
            status: PortfolioPersonalizationStatus.inProgress,
            profile: const PortfolioProfile(
              locationText: 'Сохранённый частный город',
            ),
            expectedRepository: repository,
          );
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, _Accounts(), repository, newAccount: false);
      expect(find.text('Сохранённый частный город'), findsOneWidget);
      await _tap(tester, 'personalization.next');
      expect(find.byKey(const Key('personalization.location')), findsNothing);
      await _tap(tester, 'personalization.next');
      final profile = mainPortfolioDocument(
        (await repository.read())!.content!,
      )!.content.profile;
      expect(profile.locationText, 'Сохранённый частный город');
      expect(profile.publishLocation, isFalse);
    },
  );

  testWidgets('Save failure keeps entered values and does not advance', (
    tester,
  ) async {
    final repository = _Workspace();
    await _pump(tester, _Accounts(), repository);
    await _tap(tester, 'personalization.next');
    await _enter(tester, 'personalization.name', 'Стас');
    repository.fail = true;
    await _tap(tester, 'personalization.next');
    expect(find.text('Шаг 2 из 4'), findsOneWidget);
    expect(
      tester
          .widget<StackCardInput>(find.byKey(const Key('personalization.name')))
          .controller!
          .text,
      'Стас',
    );
    expect(find.textContaining('Не удалось сохранить'), findsOneWidget);
    repository.fail = false;
    await _tap(tester, 'personalization.next');
    expect(find.text('Шаг 3 из 4'), findsOneWidget);
  });

  testWidgets('System Back can discard only this step without completing it', (
    tester,
  ) async {
    final repository = _Workspace();
    await _pump(tester, _Accounts(), repository);
    await _tap(tester, 'personalization.next');
    await _enter(tester, 'personalization.name', 'Несохранённое имя');
    await Navigator.of(tester.element(find.byType(PersonalizationScreen)))
        .maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Отменить изменения?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Несохранённое имя'), findsOneWidget);
    await Navigator.of(tester.element(find.byType(PersonalizationScreen)))
        .maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(find.text('Шаг 2 из 4'), findsOneWidget);
    expect(find.text('Несохранённое имя'), findsNothing);
    final workspace = (await repository.read())!.content!;
    expect(workspace.personalization.step, 1);
    expect(
      workspace.personalization.status,
      PortfolioPersonalizationStatus.inProgress,
    );
    expect(resolvedMainPortfolioContent(workspace)!.profile.name, isEmpty);
  });

  testWidgets('Scoped progress save leaves unrelated unsaved notes alone', (
    tester,
  ) async {
    final repository = _Workspace();
    final container = await _pump(tester, _Accounts(), repository);
    container
        .read(portfolioDraftControllerProvider.notifier)
        .updateNotes('Несохранённые заметки');
    await _tap(tester, 'personalization.next');
    expect((await repository.read())!.notes, isEmpty);
    expect(
      container.read(portfolioDraftControllerProvider).notes,
      'Несохранённые заметки',
    );
  });

  testWidgets('Late save cannot advance a screen after UID changes', (
    tester,
  ) async {
    final accounts = _Accounts();
    final repository = _Workspace();
    await _pump(tester, accounts, repository);
    repository.pending = Completer<void>();
    await tester.tap(find.byKey(const Key('personalization.next')));
    await tester.pump();
    accounts.sessions.add(
      const AuthUser(uid: 'other', email: 'other@example.dev'),
    );
    await tester.pump();
    repository.pending!.complete();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Шаг 2 из 4'), findsNothing);
    expect(find.byKey(const Key('personalization.github')), findsNothing);
  });

  testWidgets('A reused route resumes the new owner and destroys old input', (
    tester,
  ) async {
    final accounts = _Accounts();
    final repository = _Workspace();
    final other = _Workspace();
    final now = DateTime.utc(2026, 1, 1);
    const id = '0123456789abcdef0123456789abcdef';
    await other.save(
      PortfolioContent(
        mainPortfolioId: id,
        personalization: const PortfolioPersonalization(
          status: PortfolioPersonalizationStatus.inProgress,
          step: 2,
        ),
        documents: [
          PortfolioDocument(
            id: id,
            title: 'Портфолио',
            kind: PortfolioDocumentKind.portfolio,
            createdAt: now,
            updatedAt: now,
            content: PortfolioContent(
              profile: const PortfolioProfile(
                bio: 'Описание второго владельца',
              ),
            ),
          ),
        ],
      ),
      expectedRevision: 0,
      notes: '',
    );
    await _pump(
      tester,
      accounts,
      repository,
      otherRepositories: {'other': other},
    );
    await _enter(tester, 'personalization.github', 'PRIVATE_FIRST_OWNER');
    accounts.sessions.add(const AuthUser(uid: 'other'));
    await tester.pumpAndSettle();
    expect(find.text('Шаг 3 из 4'), findsOneWidget);
    expect(find.text('Описание второго владельца'), findsOneWidget);
    expect(find.text('PRIVATE_FIRST_OWNER'), findsNothing);
    await _tap(tester, 'personalization.next');
    expect(find.text('Шаг 4 из 4'), findsOneWidget);
    expect((await other.read())!.content!.personalization.step, 3);
    expect((await repository.read())!.content!.personalization.step, 0);
    expect((await repository.read())!.content!.githubUsername, isEmpty);
  });

  testWidgets(
    '320 width and text scale2 keep every action reachable with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, _Accounts(), _Workspace(), scale: 2);
      await _enter(tester, 'personalization.github', '');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      for (var step = 0; step < 4; step++) {
        final back = find.byKey(const Key('personalization.back'));
        final next = find.byKey(const Key('personalization.next'));
        await tester.ensureVisible(next);
        expect(tester.getTopLeft(back).dy, tester.getTopLeft(next).dy);
        expect(
          tester.getTopLeft(back).dx,
          lessThan(tester.getTopLeft(next).dx),
        );
        expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(next).height, greaterThanOrEqualTo(48));
        expect(find.text('Пропустить'), findsNothing);
        await _tap(tester, 'personalization.next');
      }
      expect(find.text('Главная готова'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
