import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/home/home_screen.dart';
import 'package:app_stackcard/features/media/media.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'Home reads durable main, has exactly two actions and no editor/project images',
    (tester) async {
      final saved = _workspace('Сохранённое имя');
      final working = saved.copyWith(
        documents: [
          saved.documents.single.copyWith(
            content: PortfolioContent(
              profile: const PortfolioProfile(name: 'Введённое имя'),
            ),
          ),
        ],
      );
      await _open(tester, saved: saved, working: working);
      expect(find.text('Сохранённое имя'), findsOneWidget);
      expect(find.text('Введённое имя'), findsNothing);
      expect(find.byType(StackCardButton), findsNWidgets(2));
      expect(find.byKey(const Key('home.download')), findsOneWidget);
      expect(find.byKey(const Key('home.share')), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Редактировать'), findsNothing);
      expect(find.text('Ваша работа.'), findsNothing);
      expect(find.text('Навыки'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty saved portfolio keeps short state and disables output actions',
    (tester) async {
      final saved = _workspace('');
      await _open(tester, saved: saved);
      expect(find.text('Портфолио пока пустое'), findsOneWidget);
      expect(_button(tester, 'home.download').onPressed, isNull);
      expect(_button(tester, 'home.share').onPressed, isNull);
      expect(find.text('Проекты'), findsNothing);
      expect(find.text('Имя не указано'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy documents guide to explicit migration without picking a random source',
    (tester) async {
      await _open(
        tester,
        saved: _workspace('Прежний документ')
            .copyWith(clearMainPortfolioId: true),
      );
      expect(find.text('Прежний документ'), findsNothing);
      expect(
        find.textContaining('выберите основу из прежних документов'),
        findsOneWidget,
      );
      expect(_button(tester, 'home.download').onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'download passes saved version without project images and preserves cancellation',
    (tester) async {
      final saved = _workspace('Сохранённое имя', project: true);
      final working = saved.copyWith(
        documents: [
          saved.documents.single.copyWith(
            content: PortfolioContent(
              profile: const PortfolioProfile(name: 'Введённое имя'),
            ),
          ),
        ],
      );
      final generator = _PdfGenerator();
      final files = _PdfFiles()..result = false;
      await _open(
        tester,
        saved: saved,
        working: working,
        generator: generator,
        files: files,
      );
      await _tap(tester, 'home.download');
      expect(generator.contents.single.profile.name, 'Сохранённое имя');
      expect(generator.contents.single.projects.single.imagePaths, isEmpty);
      expect(files.bytes.single, _pdfBytes);
      expect(find.text('Портфолио сохранено в PDF.'), findsNothing);
      files.result = true;
      await _tap(tester, 'home.download');
      expect(find.text('Портфолио сохранено в PDF.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owner change resets a pending PDF and ignores its late result', (
    tester,
  ) async {
    final generator = _PendingPdfGenerator();
    final files = _PdfFiles();
    final container = await _open(
      tester,
      saved: _workspace('Первый владелец'),
      generator: generator,
      files: files,
    );
    await _tap(tester, 'home.download', settle: false);
    expect(_button(tester, 'home.download').loading, isTrue);
    container.updateOverrides([
      portfolioDraftRepositoryProvider.overrideWithValue(
        MemoryPortfolioDraftRepository(),
      ),
      portfolioDraftControllerProvider.overrideWith(
        () => _DraftController(_workspace('Второй владелец'), null),
      ),
      accountSessionProvider.overrideWithValue(const AsyncData(null)),
      portfolioPdfGeneratorProvider.overrideWithValue(generator),
      portfolioPdfFileActionsProvider.overrideWithValue(files),
      documentLinkActionsProvider.overrideWithValue(null),
      documentPublicationRepositoryProvider.overrideWithValue(null),
      portfolioSyncStateProvider.overrideWithValue(
        const PortfolioSyncState(
          status: PortfolioSyncStatus.synced,
          confirmedMutationId: 'saved-mutation',
        ),
      ),
    ]);
    (container.read(
      portfolioDraftControllerProvider.notifier,
    ) as _DraftController).replaceSaved(_workspace('Второй владелец'));
    await tester.pumpAndSettle();
    expect(find.text('Второй владелец'), findsOneWidget);
    expect(find.text('Первый владелец'), findsNothing);
    expect(_button(tester, 'home.download').loading, isFalse);
    expect(_button(tester, 'home.download').onPressed, isNotNull);
    generator.pending.complete(_pdfBytes);
    await tester.pumpAndSettle();
    expect(files.bytes, isEmpty);
    expect(find.text('Портфолио сохранено в PDF.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy URL photo is read from the saved version before PDF export',
    (tester) async {
      final saved = _workspace('Сохранённое имя', avatarUrl: _legacyAvatarUrl);
      final generator = _PdfGenerator();
      final files = _PdfFiles();
      final reader = _LegacyAvatarReader();
      await _open(
        tester,
        saved: saved,
        working: _workspace(
          'Введённое имя',
          avatarUrl: 'https://images.example.com/unsaved.jpg',
        ),
        generator: generator,
        files: files,
        legacyReader: reader,
      );
      await _tap(tester, 'home.download');
      expect(reader.urls, [_legacyAvatarUrl]);
      expect(generator.contents.single.profile.name, 'Сохранённое имя');
      expect(generator.avatars.single, _legacyAvatarBytes);
      expect(files.bytes, [_pdfBytes]);
      expect(find.text('Портфолио сохранено в PDF.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed legacy photo read cannot announce an incomplete successful PDF',
    (tester) async {
      final generator = _PdfGenerator();
      final files = _PdfFiles();
      final reader = _LegacyAvatarReader()
        ..readResult = (_) async => throw const PortfolioMediaFailure(
          PortfolioMediaFailureKind.unavailable,
        );
      await _open(
        tester,
        saved: _workspace('Имя', avatarUrl: _legacyAvatarUrl),
        generator: generator,
        files: files,
        legacyReader: reader,
      );
      await _tap(tester, 'home.download');
      expect(reader.urls, [_legacyAvatarUrl]);
      expect(generator.contents, isEmpty);
      expect(files.bytes, isEmpty);
      expect(find.textContaining('Не удалось сохранить PDF.'), findsOneWidget);
      expect(find.text('Портфолио сохранено в PDF.'), findsNothing);
      expect(_button(tester, 'home.download').onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'private avatar path failure never falls back to its external URL',
    (tester) async {
      final generator = _PdfGenerator();
      final files = _PdfFiles();
      final reader = _LegacyAvatarReader();
      final media = _FailingMedia();
      await _open(
        tester,
        saved: _workspace(
          'Имя',
          avatarUrl: _legacyAvatarUrl,
          avatarPath:
              'accounts/owner/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg',
        ),
        generator: generator,
        files: files,
        legacyReader: reader,
        media: media,
      );
      await _tap(tester, 'home.download');
      expect(media.paths, isNotEmpty);
      expect(reader.urls, isEmpty);
      expect(generator.contents, isEmpty);
      expect(files.bytes, isEmpty);
      expect(find.textContaining('Не удалось сохранить PDF.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'migrated hidden legacy profile does not read private or external avatar for PDF',
    (tester) async {
      final generator = _PdfGenerator();
      final reader = _LegacyAvatarReader();
      final media = _FailingMedia();
      await _open(
        tester,
        saved: _workspace(
          'Скрытый профиль',
          project: true,
          avatarUrl: _legacyAvatarUrl,
          hideProfile: true,
          avatarPath:
              'accounts/owner/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg',
        ),
        generator: generator,
        legacyReader: reader,
        media: media,
      );
      await _tap(tester, 'home.download');
      expect(reader.urls, isEmpty);
      expect(media.paths, isEmpty);
      expect(generator.avatars.single, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late legacy photo read cannot generate or save for the next owner',
    (tester) async {
      final pending = Completer<Uint8List>();
      final reader = _LegacyAvatarReader()..readResult = (_) => pending.future;
      final generator = _PdfGenerator();
      final files = _PdfFiles();
      final container = await _open(
        tester,
        saved: _workspace('Первый владелец', avatarUrl: _legacyAvatarUrl),
        generator: generator,
        files: files,
        legacyReader: reader,
      );
      await _tap(tester, 'home.download', settle: false);
      expect(reader.urls, [_legacyAvatarUrl]);
      expect(_button(tester, 'home.download').loading, isTrue);
      container.updateOverrides([
        portfolioDraftRepositoryProvider.overrideWithValue(
          MemoryPortfolioDraftRepository(),
        ),
        portfolioDraftControllerProvider.overrideWith(
          () => _DraftController(_workspace('Второй владелец'), null),
        ),
        accountSessionProvider.overrideWithValue(const AsyncData(null)),
        portfolioPdfGeneratorProvider.overrideWithValue(generator),
        portfolioPdfFileActionsProvider.overrideWithValue(files),
        portfolioLegacyAvatarReaderProvider.overrideWithValue(reader),
        documentLinkActionsProvider.overrideWithValue(null),
        documentPublicationRepositoryProvider.overrideWithValue(null),
        portfolioSyncStateProvider.overrideWithValue(
          const PortfolioSyncState(
            status: PortfolioSyncStatus.synced,
            confirmedMutationId: 'saved-mutation',
          ),
        ),
      ]);
      (container.read(
        portfolioDraftControllerProvider.notifier,
      ) as _DraftController).replaceSaved(_workspace('Второй владелец'));
      await tester.pumpAndSettle();
      expect(find.text('Второй владелец'), findsOneWidget);
      expect(_button(tester, 'home.download').loading, isFalse);
      pending.complete(_legacyAvatarBytes);
      await tester.pumpAndSettle();
      expect(generator.contents, isEmpty);
      expect(files.bytes, isEmpty);
      expect(find.text('Портфолио сохранено в PDF.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('confirmed publication shares its real public URL', (
    tester,
  ) async {
    final links = _Links();
    final publication = _PublicationController(published: true);
    await _open(
      tester,
      saved: _workspace('Имя'),
      links: links,
      publication: publication,
    );
    await _tap(tester, 'home.share');
    expect(links.shared, [_publicUrl]);
    expect(publication.actions, isEmpty);
    expect(find.text('Опубликовать портфолио?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unpublished portfolio requires confirmation and publishes saved version before sharing',
    (tester) async {
      final links = _Links();
      final publication = _PublicationController(published: false);
      final saved = _workspace('Сохранённое имя');
      await _open(
        tester,
        saved: saved,
        working: saved.copyWith(
          documents: [
            saved.documents.single.copyWith(
              content: PortfolioContent(
                profile: const PortfolioProfile(name: 'Введённое имя'),
              ),
            ),
          ],
        ),
        links: links,
        publication: publication,
      );
      await _tap(tester, 'home.share', settle: false);
      expect(find.text('Опубликовать портфолио?'), findsOneWidget);
      expect(links.shared, isEmpty);
      expect(publication.actions, isEmpty);
      await tester.tap(find.text('Опубликовать и поделиться'));
      await tester.pumpAndSettle();
      expect(publication.actions, [
        (DocumentPublicationAction.publish, 'main', true),
      ]);
      expect(links.shared, [_publicUrl]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'newer saved version offers existing link or explicit public update',
    (tester) async {
      final links = _Links();
      final publication = _PublicationController(published: true, old: true);
      await _open(
        tester,
        saved: _workspace('Имя'),
        links: links,
        publication: publication,
      );
      await _tap(tester, 'home.share', settle: false);
      expect(find.text('Есть новая сохранённая версия'), findsOneWidget);
      await tester.tap(find.text('Поделиться текущей'));
      await tester.pumpAndSettle();
      expect(publication.actions, isEmpty);
      expect(links.shared, [_publicUrl]);
      await _tap(tester, 'home.share', settle: false);
      await tester.tap(find.text('Обновить и поделиться'));
      await tester.pumpAndSettle();
      expect(publication.actions, [
        (DocumentPublicationAction.publish, 'main', true),
      ]);
      expect(links.shared.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed system share copies only confirmed public link as fallback',
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
      await _open(
        tester,
        saved: _workspace('Имя'),
        links: _Links()..fail = true,
        publication: _PublicationController(published: true),
      );
      await _tap(tester, 'home.share');
      expect(clipboard, _publicUrl.toString());
      expect(find.text('Ссылка скопирована.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home stays within width320 at text2 with long content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    await _open(
      tester,
      saved: _workspace(
        'Очень длинное имя для проверки переноса строки на телефоне',
        project: true,
      ),
      textScale: 2,
    );
    expect(find.byType(StackCardButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('main.project.project')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main.project.project')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _publicUrl = Uri.parse('https://portfolio.example/d/public-id');
final _pdfBytes = Uint8List.fromList(
  '%PDF-1.7\nFake adapter fixture'.codeUnits,
);
const _legacyAvatarUrl = 'https://images.example.com/saved-avatar.jpg';
final _legacyAvatarBytes = Uint8List.fromList([1, 2, 3]);

PortfolioContent _workspace(
  String name, {
  bool project = false,
  String avatarUrl = '',
  String avatarPath = '',
  bool hideProfile = false,
}) {
  final projects = [
    if (project)
      PortfolioProject(
        id: 'project',
        title: 'Длинное название проекта',
        description: 'Краткое описание проекта',
        technologies: const [],
        iconId: 'camera',
        imagePaths: const [
          'accounts/owner/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg',
        ],
      ),
  ];
  final content = PortfolioContent(
    profile: PortfolioProfile(
      name: name,
      avatarUrl: avatarUrl,
      avatarPath: avatarPath,
    ),
    blocks: hideProfile
        ? const [
            PortfolioBlock(kind: PortfolioBlockKind.profile, visible: false),
            PortfolioBlock(kind: PortfolioBlockKind.featuredProjects),
          ]
        : null,
  );
  return PortfolioContent(
    mainPortfolioId: 'main',
    projects: projects,
    documents: [
      PortfolioDocument(
        id: 'main',
        title: 'Основное',
        kind: PortfolioDocumentKind.portfolio,
        createdAt: DateTime.utc(2026, 10, 11),
        updatedAt: DateTime.utc(2026, 10, 11),
        content: hideProfile
            ? mainPortfolioMigrationContent(
                PortfolioContent(projects: projects),
                content,
              )
            : content,
        projects: [
          if (project) const PortfolioProjectAttachment(projectId: 'project'),
        ],
      ),
    ],
  );
}

Future<ProviderContainer> _open(
  WidgetTester tester, {
  required PortfolioContent saved,
  PortfolioContent? working,
  _PdfGenerator? generator,
  _PdfFiles? files,
  _Links? links,
  _PublicationController? publication,
  _LegacyAvatarReader? legacyReader,
  _FailingMedia? media,
  double textScale = 1,
}) async {
  final container = ProviderContainer(
    overrides: [
      portfolioDraftRepositoryProvider.overrideWithValue(
        MemoryPortfolioDraftRepository(),
      ),
      portfolioDraftControllerProvider.overrideWith(
        () => _DraftController(saved, working),
      ),
      accountSessionProvider.overrideWithValue(
        AsyncData(
          publication == null && media == null
              ? null
              : const AuthUser(uid: 'owner'),
        ),
      ),
      portfolioPdfGeneratorProvider.overrideWithValue(
        generator ?? _PdfGenerator(),
      ),
      portfolioPdfFileActionsProvider.overrideWithValue(files ?? _PdfFiles()),
      if (legacyReader != null)
        portfolioLegacyAvatarReaderProvider.overrideWithValue(legacyReader),
      if (media != null)
        portfolioMediaRepositoryProvider.overrideWithValue(media),
      documentLinkActionsProvider.overrideWithValue(links),
      documentPublicationRepositoryProvider.overrideWithValue(
        publication == null ? null : _PublicationRepository(),
      ),
      if (publication != null)
        documentPublicationControllerProvider.overrideWith(() => publication),
      portfolioSyncStateProvider.overrideWithValue(
        const PortfolioSyncState(
          status: PortfolioSyncStatus.synced,
          confirmedMutationId: 'saved-mutation',
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: StackCardTheme.light,
        locale: const Locale('ru'),
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
        home: const Scaffold(body: HomeScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

StackCardButton _button(WidgetTester tester, String key) =>
    tester.widget<StackCardButton>(find.byKey(ValueKey(key)));
Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Диалог оставляет индикатор операции активным до явного выбора.
    await tester.pump(const Duration(milliseconds: 300));
  }
}

class _DraftController extends PortfolioDraftController {
  _DraftController(this.saved, this.working);
  final PortfolioContent saved;
  final PortfolioContent? working;
  void replaceSaved(PortfolioContent content) {
    state = state.copyWith(
      content: content,
      draft: PortfolioDraft(
        notes: '',
        revision: 1,
        updatedAt: DateTime.utc(2026, 1, 1),
        pendingSync: false,
        content: content,
      ),
    );
  }

  @override
  PortfolioDraftState build() => PortfolioDraftState(
    loading: false,
    loaded: true,
    content: working ?? saved,
    draft: PortfolioDraft(
      notes: '',
      revision: 1,
      updatedAt: DateTime.utc(2026, 10, 11),
      pendingSync: false,
      content: saved,
    ),
  );
}

class _PdfGenerator implements PortfolioPdfGenerator {
  final contents = <PortfolioContent>[];
  final avatars = <Uint8List?>[];
  @override
  Future<Uint8List> generate(
    PortfolioContent savedContent, {
    Uint8List? avatarBytes,
  }) async {
    contents.add(savedContent);
    avatars.add(avatarBytes);
    return _pdfBytes;
  }
}

class _LegacyAvatarReader implements PortfolioLegacyAvatarReader {
  final urls = <String>[];
  Future<Uint8List> Function(String) readResult = (_) async =>
      _legacyAvatarBytes;
  @override
  Future<Uint8List> read(String url) {
    urls.add(url);
    return readResult(url);
  }
}

class _FailingMedia implements PortfolioMediaRepository {
  final paths = <String>[];
  @override
  String get ownerUid => 'owner';
  @override
  Future<Uint8List> read(String path) async {
    paths.add(path);
    throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PendingPdfGenerator extends _PdfGenerator {
  final pending = Completer<Uint8List>();
  @override
  Future<Uint8List> generate(
    PortfolioContent savedContent, {
    Uint8List? avatarBytes,
  }) => pending.future;
}

class _PdfFiles implements PortfolioPdfFileActions {
  final bytes = <Uint8List>[];
  bool result = true;
  @override
  Future<bool> savePdf(
    Uint8List value, {
    String filename = 'stackcard-portfolio.pdf',
  }) async {
    bytes.add(value);
    return result;
  }
}

class _Links implements DocumentLinkActions {
  final shared = <Uri>[];
  bool fail = false;
  @override
  Future<void> open(Uri url) async {}
  @override
  Future<void> share(Uri url) async {
    if (fail) throw StateError('unavailable');
    shared.add(url);
  }
}

class _PublicationRepository implements DocumentPublicationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PublicationController extends DocumentPublicationController {
  _PublicationController({required this.published, this.old = false});
  final bool published;
  final bool old;
  final actions = <(DocumentPublicationAction, String, bool)>[];
  DocumentPublication _publication({bool old = false}) => DocumentPublication(
    documentId: 'main',
    publicId: 'public-id',
    version: 1,
    visibility: DocumentPublicationVisibility.published,
    sourceMutationId: old ? 'older-mutation' : 'saved-mutation',
    url: _publicUrl,
  );
  @override
  DocumentPublicationState build() => DocumentPublicationState(
    loading: false,
    inventory: DocumentPublicationInventory(
      publications: [if (published) _publication(old: old)],
      lifecycleGeneration: 1,
    ),
  );
  @override
  Future<void> load() async {}
  @override
  Future<bool> perform({
    required DocumentPublicationAction action,
    required String documentId,
    bool savedVersion = false,
  }) async {
    actions.add((action, documentId, savedVersion));
    state = DocumentPublicationState(
      loading: false,
      inventory: DocumentPublicationInventory(
        publications: [_publication()],
        lifecycleGeneration: 1,
      ),
    );
    return true;
  }
}
