import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_document_publication_screen.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'guest has an explicit sign-in reason and cannot publish or share',
    (tester) async {
      await _open(tester, guest: true);
      expect(_button(tester, 'publication.publish').onPressed, isNull);
      expect(find.textContaining('Для публикации войдите'), findsOneWidget);
      expect(find.byKey(const ValueKey('publication.copy')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown operation hides old public link and offers exact retry',
    (tester) async {
      await _open(tester, pending: true);
      expect(find.text('Результат операции неизвестен'), findsOneWidget);
      expect(find.text('Опубликовано'), findsNothing);
      expect(find.byKey(const ValueKey('publication.copy')), findsNothing);
      await _show(tester, 'publication.checkStatus');
      expect(
        find.byKey(const ValueKey('publication.checkStatus')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('publication.retryOperation')),
        findsOneWidget,
      );
      expect(_button(tester, 'publication.publish').onPressed, isNull);
      await _show(tester, 'publication.unpublish');
      expect(_button(tester, 'publication.unpublish').onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed server link is copied opened and shared through real adapters',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
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
      final actions = _Links();
      await _open(tester, links: actions);
      await _tap(tester, 'publication.copy');
      expect(clipboard, _publicUrl.toString());
      expect(find.text('Ссылка скопирована'), findsOneWidget);
      await _tap(tester, 'publication.open');
      await _tap(tester, 'publication.share');
      expect(actions.opened, [_publicUrl]);
      expect(actions.shared, [_publicUrl]);
      expect(find.textContaining('успешно отправ'), findsNothing);
      actions.fail = true;
      await _tap(tester, 'publication.open');
      expect(
        find.textContaining('Не удалось выполнить действие'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dirty local input blocks Publish while confirmed withdrawal remains available',
    (tester) async {
      final controller = await _open(tester, dirty: true);
      expect(_button(tester, 'publication.publish').onPressed, isNull);
      await _show(tester, 'publication.unpublish');
      expect(_button(tester, 'publication.unpublish').onPressed, isNotNull);
      await _tap(tester, 'publication.unpublish');
      expect(controller.actions, isEmpty);
      await _tap(tester, 'publication.confirm');
      expect(controller.actions, [DocumentPublicationAction.unpublish]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an in-flight Save disables deletion and permits withdrawal', (
    tester,
  ) async {
    await _open(tester, saving: true);
    await _show(tester, 'publication.delete');
    expect(_button(tester, 'publication.delete').onPressed, isNull);
    expect(_button(tester, 'publication.unpublish').onPressed, isNotNull);
    expect(find.text('Сохраняем портфолио…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppStrings.supportedLocales) {
    for (final pending in [false, true]) {
      testWidgets(
        'publication narrow text2 ${locale.languageCode} pending=$pending',
        (tester) async {
          tester.view.physicalSize = const Size(320, 690);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await _open(tester, pending: pending, locale: locale, textScale: 2);
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

final _publicUrl = Uri.parse('https://public.example/p/permanent-document');

StackCardButton _button(WidgetTester tester, String key) =>
    tester.widget<StackCardButton>(find.byKey(ValueKey(key)));
Future<void> _tap(WidgetTester tester, String key) async {
  await _show(tester, key);
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<_PublicationController> _open(
  WidgetTester tester, {
  bool guest = false,
  bool pending = false,
  bool dirty = false,
  bool saving = false,
  Locale locale = const Locale('ru'),
  double textScale = 1,
  _Links? links,
}) async {
  final repository = _Repository();
  final publication = DocumentPublication(
    documentId: 'document',
    publicId: 'public-id',
    version: 1,
    visibility: DocumentPublicationVisibility.published,
    sourceMutationId: 'saved-mutation',
    url: _publicUrl,
  );
  final controller = _PublicationController(
    DocumentPublicationState(
      loading: false,
      inventory: guest
          ? null
          : DocumentPublicationInventory(
              publications: [publication],
              lifecycleGeneration: 1,
            ),
      pending: pending
          ? const DocumentPublicationMutation(
              action: DocumentPublicationAction.publish,
              operationId: 'pending-operation',
              documentId: 'document',
              expectedMutationId: 'saved-mutation',
              expectedVersion: 1,
              expectedGeneration: 1,
            )
          : null,
    ),
  );
  final container = ProviderContainer(
    overrides: [
      accountSessionProvider.overrideWithValue(
        AsyncData(guest ? null : const AuthUser(uid: 'owner')),
      ),
      documentPublicationRepositoryProvider.overrideWithValue(
        guest ? null : repository,
      ),
      documentPublicationControllerProvider.overrideWith(() => controller),
      documentLinkActionsProvider.overrideWithValue(links),
      portfolioDraftControllerProvider.overrideWith(
        () => _DraftController(dirty, saving),
      ),
      documentPublicationExpectedMutationProvider.overrideWithValue(
        guest || dirty ? null : 'saved-mutation',
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppStrings.supportedLocales,
        theme: StackCardTheme.dark,
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
        home: const PortfolioDocumentPublicationScreen(documentId: 'document'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _DraftController extends PortfolioDraftController {
  _DraftController(this.dirty, this.saving);
  final bool dirty;
  final bool saving;
  @override
  PortfolioDraftState build() {
    final date = DateTime.utc(2026, 10, 8);
    final content = PortfolioContent(
      documents: [
        PortfolioDocument(
          id: 'document',
          title: 'Frontend resume',
          kind: PortfolioDocumentKind.resume,
          createdAt: date,
          updatedAt: date,
          content: PortfolioContent(
            profile: const PortfolioProfile(
              name: 'Alex',
              headline: 'Frontend Developer',
            ),
          ),
        ),
      ],
    );
    return PortfolioDraftState(
      loading: false,
      loaded: true,
      saving: saving,
      content: content,
      notes: dirty ? 'working note' : '',
      draft: PortfolioDraft(
        notes: '',
        revision: 1,
        updatedAt: date,
        pendingSync: false,
        content: content,
      ),
    );
  }
}

class _PublicationController extends DocumentPublicationController {
  _PublicationController(this.initial);
  final DocumentPublicationState initial;
  final actions = <DocumentPublicationAction>[];
  @override
  DocumentPublicationState build() => initial;
  @override
  Future<bool> perform({
    required DocumentPublicationAction action,
    required String documentId,
  }) async {
    actions.add(action);
    return true;
  }

  @override
  Future<void> load() async {}
}

class _Repository implements DocumentPublicationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Links implements DocumentLinkActions {
  final opened = <Uri>[];
  final shared = <Uri>[];
  bool fail = false;
  @override
  Future<void> open(Uri url) async {
    if (fail) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.unavailable,
      );
    }
    opened.add(url);
  }

  @override
  Future<void> share(Uri url) async => shared.add(url);
}
