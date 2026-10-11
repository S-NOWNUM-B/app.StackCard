import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_colors.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/core/theme/stackcard_tokens.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/settings/settings_screen.dart';
import 'package:app_stackcard/main.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/inbox_fakes.dart' show TestAuth;

const _strings = AppStrings(Locale('ru'));
const _sessionAction = Key('account.sessionAction');
const _sessionMenu = Key('account.sessionMenu');
const _googleProvider = Key('account.googleProvider');

class _SessionAuth extends TestAuth {
  _SessionAuth([super.current]);

  bool emitInitial = true;
  int sessionRequests = 0;
  int signOutCalls = 0;

  @override
  Stream<AuthUser?> watchSession() => Stream.multi((controller) {
    sessionRequests++;
    if (emitInitial) controller.add(current);
    final subscription = changes.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<void> signOut() async {
    signOutCalls++;
    await super.signOut();
  }
}

class _PublicationSpy implements DocumentPublicationRepository {
  int deletionCalls = 0;

  @override
  Future<DocumentPublicationInventory> inventory() async =>
      DocumentPublicationInventory(publications: [], lifecycleGeneration: 0);

  @override
  Future<DocumentPublicationOperation> deleteAccount({
    required String operationId,
    required int expectedGeneration,
    required String recoveryKey,
  }) async {
    deletionCalls++;
    throw StateError('Settings navigation must not delete an account');
  }

  @override
  Future<DocumentPublicationOperation> recoverAccountDeletion({
    required String ownerUid,
    required String operationId,
    required String recoveryKey,
    bool retry = false,
  }) async {
    deletionCalls++;
    throw StateError('Settings navigation must not recover or retry deletion');
  }

  @override
  Future<DocumentPublicationOperation> status(String operationId) async =>
      throw StateError('No operation has been started');

  @override
  Future<DocumentPublicationOperation> mutate(
    DocumentPublicationMutation mutation,
  ) async => throw StateError('Settings navigation must not publish documents');
}

void _setViewport(WidgetTester tester, double width, double scale) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last));

ProviderContainer _scope(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));

Finder _sessionIcon(IconData icon) =>
    find.descendant(of: find.byType(AccountCard), matching: find.byIcon(icon));

Future<void> _openSettings(
  WidgetTester tester,
  _SessionAuth auth, {
  Map<String?, PortfolioDraftRepository>? drafts,
  _PublicationSpy? publication,
}) async {
  final repositories = drafts ?? <String?, PortfolioDraftRepository>{};
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await auth.changes.close();
  });
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: auth.current == null ? '/sign-in' : '/settings',
      providerOverrides: [
        accountAuthRepositoryProvider.overrideWithValue(auth),
        portfolioDraftRepositoryFactoryProvider.overrideWithValue(
          (uid) =>
              repositories.putIfAbsent(uid, MemoryPortfolioDraftRepository.new),
        ),
        if (publication != null)
          documentPublicationRepositoryFactoryProvider.overrideWithValue(
            (_) => publication,
          ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  if (auth.current == null) {
    await _tap(tester, find.byKey(const Key('account.guest')));
    _router(tester).go('/settings');
    await tester.pumpAndSettle();
  }
  expect(find.byType(SettingsScreen), findsOneWidget);
}

// Отдельная карточка проверяет session states, которые app route guard закрывает.
Future<void> _openCard(
  WidgetTester tester,
  _SessionAuth auth, {
  bool settle = true,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Center(child: AccountCard())),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    await auth.changes.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accountAuthRepositoryProvider.overrideWithValue(auth)],
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manrope = FontLoader('Manrope');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      manrope.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
    }
    await manrope.load();
    for (final entry in [
      ('DM Sans', 'assets/fonts/DM_Sans.ttf'),
      ('Noto Sans', 'assets/fonts/Noto_Sans.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(entry.$1)..addFont(rootBundle.load(entry.$2));
      await loader.load();
    }
  });

  testWidgets(
    'Signed-out session has a neutral account title and sign-in action',
    (tester) async {
      _setViewport(tester, 390, 1);
      final auth = _SessionAuth();
      await _openSettings(tester, auth);
      await tester.ensureVisible(find.byKey(_sessionAction));
      expect(find.text(_strings.tr('account.title')), findsOneWidget);
      expect(find.text(_strings.tr('account.guestTitle')), findsNothing);
      expect(find.text(_strings.tr('account.signIn')), findsOneWidget);
      expect(_sessionIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.byKey(_sessionMenu), findsNothing);
      expect(find.byKey(_googleProvider), findsNothing);
      expect(find.byKey(const Key('settings.deleteAccount')), findsNothing);
      expect(find.text(_strings.tr('settings.deleteAccount')), findsNothing);
      expect(find.text(_strings.tr('settings.session')), findsNothing);

      await _tap(tester, find.byKey(_sessionAction));
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(
        _router(tester)
            .routeInformationProvider
            .value
            .uri
            .queryParameters['from'],
        '/settings',
      );
      for (final field in [
        ('account.email', 'owner@example.com'),
        ('account.password', 'secret'),
      ]) {
        await tester.enterText(
          find.descendant(
            of: find.byKey(Key(field.$1)),
            matching: find.byType(TextFormField),
          ),
          field.$2,
        );
      }
      await _tap(tester, find.byKey(const Key('account.submit')));
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        _router(tester).routeInformationProvider.value.uri.path,
        '/settings',
      );
      expect(find.text('owner@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fixture in [
    (
      name: 'display name takes precedence',
      user: const AuthUser(
        uid: 'owner',
        displayName: 'Stanislav Mamaev',
        email: 'owner@example.com',
      ),
      identity: 'Stanislav Mamaev',
    ),
    (
      name: 'email is used without a display name',
      user: const AuthUser(uid: 'owner', email: 'owner@example.com'),
      identity: 'owner@example.com',
    ),
    (
      name: 'missing identity uses account title',
      user: const AuthUser(uid: 'owner'),
      identity: _strings.tr('account.title'),
    ),
    (
      name: 'blank name falls back to email',
      user: const AuthUser(
        uid: 'owner',
        displayName: '   ',
        email: 'owner@example.com',
      ),
      identity: 'owner@example.com',
    ),
  ]) {
    testWidgets('Account identity: ${fixture.name}', (tester) async {
      _setViewport(tester, 390, 1);
      await _openSettings(tester, _SessionAuth(fixture.user));
      final account = tester.getRect(find.byType(AccountCard));
      final lastSetting = tester.getRect(
        find.byKey(const Key('settings.group.about')),
      );
      expect(account.top, greaterThanOrEqualTo(0));
      expect(lastSetting.bottom, lessThan(account.top));
      expect(
        account.top - lastSetting.bottom,
        closeTo(StackCardSpacing.lg, 0.1),
      );
      expect(find.text(fixture.identity), findsOneWidget);
      expect(_sessionIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.text(_strings.tr('account.signOut')), findsOneWidget);
      expect(find.text(_strings.tr('account.guestTitle')), findsNothing);
      expect(find.text(_strings.tr('settings.session')), findsNothing);
      expect(find.byKey(_sessionMenu), findsNothing);
      expect(find.byKey(const Key('settings.deleteAccount')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final fixture in [
    (
      name: 'password account with Gmail address',
      user: const AuthUser(uid: 'password', email: 'owner@gmail.com'),
      google: false,
    ),
    (
      name: 'Google provider with custom email domain',
      user: const AuthUser(
        uid: 'google',
        email: 'owner@example.com',
        hasGoogle: true,
      ),
      google: true,
    ),
  ]) {
    testWidgets('Google badge uses provider metadata: ${fixture.name}', (
      tester,
    ) async {
      _setViewport(tester, 390, 1);
      await _openSettings(tester, _SessionAuth(fixture.user));
      expect(
        find.byKey(_googleProvider),
        fixture.google ? findsOneWidget : findsNothing,
      );
      if (fixture.google) {
        expect(tester.widget<Text>(find.byKey(_googleProvider)).data, 'Google');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Settings account row routes to security without deleting', (
    tester,
  ) async {
    _setViewport(tester, 390, 1);
    final auth = _SessionAuth(const AuthUser(uid: 'owner'));
    final publication = _PublicationSpy();
    await _openSettings(tester, auth, publication: publication);
    expect(find.text(_strings.tr('settings.deleteAccount')), findsNothing);
    expect(find.byKey(_sessionMenu), findsNothing);
    expect(find.byKey(_sessionAction), findsOneWidget);
    await _tap(tester, find.byKey(const Key('settings.group.account')));
    expect(find.byType(SettingsAccountScreen), findsOneWidget);
    expect(find.byKey(_sessionAction), findsNothing);
    expect(
      _router(tester).routerDelegate.currentConfiguration.last.matchedLocation,
      '/settings/account',
    );
    expect(publication.deletionCalls, 0);
    expect(auth.signOutCalls, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Restoring session is not presented as a guest', (tester) async {
    _setViewport(tester, 390, 1);
    final auth = _SessionAuth()..emitInitial = false;
    await _openCard(tester, auth, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(_strings.tr('account.guestTitle')), findsNothing);
    expect(find.byKey(_sessionAction), findsNothing);
    expect(find.byKey(_sessionMenu), findsNothing);
    expect(find.byKey(_googleProvider), findsNothing);
    auth.emit(const AuthUser(uid: 'owner', displayName: 'Restored owner'));
    await tester.pumpAndSettle();
    expect(find.text('Restored owner'), findsOneWidget);
    expect(find.byKey(_sessionAction), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Session error removes account actions and retries explicitly', (
    tester,
  ) async {
    _setViewport(tester, 390, 1);
    final auth = _SessionAuth(
      const AuthUser(
        uid: 'owner',
        displayName: 'Verified owner',
        hasGoogle: true,
      ),
    );
    await _openCard(tester, auth);
    auth.changes.addError(const AuthFailure(AuthFailureKind.network));
    await tester.pumpAndSettle();
    expect(find.text(_strings.tr('account.sessionError')), findsOneWidget);
    expect(find.text(_strings.tr('account.guestTitle')), findsNothing);
    expect(find.text('Verified owner'), findsNothing);
    expect(find.byKey(_sessionAction), findsOneWidget);
    expect(find.text(_strings.tr('common.retry')), findsOneWidget);
    expect(find.text(_strings.tr('account.signIn')), findsNothing);
    expect(find.text(_strings.tr('account.signOut')), findsNothing);
    expect(find.byKey(_sessionMenu), findsNothing);
    expect(find.byKey(_googleProvider), findsNothing);
    expect(auth.sessionRequests, 1);
    await _tap(tester, find.text(_strings.tr('common.retry')));
    expect(auth.sessionRequests, 2);
    expect(find.text('Verified owner'), findsOneWidget);
    expect(find.byKey(_googleProvider), findsOneWidget);
    expect(find.text(_strings.tr('account.sessionError')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final fixture in [
        (user: null, identity: _strings.tr('account.title')),
        (
          user: const AuthUser(
            uid: 'long-name',
            displayName: 'Stanislav Mamaev with a very long display name',
            email: 'account@example.com',
            hasGoogle: true,
          ),
          identity: 'Stanislav Mamaev with a very long display name',
        ),
        (
          user: const AuthUser(
            uid: 'long-email',
            email: 'very.long.account.address@a.long.example.com',
          ),
          identity: 'very.long.account.address@a.long.example.com',
        ),
      ]) {
        testWidgets(
          'Session stays horizontal at $width scale $scale for ${fixture.user?.uid ?? "guest"}',
          (tester) async {
            _setViewport(tester, width, scale);
            await _openSettings(tester, _SessionAuth(fixture.user));
            final account = tester.getRect(find.byType(AccountCard));
            final lastSetting = tester.getRect(
              find.byKey(const Key('settings.group.about')),
            );
            expect(account.top, greaterThanOrEqualTo(0));
            expect(lastSetting.bottom, lessThan(account.top));
            await tester.ensureVisible(find.byKey(_sessionAction));
            await tester.pumpAndSettle();
            final identity = tester.getRect(find.text(fixture.identity));
            final action = tester.getRect(find.byKey(_sessionAction));
            final icon = tester.getRect(
              _sessionIcon(Icons.person_outline_rounded),
            );
            final colors = tester.element(find.byKey(_sessionAction)).colors;
            final renderedAction = tester.widget<RichText>(
              find.descendant(
                of: find.byKey(_sessionAction),
                matching: find.byType(RichText),
              ),
            );
            expect(
              renderedAction.text.style?.color,
              fixture.user == null ? colors.textPrimary : colors.error,
            );
            expect(icon.size, const Size(24, 24));
            expect(icon.right, lessThanOrEqualTo(identity.left));
            expect(identity.right, lessThanOrEqualTo(action.left));
            expect(identity.top, lessThan(action.bottom));
            expect(identity.bottom, greaterThan(action.top));
            expect(action.right, lessThanOrEqualTo(width));
            expect(action.height, greaterThanOrEqualTo(48));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('Settings navigation rows have equal 64dp targets', (
    tester,
  ) async {
    _setViewport(tester, 390, 1);
    await _openSettings(tester, _SessionAuth(const AuthUser(uid: 'owner')));
    final heights = <double>[];
    for (final removed in ['profile', 'contacts', 'privacy']) {
      expect(find.byKey(Key('settings.group.$removed')), findsNothing);
    }
    for (final group in [
      'account',
      'github',
      'appearance',
      'inbox',
      'notifications',
      'about',
    ]) {
      final row = find.byKey(Key('settings.group.$group'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      heights.add(tester.getSize(row).height);
    }
    for (final height in heights) {
      expect(height, greaterThanOrEqualTo(64));
      expect(height, closeTo(heights.first, 0.1));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Session sign-out keeps confirmation and durable account notes', (
    tester,
  ) async {
    _setViewport(tester, 390, 1);
    final auth = _SessionAuth(const AuthUser(uid: 'owner'));
    final account = MemoryPortfolioDraftRepository();
    await account.saveNotes('Durable notes');
    await _openSettings(tester, auth, drafts: {'owner': account});
    final scope = _scope(tester);
    scope
        .read(portfolioDraftControllerProvider.notifier)
        .editNotes('Unsaved notes');
    await _tap(tester, find.byKey(_sessionAction), settle: false);
    expect(find.text(_strings.tr('account.unsavedTitle')), findsOneWidget);
    expect(auth.signOutCalls, 0);
    await _tap(
      tester,
      find.widgetWithText(StackCardButton, _strings.tr('common.cancel')),
    );
    expect(scope.read(portfolioDraftControllerProvider).notes, 'Unsaved notes');
    expect(auth.signOutCalls, 0);
    await _tap(tester, find.byKey(_sessionAction), settle: false);
    await _tap(
      tester,
      find.widgetWithText(StackCardButton, _strings.tr('common.confirm')),
    );
    expect(auth.signOutCalls, 1);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect((await account.read())!.notes, 'Durable notes');
    expect(tester.takeException(), isNull);
  });
}
