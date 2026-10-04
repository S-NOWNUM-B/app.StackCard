import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/settings/account_settings_section.dart';
import 'package:app_stackcard/main.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth implements AccountAuthRepository {
  AuthUser? user = const AuthUser(uid: 'a', email: 'a@example.com');
  final sessions = StreamController<AuthUser?>.broadcast();
  int signOutCalls = 0;

  @override
  Stream<AuthUser?> watchSession() => Stream.multi((controller) {
    controller.add(user);
    final subscription = sessions.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });
  @override
  Future<void> signOut() async {
    signOutCalls++;
    user = null;
    sessions.add(null);
  }

  @override
  Future<void> signInEmail(String email, String password) async {}
  @override
  Future<void> registerEmail(String email, String password) async {}
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}

class _DraftTransfer {
  final guest = MemoryPortfolioDraftRepository();
  final account = MemoryPortfolioDraftRepository();
  final calls = <String>[];
  bool available = true;
  bool availabilityFailure = false;
  PortfolioDraftFailure? failure;
  Completer<void>? pending;

  Future<void> transfer(String uid) async {
    calls.add(uid);
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    if (await account.read() != null) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.conflict);
    }
    final source = (await guest.read())!;
    if (source.content case final content?) {
      await account.save(content, expectedRevision: 0, notes: source.notes);
    } else {
      await account.saveNotes(source.notes);
    }
    available = false;
  }
}

Future<void> _pumpSettings(
  WidgetTester tester,
  _Auth auth,
  _DraftTransfer transfer,
) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await auth.sessions.close();
  });
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: '/settings',
      providerOverrides: [
        accountAuthRepositoryProvider.overrideWithValue(auth),
        portfolioDraftRepositoryFactoryProvider.overrideWithValue(
          (uid) => uid == null ? transfer.guest : transfer.account,
        ),
        guestDraftAvailableProvider.overrideWith((ref) async {
          if (transfer.availabilityFailure) {
            throw const PortfolioDraftFailure(
              PortfolioDraftFailureKind.unavailable,
            );
          }
          return transfer.available;
        }),
        guestDraftTransferProvider.overrideWithValue(transfer.transfer),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _scope(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(AccountSettingsSection)),
);

Future<void> _requestTransfer(WidgetTester tester) async {
  final button = find.widgetWithText(
    StackCardButton,
    'Перенести в этот аккаунт',
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _confirmTransfer(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Перенести в этот аккаунт'));
  await tester.pump();
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
    'Guest transfer requires explicit confirmation and refreshes current account draft',
    (tester) async {
      final auth = _Auth();
      final transfer = _DraftTransfer();
      final content = PortfolioContent(
        profile: const PortfolioProfile(name: 'Guest owner'),
      );
      await transfer.guest.save(
        content,
        expectedRevision: 0,
        notes: 'Guest private notes',
      );
      await _pumpSettings(tester, auth, transfer);
      await _requestTransfer(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(transfer.calls, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
      await tester.pumpAndSettle();
      expect(transfer.calls, isEmpty);
      expect(await transfer.account.read(), isNull);
      expect((await transfer.guest.read())!.notes, 'Guest private notes');
      await _requestTransfer(tester);
      await _confirmTransfer(tester);
      await tester.pumpAndSettle();
      expect(transfer.calls, ['a']);
      expect((await transfer.account.read())!.content, content);
      expect(
        _scope(tester).read(portfolioDraftControllerProvider).notes,
        'Guest private notes',
      );
      expect(
        find.text('Черновик перенесён. Открой Builder, чтобы продолжить.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(StackCardButton, 'Перенести в этот аккаунт'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Existing account draft blocks transfer without overwriting either source',
    (tester) async {
      final auth = _Auth();
      final transfer = _DraftTransfer();
      await transfer.guest.saveNotes('Guest notes');
      await transfer.account.saveNotes('Account notes');
      await _pumpSettings(tester, auth, transfer);
      await _requestTransfer(tester);
      await _confirmTransfer(tester);
      await tester.pumpAndSettle();
      expect(transfer.calls, ['a']);
      expect((await transfer.account.read())!.notes, 'Account notes');
      expect((await transfer.guest.read())!.notes, 'Guest notes');
      expect(find.textContaining('Перенос заблокирован:'), findsOneWidget);
      expect(
        _scope(tester).read(portfolioDraftControllerProvider).notes,
        'Account notes',
      );
    },
  );

  testWidgets(
    'Unsaved account edits block guest transfer and preserve working input',
    (tester) async {
      final auth = _Auth();
      final transfer = _DraftTransfer();
      await transfer.guest.saveNotes('Guest notes');
      await _pumpSettings(tester, auth, transfer);
      final scope = _scope(tester);
      scope
          .read(portfolioDraftControllerProvider.notifier)
          .editNotes('Unsaved account notes');
      expect(
        scope.read(portfolioDraftControllerProvider).hasUnsavedChanges,
        isTrue,
      );
      await _requestTransfer(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Сначала сохрани или отмени текущие правки аккаунта.'),
        findsOneWidget,
      );
      expect(transfer.calls, isEmpty);
      expect(
        scope.read(portfolioDraftControllerProvider).notes,
        'Unsaved account notes',
      );
      expect(await transfer.account.read(), isNull);
    },
  );

  testWidgets(
    'Failed guest-draft availability can be explicitly retried before transfer',
    (tester) async {
      final auth = _Auth();
      final transfer = _DraftTransfer()..availabilityFailure = true;
      await transfer.guest.saveNotes('Guest notes');
      await _pumpSettings(tester, auth, transfer);
      final retry = find.descendant(
        of: find.byType(AccountSettingsSection),
        matching: find.widgetWithText(StackCardButton, 'Повторить'),
      );
      expect(retry, findsOneWidget);
      expect(
        find.widgetWithText(StackCardButton, 'Перенести в этот аккаунт'),
        findsNothing,
      );
      transfer.availabilityFailure = false;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(StackCardButton, 'Перенести в этот аккаунт'),
        findsOneWidget,
      );
      expect(transfer.calls, isEmpty);
      expect((await transfer.guest.read())!.notes, 'Guest notes');
    },
  );

  testWidgets(
    'Transfer failure preserves guest draft and allows a successful explicit retry',
    (tester) async {
      final auth = _Auth();
      final transfer = _DraftTransfer()
        ..failure = const PortfolioDraftFailure(
          PortfolioDraftFailureKind.unavailable,
        );
      await transfer.guest.saveNotes('Recoverable guest notes');
      await _pumpSettings(tester, auth, transfer);
      await _requestTransfer(tester);
      await _confirmTransfer(tester);
      await tester.pumpAndSettle();
      expect(transfer.calls, ['a']);
      expect(await transfer.account.read(), isNull);
      expect((await transfer.guest.read())!.notes, 'Recoverable guest notes');
      transfer.failure = null;
      await _requestTransfer(tester);
      await _confirmTransfer(tester);
      await tester.pumpAndSettle();
      expect(transfer.calls, ['a', 'a']);
      expect(
        _scope(tester).read(portfolioDraftControllerProvider).notes,
        'Recoverable guest notes',
      );
    },
  );

  testWidgets(
    'Transfer pending disables duplicate transfer and sign-out cannot leave mid-transfer',
    (tester) async {
      final auth = _Auth();
      final transfer = _DraftTransfer()..pending = Completer<void>();
      await transfer.guest.saveNotes('Guest notes');
      await _pumpSettings(tester, auth, transfer);
      await _requestTransfer(tester);
      await _confirmTransfer(tester);
      final button = tester.widget<StackCardButton>(
        find.widgetWithText(StackCardButton, 'Перенести в этот аккаунт'),
      );
      expect(button.loading, isTrue);
      expect(button.onPressed, isNull);
      await tester.ensureVisible(
        find.byKey(const Key('account.sessionAction')),
      );
      await tester.tap(find.byKey(const Key('account.sessionAction')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(auth.signOutCalls, 0);
      transfer.pending!.complete();
      await tester.pumpAndSettle();
      expect(transfer.calls, ['a']);
    },
  );

  testWidgets(
    'New working edits during transfer remain visible after transfer completes',
    (tester) async {
      final auth = _Auth();
      final transfer = _DraftTransfer()..pending = Completer<void>();
      await transfer.guest.saveNotes('Saved guest notes');
      await _pumpSettings(tester, auth, transfer);
      await _requestTransfer(tester);
      await _confirmTransfer(tester);
      final scope = _scope(tester);
      scope
          .read(portfolioDraftControllerProvider.notifier)
          .editNotes('NEW WORKING NOTES');
      transfer.pending!.complete();
      await tester.pumpAndSettle();
      expect(
        scope.read(portfolioDraftControllerProvider).notes,
        'NEW WORKING NOTES',
      );
      expect(
        scope.read(portfolioDraftControllerProvider).hasUnsavedChanges,
        isTrue,
      );
      expect((await transfer.account.read())!.notes, 'Saved guest notes');
    },
  );

  testWidgets(
    'Sign-out confirmation cancels safely then discards only unsaved working changes',
    (tester) async {
      final auth = _Auth();
      final transfer = _DraftTransfer()..available = false;
      await transfer.account.saveNotes('Durable account notes');
      await _pumpSettings(tester, auth, transfer);
      final scope = _scope(tester);
      scope
          .read(portfolioDraftControllerProvider.notifier)
          .editNotes('Working secret');
      await tester.ensureVisible(
        find.byKey(const Key('account.sessionAction')),
      );
      await tester.tap(find.byKey(const Key('account.sessionAction')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Есть несохранённые изменения'), findsOneWidget);
      expect(auth.signOutCalls, 0);
      await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
      await tester.pumpAndSettle();
      expect(
        scope.read(portfolioDraftControllerProvider).notes,
        'Working secret',
      );
      expect(auth.signOutCalls, 0);
      await tester.tap(find.byKey(const Key('account.sessionAction')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.widgetWithText(TextButton, 'Продолжить без сохранения'),
      );
      await tester.pumpAndSettle();
      expect(auth.signOutCalls, 1);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Working secret'), findsNothing);
      expect((await transfer.account.read())!.notes, 'Durable account notes');
    },
  );
}
