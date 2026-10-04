import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/auth/auth_providers.dart';
import 'package:app_stackcard/features/auth/domain/account_auth_repository.dart';
import 'package:app_stackcard/features/auth/domain/auth_failure.dart';
import 'package:app_stackcard/features/auth/domain/auth_user.dart';
import 'package:app_stackcard/features/auth/presentation/account_auth_form.dart';
import 'package:app_stackcard/features/auth/presentation/account_card.dart';
import 'package:app_stackcard/features/auth/presentation/sign_in_screen.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/shared/widgets/stackcard_brand.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:app_stackcard/shared/widgets/stackcard_input.dart';
import 'package:app_stackcard/shared/widgets/stackcard_poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _AuthRepository implements AccountAuthRepository {
  final requests = <String>[];
  final sessions = StreamController<AuthUser?>.broadcast();
  AuthUser? current;
  bool emitInitial = true;
  int sessionRequests = 0;
  Completer<void>? pending;
  AuthFailure? failure;
  String? email;
  String? password;

  Future<void> _complete(String operation) async {
    requests.add(operation);
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
  }

  @override
  Stream<AuthUser?> watchSession() async* {
    sessionRequests++;
    if (emitInitial) yield current;
    yield* sessions.stream;
  }

  @override
  Future<void> signInEmail(String email, String password) async {
    this.email = email;
    this.password = password;
    await _complete('email');
  }

  @override
  Future<void> registerEmail(String email, String password) async {
    this.email = email;
    this.password = password;
    await _complete('register');
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    this.email = email;
    await _complete('reset');
  }

  @override
  Future<void> signInGoogle() => _complete('google');

  @override
  Future<void> signOut() => _complete('signOut');
}

Future<void> _pumpAuth(
  WidgetTester tester,
  _AuthRepository repository, {
  String location = '/sign-in',
  Locale locale = const Locale('ru'),
  ThemeData? theme,
  double textScale = 1,
  Future<bool> Function()? beforeSignOut,
  bool settle = true,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await repository.sessions.close();
  });
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/register',
        builder: (_, _) => const SignInScreen(mode: AuthFormMode.register),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const SignInScreen(mode: AuthFormMode.resetPassword),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Destination home')),
      ),
      GoRoute(
        path: '/portfolio/builder',
        builder: (_, _) => const Scaffold(body: Text('Destination builder')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            child: AccountCard(beforeSignOut: beforeSignOut),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accountAuthRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: theme ?? StackCardTheme.dark,
        locale: locale,
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(TextFormField),
    ),
    value,
  );
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

bool _actionEnabled(WidgetTester tester, String key) {
  final widget = tester.widget(find.byKey(Key(key)));
  return switch (widget) {
    StackCardButton(:final onPressed) => onPressed != null,
    ButtonStyleButton(:final onPressed) => onPressed != null,
    _ => throw StateError('Unexpected action widget for $key'),
  };
}

Future<void> _checkAccountAccessibility(WidgetTester tester) async {
  // Проверяем полные semantics при исходной ширине, без scroll clipping,
  // как в существующих responsive/Builder проверках.
  final size = tester.view.physicalSize;
  final scroll = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  tester.view.physicalSize = Size(
    size.width,
    size.height + scroll.position.maxScrollExtent.ceilToDouble() + 16,
  );
  await tester.pumpAndSettle();
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  } finally {
    semantics.dispose();
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in [
      ('DM Sans', 'assets/fonts/DM_Sans.ttf'),
      ('Noto Sans', 'assets/fonts/Noto_Sans.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(entry.$1)..addFont(rootBundle.load(entry.$2));
      await loader.load();
    }
  });
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
    'Email form validates, obscures password and preserves its spaces',
    (tester) async {
      final repository = _AuthRepository();
      await _pumpAuth(
        tester,
        repository,
        location: '/sign-in?from=%2Fportfolio%2Fbuilder',
      );
      expect(
        tester
            .widget<StackCardInput>(find.byKey(const Key('account.password')))
            .obscureText,
        isTrue,
      );
      expect(
        tester
            .widget<StackCardInput>(find.byKey(const Key('account.email')))
            .controller!
            .text,
        isEmpty,
      );
      await _enter(tester, 'account.email', 'invalid');
      await _tap(tester, 'account.submit');
      await tester.pumpAndSettle();
      expect(repository.requests, isEmpty);
      expect(find.text('Укажите корректный email'), findsOneWidget);
      await _enter(tester, 'account.email', ' user@example.com ');
      await _enter(tester, 'account.password', ' secret ');
      await _tap(tester, 'account.submit');
      await tester.pumpAndSettle();
      expect(repository.requests, ['email']);
      expect(repository.email, 'user@example.com');
      expect(repository.password, ' secret ');
      expect(find.text('Destination builder'), findsOneWidget);
    },
  );

  testWidgets(
    'Registration requires matching passwords before making a request',
    (tester) async {
      final repository = _AuthRepository();
      await _pumpAuth(tester, repository, location: '/register');
      await _enter(tester, 'account.email', 'new@example.com');
      await _enter(tester, 'account.password', '123');
      await _enter(tester, 'account.confirmPassword', 'different');
      await _tap(tester, 'account.submit');
      await tester.pumpAndSettle();
      expect(repository.requests, isEmpty);
      expect(find.text('Пароли не совпадают'), findsOneWidget);
      await _enter(tester, 'account.password', 'valid-password');
      await _enter(tester, 'account.confirmPassword', 'valid-password');
      await _tap(tester, 'account.submit');
      await tester.pumpAndSettle();
      expect(repository.requests, ['register']);
      expect(find.text('Destination home'), findsOneWidget);
    },
  );

  testWidgets(
    'Reset stays on screen with a generic email-enumeration-safe response',
    (tester) async {
      final repository = _AuthRepository();
      await _pumpAuth(
        tester,
        repository,
        location: '/reset-password',
        locale: const Locale('en'),
      );
      expect(find.byKey(const Key('account.password')), findsNothing);
      await _enter(tester, 'account.email', 'unknown@example.com');
      await _tap(tester, 'account.submit');
      await tester.pumpAndSettle();
      expect(repository.requests, ['reset']);
      expect(find.textContaining('If an account exists'), findsOneWidget);
      expect(find.byType(SignInScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Pending login disables fields and all actions; error permits retry',
    (tester) async {
      final repository = _AuthRepository()
        ..pending = Completer<void>()
        ..failure = const AuthFailure(AuthFailureKind.invalidCredentials);
      await _pumpAuth(tester, repository);
      await _enter(tester, 'account.email', 'user@example.com');
      await _enter(tester, 'account.password', 'secret');
      await _tap(tester, 'account.submit');
      expect(
        tester
            .widget<StackCardButton>(find.byKey(const Key('account.submit')))
            .loading,
        isTrue,
      );
      expect(
        tester
            .widget<StackCardInput>(find.byKey(const Key('account.email')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<StackCardButton>(find.byKey(const Key('account.google')))
            .onPressed,
        isNull,
      );
      expect(_actionEnabled(tester, 'account.guest'), isFalse);
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось войти. Проверьте email и пароль.'),
        findsOneWidget,
      );
      repository.failure = null;
      await _tap(tester, 'account.submit');
      await tester.pumpAndSettle();
      expect(repository.requests, ['email', 'email']);
      expect(find.text('Destination home'), findsOneWidget);
    },
  );

  testWidgets('Google cancellation is quiet and next attempt can sign in', (
    tester,
  ) async {
    final repository = _AuthRepository()
      ..failure = const AuthFailure(AuthFailureKind.cancelled);
    await _pumpAuth(tester, repository);
    await _tap(tester, 'account.google');
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(
      find.text('Не удалось выполнить действие. Повторите попытку.'),
      findsNothing,
    );
    repository.failure = null;
    await _tap(tester, 'account.google');
    await tester.pumpAndSettle();
    expect(repository.requests, ['google', 'google']);
    expect(find.text('Destination home'), findsOneWidget);
  });

  testWidgets('Guest entry does not call account repository', (tester) async {
    final repository = _AuthRepository();
    await _pumpAuth(tester, repository);
    await _tap(tester, 'account.guest');
    await tester.pumpAndSettle();
    expect(repository.requests, isEmpty);
    expect(find.text('Destination home'), findsOneWidget);
    final scope = ProviderScope.containerOf(
      tester.element(find.text('Destination home')),
    );
    expect(scope.read(guestAccessProvider), isTrue);
  });

  testWidgets('Account card confirms sign-out and reports retryable failures', (
    tester,
  ) async {
    var allowed = false;
    final repository = _AuthRepository()
      ..current = const AuthUser(uid: 'a', email: 'owner@example.com')
      ..failure = const AuthFailure(AuthFailureKind.network);
    await _pumpAuth(
      tester,
      repository,
      location: '/settings',
      beforeSignOut: () async => allowed,
    );
    expect(find.text('owner@example.com'), findsOneWidget);
    await _tap(tester, 'account.sessionAction');
    await tester.pumpAndSettle();
    expect(repository.requests, isEmpty);
    allowed = true;
    await _tap(tester, 'account.sessionAction');
    await tester.pumpAndSettle();
    expect(repository.requests, ['signOut']);
    expect(
      find.text('Нет соединения. Проверьте сеть и повторите попытку.'),
      findsOneWidget,
    );
    repository.failure = null;
    await _tap(tester, 'account.sessionAction');
    await tester.pumpAndSettle();
    expect(repository.requests, ['signOut', 'signOut']);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  for (final locale in [const Locale('ru'), const Locale('en')]) {
    testWidgets(
      'Session restoration blocks auth and guest entry in ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        final repository = _AuthRepository()..emitInitial = false;
        await _pumpAuth(
          tester,
          repository,
          locale: locale,
          textScale: 2,
          settle: false,
        );
        expect(
          find.text(
            locale.languageCode == 'ru'
                ? 'Проверяем аккаунт…'
                : 'Restoring your account…',
          ),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        for (final key in [
          'account.submit',
          'account.google',
          'account.guest',
        ]) {
          expect(_actionEnabled(tester, key), isFalse);
        }
        expect(repository.requests, isEmpty);
        expect(repository.sessionRequests, 1);
        expect(tester.takeException(), isNull);
        repository.sessions.add(null);
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(_actionEnabled(tester, 'account.guest'), isTrue);
        await _tap(tester, 'account.guest');
        await tester.pumpAndSettle();
        expect(find.text('Destination home'), findsOneWidget);
      },
    );

    testWidgets(
      'Session failure requires explicit retry before account actions in ${locale.languageCode}',
      (tester) async {
        final repository = _AuthRepository();
        await _pumpAuth(tester, repository, locale: locale);
        await _enter(tester, 'account.email', 'user@example.com');
        await _enter(tester, 'account.password', 'secret');
        repository.sessions.addError(
          const AuthFailure(AuthFailureKind.network),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        expect(
          find.text(
            locale.languageCode == 'ru'
                ? 'Не удалось проверить аккаунт. Повторите попытку.'
                : 'Unable to check your account. Please try again.',
          ),
          findsOneWidget,
        );
        expect(repository.sessionRequests, 1);
        for (final key in [
          'account.submit',
          'account.google',
          'account.guest',
        ]) {
          expect(_actionEnabled(tester, key), isFalse);
        }
        expect(repository.requests, isEmpty);
        await _tap(tester, 'account.retrySession');
        await tester.pumpAndSettle();
        expect(repository.sessionRequests, 2);
        expect(find.byKey(const Key('account.retrySession')), findsNothing);
        expect(
          tester
              .widget<StackCardInput>(find.byKey(const Key('account.email')))
              .controller!
              .text,
          'user@example.com',
        );
        await _tap(tester, 'account.submit');
        await tester.pumpAndSettle();
        expect(repository.requests, ['email']);
        expect(find.text('Destination home'), findsOneWidget);
      },
    );
  }

  for (final operation in ['email', 'register', 'google']) {
    testWidgets('Unsaved guest edits require confirmation before $operation', (
      tester,
    ) async {
      final repository = _AuthRepository();
      await _pumpAuth(
        tester,
        repository,
        location: operation == 'register' ? '/register' : '/sign-in',
      );
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(SignInScreen)),
      );
      scope.read(guestAccessProvider.notifier).enter();
      scope.read(accountSessionProvider);
      await tester.pumpAndSettle();
      final subscription = scope.listen(
        portfolioDraftControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await tester.pumpAndSettle();
      final draftState = scope.read(portfolioDraftControllerProvider);
      expect(
        draftState.canEdit,
        isTrue,
        reason:
            'loading=${draftState.loading} loaded=${draftState.loaded} failure=${draftState.failure} guest=${scope.read(guestAccessProvider)} session=${scope.read(accountSessionProvider)}',
      );
      scope
          .read(portfolioDraftControllerProvider.notifier)
          .editNotes('Unsaved guest notes');
      expect(
        scope.read(portfolioDraftControllerProvider).hasUnsavedChanges,
        isTrue,
      );
      if (operation != 'google') {
        await _enter(tester, 'account.email', 'user@example.com');
        await _enter(tester, 'account.password', 'secret');
        if (operation == 'register') {
          await _enter(tester, 'account.confirmPassword', 'secret');
        }
      }
      final key = operation == 'google' ? 'account.google' : 'account.submit';
      await _tap(tester, key);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Есть несохранённые изменения'), findsOneWidget);
      expect(repository.requests, isEmpty);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(
        scope.read(portfolioDraftControllerProvider).notes,
        'Unsaved guest notes',
      );
      expect(repository.requests, isEmpty);
      await _tap(tester, key);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Продолжить без сохранения'));
      await tester.pumpAndSettle();
      expect(repository.requests, [operation]);
      expect(find.text('Destination home'), findsOneWidget);
    });
  }

  for (final locale in [const Locale('ru'), const Locale('en')]) {
    for (final mode in ['/sign-in', '/register', '/reset-password']) {
      testWidgets(
        'Auth $mode fits 320px at text scale 2 in ${locale.languageCode}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 720);
          final repository = _AuthRepository();
          await _pumpAuth(
            tester,
            repository,
            location: mode,
            locale: locale,
            theme: StackCardTheme.light,
            textScale: 2,
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byKey(const Key('account.guest')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byKey(const Key('account.guest'))).height,
            greaterThanOrEqualTo(48),
          );
        },
      );
    }
  }

  for (final theme in [
    (name: 'dark', data: StackCardTheme.dark),
    (name: 'light', data: StackCardTheme.light),
  ]) {
    for (final mode in ['/sign-in', '/register', '/reset-password']) {
      testWidgets('Account $mode ${theme.name} centered with keyboard', (
        tester,
      ) async {
        final repository = _AuthRepository();
        await _pumpAuth(tester, repository, location: mode, theme: theme.data);
        addTearDown(tester.view.resetViewInsets);
        for (final viewport in [const Size(390, 844), const Size(768, 1024)]) {
          tester.view.physicalSize = viewport;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(StackCardPoster), findsNothing);
          expect(
            find.text(const AppStrings(Locale('ru')).tr('auth.hero')),
            findsNothing,
          );

          final brand = find.byType(StackCardBrand);
          final mark = find.descendant(
            of: brand,
            matching: find.byType(CustomPaint),
          );
          final wordmark = find.descendant(
            of: brand,
            matching: find.byType(Text),
          );
          final brandRect = tester
              .getRect(mark)
              .expandToInclude(tester.getRect(wordmark));
          final content = brandRect.expandToInclude(
            tester.getRect(find.byType(AccountAuthForm)),
          );
          expect(brandRect.center.dx, closeTo(viewport.width / 2, 1));
          expect(content.center.dx, closeTo(viewport.width / 2, 1));
          if (content.height <= viewport.height - 64) {
            expect(content.center.dy, closeTo(viewport.height / 2, 1));
          }

          final title = find.byKey(const Key('account.title'));
          final email = find.byKey(const Key('account.email'));
          expect(tester.widget<Text>(title).textAlign, TextAlign.left);
          expect(tester.getRect(title).left, tester.getRect(email).left);
          await _checkAccountAccessibility(tester);
          if (const bool.fromEnvironment('UPDATE_UI_PREVIEWS') &&
              viewport.width == 390) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../../docs/design/previews/${mode.substring(1)}_account_'
                '${theme.name}_phone_portrait.png',
              ),
            );
          }

          final emailField = find.descendant(
            of: email,
            matching: find.byType(TextFormField),
          );
          await tester.ensureVisible(emailField);
          await tester.tap(emailField);
          await tester.pump();
          expect(tester.testTextInput.isVisible, isTrue);
          tester.view.viewInsets = const FakeViewPadding(bottom: 320);
          await tester.pumpAndSettle();
          if (content.height > viewport.height - 320) {
            final scroll = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );
            expect(scroll.position.maxScrollExtent, greaterThan(0));
          }
          final submit = find.byKey(const Key('account.submit'));
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(tester.getRect(submit).top, greaterThanOrEqualTo(0));
          expect(
            tester.getRect(submit).bottom,
            lessThanOrEqualTo(viewport.height - 320 + 1),
          );
          expect(_actionEnabled(tester, 'account.submit'), isTrue);
          await _checkAccountAccessibility(tester);
          expect(tester.takeException(), isNull);
          FocusManager.instance.primaryFocus?.unfocus();
          tester.testTextInput.hide();
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
        }
        expect(repository.requests, isEmpty);
      });
    }
  }
}
