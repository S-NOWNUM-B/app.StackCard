import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/main.dart';
import 'package:app_stackcard/shared/widgets/stackcard_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SessionRepository implements AccountAuthRepository {
  _SessionRepository([this.current]);
  AuthUser? current;
  bool emitInitial = true;
  final changes = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> watchSession() => Stream.multi((controller) {
    if (emitInitial) controller.add(current);
    final subscription = changes.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });

  void emit(AuthUser? user) {
    current = user;
    changes.add(user);
  }

  @override
  Future<void> signInEmail(String email, String password) async =>
      emit(AuthUser(uid: 'a', email: email));
  @override
  Future<void> registerEmail(String email, String password) =>
      signInEmail(email, password);
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signInGoogle() async => emit(const AuthUser(uid: 'a'));
  @override
  Future<void> signOut() async => emit(null);
}

class _DelayedNotesRepository implements PortfolioDraftRepository {
  _DelayedNotesRepository(this.source);
  final MemoryPortfolioDraftRepository source;
  final completion = Completer<void>();
  @override
  Future<PortfolioDraft?> read() => source.read();
  @override
  Future<PortfolioDraft> saveNotes(String notes) async {
    await completion.future;
    return source.saveNotes(notes);
  }

  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) => source.save(content, expectedRevision: expectedRevision, notes: notes);
}

Future<MemoryPortfolioDraftRepository> _seed(String notes, String name) async {
  final repository = MemoryPortfolioDraftRepository();
  if (name.isEmpty) {
    await repository.saveNotes(notes);
  } else {
    await repository.save(
      PortfolioContent(profile: PortfolioProfile(name: name)),
      expectedRevision: 0,
      notes: notes,
    );
  }
  return repository;
}

Future<void> _pumpApp(
  WidgetTester tester,
  _SessionRepository auth,
  Map<String?, PortfolioDraftRepository> drafts, {
  String location = '/home',
  Key? key,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await auth.changes.close();
  });
  await tester.pumpWidget(
    StackCardApp(
      key: key,
      initialLocation: location,
      providerOverrides: [
        accountAuthRepositoryProvider.overrideWithValue(auth),
        portfolioDraftRepositoryFactoryProvider.overrideWithValue(
          (uid) => drafts.putIfAbsent(uid, MemoryPortfolioDraftRepository.new),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _scope(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).last));

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));

String _notes(WidgetTester tester) => tester
    .widget<StackCardInput>(find.byType(StackCardInput).last)
    .controller!
    .text;

Future<void> _openNotes(WidgetTester tester) async {
  _router(tester).goNamed('portfolioDraft');
  await tester.pumpAndSettle();
}

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

  testWidgets(
    'Unauthorized nested editor keeps return destination and email session opens it',
    (tester) async {
      final auth = _SessionRepository();
      await _pumpApp(tester, auth, {}, location: '/portfolio/builder/profile');
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(
        _router(tester)
            .routeInformationProvider
            .value
            .uri
            .queryParameters['from'],
        '/portfolio/builder/profile',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('account.email')),
          matching: find.byType(TextFormField),
        ),
        'owner@example.com',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('account.password')),
          matching: find.byType(TextFormField),
        ),
        'secret',
      );
      await tester.ensureVisible(find.byKey(const Key('account.submit')));
      await tester.tap(find.byKey(const Key('account.submit')));
      await tester.pumpAndSettle();
      expect(find.byType(PortfolioProfileEditorScreen), findsOneWidget);
      expect(
        _router(tester).routeInformationProvider.value.uri.path,
        '/portfolio/builder/profile',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Named project edit redirects with id and query intact before authentication',
    (tester) async {
      final auth = _SessionRepository();
      await _pumpApp(tester, auth, {});
      _router(tester).goNamed(
        'editProject',
        pathParameters: {'id': 'private-project'},
        queryParameters: {'section': 'details'},
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(
        _router(tester)
            .routeInformationProvider
            .value
            .uri
            .queryParameters['from'],
        '/projects/private-project/edit?section=details',
      );
      expect(find.byType(PortfolioProjectEditorScreen), findsNothing);
    },
  );

  for (final destination in [
    'https://example.com/private',
    '//example.com',
    '/sign-in',
  ]) {
    testWidgets(
      'Restored account rejects unsafe return destination $destination',
      (tester) async {
        final auth = _SessionRepository(const AuthUser(uid: 'a'));
        final drafts = <String?, PortfolioDraftRepository>{
          'a': await _seed('A notes', 'A owner'),
        };
        await _pumpApp(
          tester,
          auth,
          drafts,
          location: Uri(
            path: '/sign-in',
            queryParameters: {'from': destination},
          ).toString(),
        );
        expect(
          _router(tester).routeInformationProvider.value.uri.path,
          '/home',
        );
        expect(find.byType(SignInScreen), findsNothing);
      },
    );
  }

  testWidgets(
    'Direct account switch replaces private notes/content and resets project filters',
    (tester) async {
      final auth = _SessionRepository(const AuthUser(uid: 'a'));
      final drafts = <String?, PortfolioDraftRepository>{
        'a': await _seed('Private notes A', 'Owner A'),
        'b': await _seed('Private notes B', 'Owner B'),
      };
      await _pumpApp(tester, auth, drafts, location: '/portfolio-draft');
      expect(_notes(tester), 'Private notes A');
      final scope = _scope(tester);
      scope.read(projectFiltersProvider.notifier).setQuery('A-only query');
      auth.emit(const AuthUser(uid: 'b'));
      await tester.pumpAndSettle();
      expect(find.text('Owner A'), findsNothing);
      expect(scope.read(projectFiltersProvider).query, isEmpty);
      await _openNotes(tester);
      expect(_notes(tester), 'Private notes B');
      expect(
        scope.read(portfolioDraftControllerProvider).content!.profile.name,
        'Owner B',
      );
      expect(find.text('Private notes A'), findsNothing);
    },
  );

  testWidgets(
    'Sign-out locks private routes; explicit guest opens only the guest draft',
    (tester) async {
      final auth = _SessionRepository(const AuthUser(uid: 'a'));
      final drafts = <String?, PortfolioDraftRepository>{
        'a': await _seed('Account secret', 'Owner A'),
        null: await _seed('Guest-only notes', 'Guest owner'),
      };
      await _pumpApp(tester, auth, drafts, location: '/portfolio-draft');
      expect(_notes(tester), 'Account secret');
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Account secret'), findsNothing);
      _router(tester).goNamed('portfolioDraft');
      await tester.pumpAndSettle();
      expect(find.byType(PortfolioDraftScreen), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('account.guest')));
      await tester.tap(find.byKey(const Key('account.guest')));
      await tester.pumpAndSettle();
      await _openNotes(tester);
      expect(_notes(tester), 'Guest-only notes');
      expect(
        _scope(tester)
            .read(portfolioDraftControllerProvider)
            .content!
            .profile
            .name,
        'Guest owner',
      );
      expect(find.text('Account secret'), findsNothing);
    },
  );

  testWidgets(
    'Late save for account A cannot replace current account B draft',
    (tester) async {
      final auth = _SessionRepository(const AuthUser(uid: 'a'));
      final delayed = _DelayedNotesRepository(await _seed('Old A', ''));
      final drafts = <String?, PortfolioDraftRepository>{
        'a': delayed,
        'b': await _seed('B private', 'Owner B'),
      };
      await _pumpApp(tester, auth, drafts, location: '/portfolio-draft');
      final scope = _scope(tester);
      final controller = scope.read(portfolioDraftControllerProvider.notifier);
      controller.editNotes('New unsaved A');
      final saving = controller.save();
      await tester.pump();
      auth.emit(const AuthUser(uid: 'b'));
      await tester.pumpAndSettle();
      await _openNotes(tester);
      expect(_notes(tester), 'B private');
      delayed.completion.complete();
      await saving;
      await tester.pumpAndSettle();
      expect(_notes(tester), 'B private');
      expect(
        scope.read(portfolioDraftControllerProvider).content!.profile.name,
        'Owner B',
      );
      expect((await delayed.read())!.notes, 'New unsaved A');
      expect(find.text('New unsaved A'), findsNothing);
    },
  );

  testWidgets(
    'Guest editor input cannot be applied to a newly restored account',
    (tester) async {
      final auth = _SessionRepository();
      final drafts = <String?, PortfolioDraftRepository>{
        null: await _seed('Guest notes', 'Guest owner'),
        'a': await _seed('A notes', 'Owner A'),
      };
      await _pumpApp(tester, auth, drafts);
      await tester.ensureVisible(find.byKey(const Key('account.guest')));
      await tester.tap(find.byKey(const Key('account.guest')));
      await tester.pumpAndSettle();
      _router(tester).goNamed('editProfile');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('builder_form_name')),
        'PRIVATE GUEST FIELD',
      );
      auth.emit(const AuthUser(uid: 'a'));
      await tester.pumpAndSettle();
      expect(find.byType(PortfolioProfileEditorScreen), findsNothing);
      expect(find.text('PRIVATE GUEST FIELD'), findsNothing);
      expect(
        _scope(tester)
            .read(portfolioDraftControllerProvider)
            .content!
            .profile
            .name,
        'Owner A',
      );
      expect((await drafts['a']!.read())!.content!.profile.name, 'Owner A');
      _router(tester).goNamed('editProfile');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StackCardInput>(
              find.byKey(const ValueKey('builder_form_name')),
            )
            .controller!
            .text,
        'Owner A',
      );
    },
  );

  testWidgets(
    'Account switch removes an imperative editor dialog containing private input',
    (tester) async {
      final auth = _SessionRepository(const AuthUser(uid: 'a'));
      final drafts = <String?, PortfolioDraftRepository>{
        'a': await _seed('A notes', 'Owner A'),
        'b': await _seed('B notes', 'Owner B'),
      };
      await _pumpApp(
        tester,
        auth,
        drafts,
        location: '/portfolio/builder/skills',
      );
      final add = find.byKey(const ValueKey('builder_collection_add'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'PRIVATE A DIALOG',
      );
      auth.emit(const AuthUser(uid: 'b'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('PRIVATE A DIALOG'), findsNothing);
      expect(
        _scope(tester)
            .read(portfolioDraftControllerProvider)
            .content!
            .profile
            .name,
        'Owner B',
      );
    },
  );

  testWidgets(
    'Restored SDK session reopens the owner draft after a new app session',
    (tester) async {
      final auth = _SessionRepository(const AuthUser(uid: 'a'));
      final drafts = <String?, PortfolioDraftRepository>{
        'a': await _seed('Durable A notes', 'Owner A'),
      };
      await _pumpApp(
        tester,
        auth,
        drafts,
        location: '/portfolio-draft',
        key: const ValueKey('first-app'),
      );
      expect(_notes(tester), 'Durable A notes');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        StackCardApp(
          key: const ValueKey('restarted-app'),
          initialLocation: '/portfolio-draft',
          providerOverrides: [
            accountAuthRepositoryProvider.overrideWithValue(auth),
            portfolioDraftRepositoryFactoryProvider.overrideWithValue(
              (uid) =>
                  drafts.putIfAbsent(uid, MemoryPortfolioDraftRepository.new),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsNothing);
      expect(_notes(tester), 'Durable A notes');
    },
  );

  testWidgets(
    'Session error and restoration hide old private content until a new session arrives',
    (tester) async {
      final auth = _SessionRepository(const AuthUser(uid: 'a'));
      final drafts = <String?, PortfolioDraftRepository>{
        'a': await _seed('A secret', 'Owner A'),
        'b': await _seed('B secret', 'Owner B'),
      };
      await _pumpApp(tester, auth, drafts, location: '/portfolio-draft');
      final scope = _scope(tester);
      auth.emitInitial = false;
      auth.changes.addError(const AuthFailure(AuthFailureKind.network));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(PortfolioDraftScreen), findsNothing);
      expect(find.text('A secret'), findsNothing);
      expect(scope.read(portfolioDraftControllerProvider).content, isNull);
      scope.invalidate(accountSessionProvider);
      await tester.pump(const Duration(milliseconds: 200));
      expect(scope.read(accountSessionProvider).isLoading, isTrue);
      expect(find.byType(PortfolioDraftScreen), findsNothing);
      expect(find.text('A secret'), findsNothing);
      auth.emit(const AuthUser(uid: 'b'));
      await tester.pumpAndSettle();
      await _openNotes(tester);
      expect(_notes(tester), 'B secret');
    },
  );
}
