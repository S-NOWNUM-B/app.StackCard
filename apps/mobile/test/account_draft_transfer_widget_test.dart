import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/settings/account_settings_section.dart';
import 'package:app_stackcard/main.dart';
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
  int availabilityReads = 0;
  bool available = true;
  bool availabilityFailure = false;

  Future<void> transfer(String uid) async {
    calls.add(uid);
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
          transfer.availabilityReads++;
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

  for (final availabilityFailure in [false, true]) {
    testWidgets(
      'Settings hide guest transfer without reading ${availabilityFailure ? "failed" : "available"} availability',
      (tester) async {
        final auth = _Auth();
        final transfer = _DraftTransfer()
          ..availabilityFailure = availabilityFailure;
        await transfer.guest.saveNotes('Durable guest notes');
        await transfer.account.saveNotes('Durable account notes');
        await _pumpSettings(tester, auth, transfer);
        expect(find.text('Гостевой режим'), findsNothing);
        expect(find.text('Гостевой черновик'), findsNothing);
        expect(find.text('Перенести в этот аккаунт'), findsNothing);
        expect(transfer.availabilityReads, 0);
        expect(transfer.calls, isEmpty);
        expect((await transfer.guest.read())!.notes, 'Durable guest notes');
        expect((await transfer.account.read())!.notes, 'Durable account notes');
        expect(
          _scope(tester).read(portfolioDraftControllerProvider).notes,
          'Durable account notes',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

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
