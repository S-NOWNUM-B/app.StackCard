import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/data/developer_card_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/developer_card_qr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/developer_card_fixture.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope');
    font.addFont(rootBundle.load('assets/fonts/Manrope-Regular.ttf'));
    await font.load();
  });
  testWidgets(
    'published card has identity, technologies, brand and exact QR URL',
    (tester) async {
      final repository = _Cards();
      final controller = _Publications();
      final links = _Links();
      await _open(tester, repository, controller, links: links);
      expect(find.text('Анна Ёлкина'), findsOneWidget);
      expect(find.text('Flutter developer'), findsOneWidget);
      expect(find.text('@anna-dev'), findsOneWidget);
      expect(find.byType(DeveloperCardQr), findsOneWidget);
      expect(
        tester.widget<DeveloperCardQr>(find.byType(DeveloperCardQr)).url,
        publication().url,
      );
      final share = find.byKey(const ValueKey('developerCard.share'));
      await tester.scrollUntilVisible(share, 250, scrollable: _scrollable);
      await tester.pumpAndSettle();
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(links.shared, [publication().url]);
      expect(controller.loads, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Copy passes only the confirmed public URL to Clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _open(tester, _Cards(), _Publications());
    final copy = find.byKey(const ValueKey('developerCard.copy'));
    await tester.scrollUntilVisible(copy, 250, scrollable: _scrollable);
    await tester.pumpAndSettle();
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, publication().url.toString());
    expect(find.text('Ссылка скопирована.'), findsOneWidget);
  });
  testWidgets(
    'withdrawal removes the QR and actions while the card remains open',
    (tester) async {
      final repository = _Cards();
      final controller = _Publications();
      await _open(tester, repository, controller);
      controller.withdraw();
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperCardQr), findsNothing);
      expect(find.byKey(const ValueKey('developerCard.share')), findsNothing);
      expect(find.textContaining('ещё не опубликовано'), findsOneWidget);
    },
  );
  testWidgets(
    'Copy waits for server confirmation after transient cache event',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _open(tester, _CacheThenServerCards(), _RefreshingPublications());
      final copy = find.byKey(const ValueKey('developerCard.copy'));
      await tester.scrollUntilVisible(copy, 250, scrollable: _scrollable);
      await tester.pumpAndSettle();
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copied, publication().url.toString());
      expect(find.text('Ссылка скопирована.'), findsOneWidget);
    },
  );
  testWidgets(
    'unknown pending publication cannot render a previously known QR',
    (tester) async {
      final controller = _Publications();
      await _open(tester, _Cards(), controller);
      controller.unknown();
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperCardQr), findsNothing);
      expect(
        find.textContaining('Результат публикации неизвестен'),
        findsOneWidget,
      );
    },
  );
  for (final changeOwner in [false, true]) {
    testWidgets(
      'late server data cannot Share after ${changeOwner ? 'owner change' : 'withdrawal'}',
      (tester) async {
        final cards = _WaitingCards();
        addTearDown(cards.late.close);
        final publications = _RefreshingPublications();
        final links = _Links();
        final container = await _open(
          tester,
          cards,
          publications,
          links: links,
        );
        final share = find.byKey(const ValueKey('developerCard.share'));
        await tester.scrollUntilVisible(share, 250, scrollable: _scrollable);
        await tester.pumpAndSettle();
        await tester.tap(share);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(links.shared, isEmpty);
        if (changeOwner) {
          container.updateOverrides([
            developerCardRepositoryProvider.overrideWithValue(null),
            documentPublicationControllerProvider.overrideWith(
              () => publications,
            ),
            documentLinkActionsProvider.overrideWithValue(links),
          ]);
        } else {
          publications.withdraw();
        }
        await tester.pumpAndSettle();
        cards.late.add(decodeDeveloperCard(publicCardFixture(), publication()));
        await tester.pumpAndSettle();
        expect(links.shared, isEmpty);
        expect(find.byType(DeveloperCardQr), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'owner change while confirming Share never invokes a native action',
    (tester) async {
      final repository = _Cards();
      final controller = _Publications();
      final links = _Links();
      final container = await _open(
        tester,
        repository,
        controller,
        links: links,
      );
      controller.wait = Completer<void>();
      final share = find.byKey(const ValueKey('developerCard.share'));
      await tester.scrollUntilVisible(share, 250, scrollable: _scrollable);
      await tester.pumpAndSettle();
      await tester.tap(share);
      await tester.pump();
      container.updateOverrides([
        developerCardRepositoryProvider.overrideWithValue(null),
        documentPublicationControllerProvider.overrideWith(() => controller),
        documentLinkActionsProvider.overrideWithValue(links),
      ]);
      await tester.pump();
      controller.wait!.complete();
      await tester.pumpAndSettle();
      expect(links.shared, isEmpty);
      expect(find.byType(DeveloperCardQr), findsNothing);
      expect(find.textContaining('Аккаунт изменился'), findsOneWidget);
    },
  );
  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'card and share actions scroll without overflow at $size text2',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _open(tester, _Cards(), _Publications(), scale: 2);
        final share = find.byKey(const ValueKey('developerCard.share'));
        await tester.scrollUntilVisible(share, 300, scrollable: _scrollable);
        await tester.pumpAndSettle();
        expect(tester.getSize(share).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'QR capture preserves a white quiet zone for independent decoding',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final card = decodeDeveloperCard(publicCardFixture(), publication());
      await tester.pumpWidget(
        MaterialApp(
          theme: StackCardTheme.light,
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('capture'),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DeveloperCardView(card: card),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const export = bool.fromEnvironment('EXPORT_DEVELOPER_CARD_PREVIEW');
      if (export) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/private/tmp/stackcard-phase15-card.png')
              .writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.byType(DeveloperCardQr), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  _Cards cards,
  _Publications publications, {
  _Links? links,
  double scale = 1,
}) async {
  final container = ProviderContainer(
    overrides: [
      developerCardRepositoryProvider.overrideWithValue(cards),
      documentPublicationControllerProvider.overrideWith(() => publications),
      documentLinkActionsProvider.overrideWithValue(links ?? _Links()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: StackCardTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const DeveloperCardScreen(documentId: 'main'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _Cards implements DeveloperCardRepository {
  @override
  String get ownerUid => 'owner';
  @override
  Stream<DeveloperCard> watch(DocumentPublication publication) =>
      Stream.value(decodeDeveloperCard(publicCardFixture(), publication));
}

class _CacheThenServerCards extends _Cards {
  int watches = 0;
  @override
  Stream<DeveloperCard> watch(DocumentPublication publication) async* {
    if (++watches > 1) {
      // cache/pending остаётся ошибкой: ни QR, ни action не используют эти данные.
      yield* Stream<DeveloperCard>.error(
        const DeveloperCardFailure(DeveloperCardFailureKind.unavailable),
      );
    }
    yield decodeDeveloperCard(publicCardFixture(), publication);
  }
}

class _RefreshingPublications extends _Publications {
  @override
  Future<void> load() async {
    if (++loads == 1) return;
    final inventory = state.inventory;
    state = DocumentPublicationState(inventory: inventory);
    await Future<void>.value();
    state = DocumentPublicationState(inventory: inventory, loading: false);
  }
}

class _WaitingCards extends _Cards {
  int watches = 0;
  final late = StreamController<DeveloperCard>.broadcast();
  @override
  Stream<DeveloperCard> watch(DocumentPublication publication) async* {
    if (++watches == 1) {
      yield decodeDeveloperCard(publicCardFixture(), publication);
    } else {
      yield* Stream<DeveloperCard>.error(
        const DeveloperCardFailure(DeveloperCardFailureKind.unavailable),
      );
      yield* late.stream;
    }
  }
}

class _Publications extends DocumentPublicationController {
  int loads = 0;
  Completer<void>? wait;
  @override
  DocumentPublicationState build() => DocumentPublicationState(
    loading: false,
    inventory: DocumentPublicationInventory(
      publications: [publication()],
      lifecycleGeneration: 1,
    ),
  );
  @override
  Future<void> load() async {
    loads++;
    await wait?.future;
  }

  void withdraw() {
    state = DocumentPublicationState(
      loading: false,
      inventory: DocumentPublicationInventory(
        publications: [],
        lifecycleGeneration: 1,
      ),
    );
  }

  void unknown() {
    state = DocumentPublicationState(
      loading: false,
      inventory: state.inventory,
      pending: const DocumentPublicationMutation(
        action: DocumentPublicationAction.unpublish,
        operationId: 'operation',
        documentId: 'main',
        expectedMutationId: 'published-mutation',
        expectedVersion: 1,
        expectedGeneration: 1,
      ),
    );
  }
}

class _Links implements DocumentLinkActions {
  final shared = <Uri>[];
  @override
  Future<void> open(Uri url) async {}
  @override
  Future<void> share(Uri url) async {
    shared.add(url);
  }
}

Finder get _scrollable => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;
