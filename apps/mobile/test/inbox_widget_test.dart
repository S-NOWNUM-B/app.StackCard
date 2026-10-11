import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/inbox/inbox.dart';
import 'package:app_stackcard/features/notifications/notifications.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/inbox_fakes.dart';

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));
ProviderContainer _scope(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).last));
Future<void> _open(
  WidgetTester tester,
  TestAuth auth, {
  String location = '/home',
  Map<String, TestInbox> inboxes = const {},
  NotificationsController? notifications,
  PortfolioDraftRepository? draft,
  bool settle = true,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await auth.changes.close();
  });
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: location,
      providerOverrides: [
        accountAuthRepositoryProvider.overrideWithValue(auth),
        inboxRepositoryFactoryProvider.overrideWithValue((uid) => inboxes[uid]),
        notificationsControllerProvider.overrideWithValue(notifications),
        if (draft != null)
          portfolioDraftRepositoryFactoryProvider.overrideWithValue(
            (_) => draft,
          ),
      ],
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _drain(WidgetTester tester, Future<void> future) async {
  // SDK stream cancel использует real-zone Future; queue callbacks используют widget fake clock.
  var completed = false;
  future.whenComplete(() => completed = true).ignore();
  for (var i = 0; i < 20 && !completed; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  expect(
    completed,
    isTrue,
    reason: 'Async resource disposal must settle after fake-clock microtasks.',
  );
  await future;
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
    'Inbox is account-only for guest, keeps safe return destination and demo has no fake enquiries',
    (tester) async {
      final auth = TestAuth();
      await _open(tester, auth, location: '/inbox/$requestId');
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(
        _router(tester)
            .routeInformationProvider
            .value
            .uri
            .queryParameters['from'],
        '/inbox/$requestId',
      );
      _scope(tester).read(guestAccessProvider.notifier).enter();
      _router(tester).go('/inbox');
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(InboxScreen), findsNothing);
      auth.emit(const AuthUser(uid: 'a'));
      await tester.pumpAndSettle();
      _router(tester).go('/inbox');
      await tester.pumpAndSettle();
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(
        find.textContaining('Не удалось загрузить обращения'),
        findsOneWidget,
      );
      expect(find.text('Visitor'), findsNothing);
    },
  );
  testWidgets(
    'Settings opens standalone Inbox and Back retains three root destinations',
    (tester) async {
      final inbox = TestInbox('a');
      await _open(
        tester,
        TestAuth(const AuthUser(uid: 'a')),
        inboxes: {'a': inbox},
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(3),
      );
      expect(
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(NavigationBar),
                matching: find.byType(Text),
              ),
            )
            .map((label) => label.data),
        ['Главная', 'Проекты', 'Редактор'],
      );
      await _tap(tester, find.byKey(const Key('app.settings')));
      await _tap(tester, find.byKey(const Key('settings.group.inbox')));
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await _tap(tester, find.byKey(const Key('inbox.request.$requestId')));
      expect(find.byType(InboxRequestScreen), findsOneWidget);
      expect(
        find.text(
          'Электронная почта указана отправителем. Её принадлежность не подтверждена.',
        ),
        findsOneWidget,
      );
      _router(tester).pop();
      await tester.pumpAndSettle();
      _router(tester).pop();
      await tester.pumpAndSettle();
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(3),
      );
      expect(_router(tester).routeInformationProvider.value.uri.path, '/home');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'read failure retains unread request; explicit retry obtains server read acknowledgement',
    (tester) async {
      final inbox = TestInbox('a')
        ..readFailure = const InboxFailure(InboxFailureKind.network);
      await _open(
        tester,
        TestAuth(const AuthUser(uid: 'a')),
        location: '/inbox/$requestId',
        inboxes: {'a': inbox},
      );
      await _tap(tester, find.byKey(const Key('inbox.markRead')));
      expect(inbox.items.single.unread, isTrue);
      expect(find.byKey(const Key('inbox.markRead')), findsOneWidget);
      expect(
        find.textContaining('Не удалось связаться с сервером'),
        findsOneWidget,
      );
      inbox.readFailure = null;
      await _tap(tester, find.byKey(const Key('inbox.markRead')));
      expect(inbox.reads, 2);
      expect(inbox.items.single.unread, isFalse);
      expect(find.byKey(const Key('inbox.markRead')), findsNothing);
      expect(find.text('Прочитано'), findsOneWidget);
    },
  );
  testWidgets(
    'permission request is explicit, denial leaves Inbox available and foreground reloads same owner only',
    (tester) async {
      final messaging = TestMessaging()..status = PushPermission.denied;
      final device = TestRegistration('a');
      final controller = NotificationsController(
        messaging: messaging,
        registrationForOwner: (uid) => uid == 'a' ? device : null,
      );
      addTearDown(() async {
        final disposing = controller.dispose();
        await _drain(tester, disposing);
        final closing = messaging.close();
        await _drain(tester, closing);
      });
      final inbox = TestInbox('a');
      await _open(
        tester,
        TestAuth(const AuthUser(uid: 'a')),
        location: '/settings/notifications',
        inboxes: {'a': inbox},
        notifications: controller,
      );
      expect(messaging.calls, isNot(contains('permission-request')));
      await _tap(tester, find.byKey(const Key('notifications.enable')));
      expect(find.text('Разрешение отклонено в системе'), findsOneWidget);
      expect(messaging.calls, isNot(contains('get-token')));
      expect(device.trace, isEmpty);
      _router(tester).push('/inbox');
      await tester.pumpAndSettle();
      expect(find.text('Visitor'), findsOneWidget);
      final previousLists = inbox.lists;
      inbox.items = [enquiry(name: 'New visitor')];
      messaging.foregrounds.add(pushMessage('b'));
      await tester.pumpAndSettle();
      expect(inbox.lists, previousLists);
      messaging.foregrounds.add(pushMessage('a'));
      await tester.pumpAndSettle();
      expect(inbox.lists, greaterThan(previousLists));
      expect(find.text('New visitor'), findsOneWidget);
    },
  );
  testWidgets(
    'new owner can enable after local cleanup while previous backend cleanup stays visible',
    (tester) async {
      final messaging = TestMessaging();
      final auth = TestAuth(const AuthUser(uid: 'a'));
      final devices = {'a': TestRegistration('a'), 'b': TestRegistration('b')};
      final controller = NotificationsController(
        messaging: messaging,
        registrationForOwner: (uid) =>
            uid == auth.current?.uid ? devices[uid] : null,
      );
      addTearDown(() async {
        await _drain(tester, controller.dispose());
        await _drain(tester, messaging.close());
      });
      await _open(
        tester,
        auth,
        location: '/settings/notifications',
        notifications: controller,
        inboxes: {'b': TestInbox('b')},
      );
      await _tap(tester, find.byKey(const Key('notifications.enable')));
      auth.emit(const AuthUser(uid: 'b'));
      await tester.pumpAndSettle();
      _router(tester).go('/settings/notifications');
      await tester.pumpAndSettle();
      messaging.token = 'token-b';
      await _tap(tester, find.byKey(const Key('notifications.enable')));
      expect(controller.state.enabled, isTrue);
      expect(controller.state.cleanupFailed, isTrue);
      expect(
        find.text('Устройство зарегистрировано для этого аккаунта'),
        findsOneWidget,
      );
      expect(
        find.text('Очистка прежней регистрации не завершена'),
        findsOneWidget,
      );
      expect(find.text('Уведомления не подтверждены'), findsNothing);
      _router(tester).push('/inbox');
      await tester.pumpAndSettle();
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'UID transition clears Inbox and late old-owner page cannot appear in new account',
    (tester) async {
      final auth = TestAuth(const AuthUser(uid: 'a'));
      final completion = Completer<InboxPage>();
      final inboxA = TestInbox('a')..listing = (_) => completion.future;
      final inboxB = TestInbox('b', items: [enquiry(name: 'B visitor')]);
      await _open(
        tester,
        auth,
        location: '/inbox',
        inboxes: {'a': inboxA, 'b': inboxB},
        settle: false,
      );
      auth.emit(const AuthUser(uid: 'b'));
      await tester.pumpAndSettle();
      _router(tester).push('/inbox');
      await tester.pumpAndSettle();
      expect(find.text('B visitor'), findsOneWidget);
      completion.complete(
        InboxPage(requests: [enquiry(name: 'A secret visitor')]),
      );
      await tester.pumpAndSettle();
      expect(find.text('A secret visitor'), findsNothing);
      expect(find.text('B visitor'), findsOneWidget);
      auth.emit(null);
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('B visitor'), findsNothing);
    },
  );
  testWidgets(
    'same-owner notification tap pushes detail and Back preserves unsaved editor buffer',
    (tester) async {
      final messaging = TestMessaging(),
          auth = TestAuth(const AuthUser(uid: 'a'));
      final controller = NotificationsController(
        messaging: messaging,
        registrationForOwner: (_) => null,
      );
      addTearDown(() async {
        final disposing = controller.dispose();
        await _drain(tester, disposing);
        final closing = messaging.close();
        await _drain(tester, closing);
      });
      final draft = MemoryPortfolioDraftRepository();
      await draft.save(
        PortfolioContent(
          mainPortfolioId: 'main',
          documents: [
            PortfolioDocument(
              id: 'main',
              title: 'Основное портфолио',
              kind: PortfolioDocumentKind.portfolio,
              createdAt: DateTime.utc(2026, 10, 11),
              updatedAt: DateTime.utc(2026, 10, 11),
              content: PortfolioContent(
                profile: const PortfolioProfile(name: 'Owner'),
              ),
            ),
          ],
        ),
        expectedRevision: 0,
        notes: 'private notes',
      );
      await _open(
        tester,
        auth,
        location: '/editor',
        inboxes: {'a': TestInbox('a')},
        notifications: controller,
        draft: draft,
      );
      final input = find.descendant(
        of: find.byKey(const ValueKey('main.editor.name')),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Unsaved author');
      messaging.opens.add(pushMessage('b'));
      await tester.pumpAndSettle();
      expect(find.byType(MainPortfolioEditorScreen), findsOneWidget);
      expect(
        mainPortfolioDocument((await draft.read())!.content!)!
            .content
            .profile
            .name,
        'Owner',
      );
      messaging.opens.add(pushMessage('a'));
      await tester.pumpAndSettle();
      expect(find.byType(InboxRequestScreen), findsOneWidget);
      expect(controller.state.pendingRequestId, isNull);
      _router(tester).pop();
      await tester.pumpAndSettle();
      expect(find.byType(MainPortfolioEditorScreen), findsOneWidget);
      expect(find.text('Unsaved author'), findsOneWidget);
      expect(
        mainPortfolioDocument(
          _scope(tester).read(portfolioDraftControllerProvider).content!,
        )!.content.profile.name,
        'Unsaved author',
      );
      auth.emit(null);
      await tester.pumpAndSettle();
      messaging.opens.add(pushMessage('a'));
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(InboxRequestScreen), findsNothing);
    },
  );
}
