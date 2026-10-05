import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/home/home_screen.dart';
import 'package:app_stackcard/main.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledAuthRepository implements AuthRepository {
  final requests = <String>[];
  final completions = <Completer<DemoSession>>[];

  @override
  Future<DemoSession> openDemo(String email) {
    requests.add(email);
    final completion = Completer<DemoSession>();
    completions.add(completion);
    return completion.future;
  }
}

void main() {
  test(
    'Auth controller uses injected repository and blocks duplicate requests',
    () async {
      final repository = _ControlledAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      expect(container.read(authControllerProvider).requireValue, isNull);

      final opened = controller.openDemo('other@example.dev');
      expect(container.read(authControllerProvider).isLoading, isTrue);
      expect(await controller.openDemo('duplicate@example.dev'), isFalse);
      expect(repository.requests, ['other@example.dev']);

      final session = DemoSession(email: 'Other@Example.Dev');
      repository.completions.single.complete(session);
      expect(await opened, isTrue);
      expect(
        container.read(authControllerProvider).requireValue,
        same(session),
      );
    },
  );

  test(
    'Pending auth completion cannot update a disposed app session',
    () async {
      final repository = _ControlledAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      final controller = container.read(authControllerProvider.notifier);
      final opened = controller.openDemo('alex@example.dev');
      container.dispose();
      repository.completions.single.complete(
        DemoSession(email: 'alex@example.dev'),
      );
      expect(await opened, isFalse);
    },
  );

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

  testWidgets('Invalid form input never reaches the injected repository', (
    tester,
  ) async {
    final repository = _ControlledAuthRepository();
    await tester.pumpWidget(
      StackCardApp(
        providerOverrides: [
          authRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.ensureVisible(find.text('Открыть демо'));
    await tester.tap(find.text('Открыть демо'));
    await tester.pumpAndSettle();
    expect(repository.requests, isEmpty);
    expect(find.text('Укажите корректный email'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Failed demo entry stays on sign-in and retry opens the demo', (
    tester,
  ) async {
    final repository = _ControlledAuthRepository();
    await tester.pumpWidget(
      StackCardApp(
        providerOverrides: [
          authRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Открыть демо'));
    await tester.tap(find.text('Открыть демо'));
    await tester.pump();
    final button = tester.widget<StackCardButton>(find.byType(StackCardButton));
    expect(button.loading, isTrue);
    expect(button.onPressed, isNull);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    repository.completions.single.completeError(StateError('demo unavailable'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.text(
        'Не удалось открыть демо. Нажмите «Открыть демо», чтобы повторить.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<StackCardButton>(find.byType(StackCardButton)).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isTrue,
    );

    await tester.ensureVisible(find.text('Открыть демо'));
    await tester.tap(find.text('Открыть демо'));
    await tester.pump();
    expect(repository.requests, ['alex@example.dev', 'alex@example.dev']);
    repository.completions.last.complete(
      DemoSession(email: 'alex@example.dev'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(
      container.read(authControllerProvider).requireValue?.email,
      'alex@example.dev',
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
