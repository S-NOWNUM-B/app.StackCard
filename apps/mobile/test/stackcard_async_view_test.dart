import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/shared/widgets/stackcard_async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Owner extends Notifier<String> {
  @override
  String build() => 'owner-a';

  void change(String value) => state = value;
}

final _owner = NotifierProvider<_Owner, String>(_Owner.new);

class _AsyncHarness {
  final container = ProviderContainer();
  final requests = <Completer<String>>[];
  var retries = 0;

  late final document = FutureProvider<String>((ref) {
    ref.watch(_owner);
    final request = Completer<String>();
    requests.add(request);
    return request.future;
  });

  Future<void> mount(
    WidgetTester tester,
    ThemeData theme, {
    bool retain = true,
  }) async {
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => StackCardAsyncView<String>(
                state: ref.watch(document),
                retainDataDuringRefresh: retain,
                data: (value) =>
                    Text(value, key: const ValueKey('private_data')),
                onRetry: () {
                  retries++;
                  ref.invalidate(document);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> complete(WidgetTester tester, String value) async {
    requests.last.complete(value);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> fail(WidgetTester tester) async {
    requests.last.completeError(StateError('Read failed'));
    await tester.pump();
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final configuration in [
    ('dark', StackCardTheme.dark),
    ('light', StackCardTheme.light),
  ]) {
    testWidgets(
      '${configuration.$1} initial loading and error require real retry',
      (tester) async {
        final harness = _AsyncHarness();
        await harness.mount(tester, configuration.$2);
        expect(find.byKey(const ValueKey('private_data')), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await harness.fail(tester);
        expect(find.byKey(const ValueKey('private_data')), findsNothing);
        const strings = AppStrings(Locale('ru'));
        expect(find.text(strings.tr('async.errorTitle')), findsOneWidget);
        await tester.tap(find.text(strings.tr('common.retry')));
        await tester.pump();
        expect(harness.retries, 1);
        expect(harness.requests, hasLength(2));
        expect(find.byKey(const ValueKey('private_data')), findsNothing);
        await harness.complete(tester, 'Actual saved document');
        expect(find.text('Actual saved document'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${configuration.$1} explicit refresh retains content with progress',
      (tester) async {
        final harness = _AsyncHarness();
        await harness.mount(tester, configuration.$2);
        await harness.complete(tester, 'Private document of owner A');
        harness.container.invalidate(harness.document);
        await tester.pump();
        expect(harness.container.read(harness.document).isRefreshing, isTrue);
        expect(find.text('Private document of owner A'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        await harness.complete(tester, 'Refreshed document of owner A');
        expect(find.text('Private document of owner A'), findsNothing);
        expect(find.text('Refreshed document of owner A'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${configuration.$1} default refresh does not opt into retained data',
      (tester) async {
        final harness = _AsyncHarness();
        await harness.mount(tester, configuration.$2, retain: false);
        await harness.complete(tester, 'Previous document');
        harness.container.invalidate(harness.document);
        await tester.pump();
        expect(find.text('Previous document'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await harness.complete(tester, 'New document');
        expect(find.text('New document'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${configuration.$1} owner dependency reload hides previous private content',
      (tester) async {
        final harness = _AsyncHarness();
        await harness.mount(tester, configuration.$2);
        await harness.complete(tester, 'Private document of owner A');
        harness.container.read(_owner.notifier).change('owner-b');
        await tester.pump();
        expect(harness.container.read(harness.document).isReloading, isTrue);
        expect(find.text('Private document of owner A'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await harness.complete(tester, 'Private document of owner B');
        expect(find.text('Private document of owner B'), findsOneWidget);
        expect(find.text('Private document of owner A'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${configuration.$1} refresh failure with previous data remains an error',
      (tester) async {
        final harness = _AsyncHarness();
        await harness.mount(tester, configuration.$2);
        await harness.complete(tester, 'Previously read private document');
        harness.container.invalidate(harness.document);
        await tester.pump();
        await harness.fail(tester);
        final state = harness.container.read(harness.document);
        expect(state.hasValue, isTrue);
        expect(state.hasError, isTrue);
        expect(find.text('Previously read private document'), findsNothing);
        const strings = AppStrings(Locale('ru'));
        expect(find.text(strings.tr('async.errorTitle')), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
