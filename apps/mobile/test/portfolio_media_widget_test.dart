import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/localization/media_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/media/media.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _currentRepositoryProvider =
    NotifierProvider<_RepositorySelection, PortfolioMediaRepository?>(
      _RepositorySelection.new,
    );

class _RepositorySelection extends Notifier<PortfolioMediaRepository?> {
  @override
  PortfolioMediaRepository? build() => null;
  void select(PortfolioMediaRepository? value) => state = value;
}

void main() {
  test('Media translations match and belong to both app catalogues', () {
    expect(russianMediaStrings.keys.toSet(), englishMediaStrings.keys.toSet());
    for (final locale in AppStrings.supportedLocales) {
      expect(AppStrings(locale).keys, containsAll(englishMediaStrings.keys));
    }
  });

  testWidgets(
    'Upload shows progress, blocks Apply and stays local until Apply',
    (tester) async {
      final media = _MediaRepository()..pending = Completer<String>();
      final h = await _pump(tester, media: media);
      await _tap(tester, 'media_gallery', settle: false);
      media.progress?.call(.45);
      await tester.pump();
      expect(find.text('Загрузка: 45%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('media_prepared_preview')),
        findsOneWidget,
      );
      expect(_button(tester, 'builder_form_apply').onPressed, isNull);
      expect(h.content.profile.avatarPath, isEmpty);
      media.pending!.complete(_path('owner', 'a'));
      await tester.pumpAndSettle();
      expect(h.content.profile.avatarPath, isEmpty);
      await _tap(tester, 'builder_form_apply');
      expect(h.content.profile.avatarPath, _path('owner', 'a'));
      expect(h.draft.saves, 0);
      expect(media.deleted, isEmpty);
    },
  );

  testWidgets('Upload retry reuses prepared bytes and does not reopen picker', (
    tester,
  ) async {
    final media = _MediaRepository()..failNext = true;
    final picker = _Picker();
    final h = await _pump(tester, media: media, picker: picker);
    await _tap(tester, 'media_gallery');
    expect(find.byKey(const ValueKey('media_upload_error')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('media_prepared_preview')),
      findsOneWidget,
    );
    expect(h.content.profile.avatarPath, isEmpty);
    await _tap(tester, 'media_retry');
    expect(picker.calls, 1);
    expect(media.uploads, 2);
    expect(find.byKey(const ValueKey('media_upload_error')), findsNothing);
    await _tap(tester, 'builder_form_apply');
    expect(h.content.profile.avatarPath, _path('owner', 'a'));
  });

  testWidgets('Picker cancel and permission denial preserve existing avatar', (
    tester,
  ) async {
    final path = _path('owner', 'b');
    final picker = _Picker()..cancel = true;
    final h = await _pump(
      tester,
      media: _MediaRepository(),
      picker: picker,
      content: PortfolioContent(profile: PortfolioProfile(avatarPath: path)),
    );
    await _tap(tester, 'media_gallery');
    expect(h.content.profile.avatarPath, path);
    expect(find.byKey(const ValueKey('media_upload_error')), findsNothing);
    picker.cancel = false;
    picker.failure = PortfolioMediaFailureKind.permissionDenied;
    await _tap(tester, 'media_camera');
    expect(
      find.text(russianMediaStrings['media.permissionDenied']!),
      findsOneWidget,
    );
    await _tap(tester, 'builder_form_apply');
    expect(h.content.profile.avatarPath, path);
  });

  testWidgets('Cancel deletes only a new upload and does not change draft', (
    tester,
  ) async {
    final old = _path('owner', 'b');
    final media = _MediaRepository();
    final initial = PortfolioContent(
      profile: PortfolioProfile(avatarPath: old),
    );
    final h = await _pump(tester, media: media, content: initial);
    await _tap(tester, 'media_gallery');
    await _tap(tester, 'builder_form_cancel');
    expect(h.content, initial);
    expect(media.deleted, [_path('owner', 'a')]);
    expect(media.deleted, isNot(contains(old)));
  });

  testWidgets('Cancel during an upload cleans up its late result', (
    tester,
  ) async {
    final media = _MediaRepository()..pending = Completer<String>();
    final h = await _pump(tester, media: media);
    await _tap(tester, 'media_gallery', settle: false);
    await _tap(tester, 'builder_form_cancel');
    media.pending!.complete(_path('owner', 'a'));
    await tester.pumpAndSettle();
    expect(h.content.profile.avatarPath, isEmpty);
    expect(media.deleted, [_path('owner', 'a')]);
  });

  testWidgets('Removing an existing file only edits the form reference', (
    tester,
  ) async {
    final old = _path('owner', 'b');
    final media = _MediaRepository();
    final h = await _pump(
      tester,
      media: media,
      content: PortfolioContent(profile: PortfolioProfile(avatarPath: old)),
    );
    await _tap(tester, 'media_remove_$old');
    expect(h.content.profile.avatarPath, old);
    await _tap(tester, 'builder_form_apply');
    expect(h.content.profile.avatarPath, isEmpty);
    expect(media.deleted, isEmpty);
  });

  testWidgets(
    'Project Apply preserves existing images and adds selected image',
    (tester) async {
      final old = _path('owner', 'b');
      final h = await _pump(
        tester,
        media: _MediaRepository(),
        editor: const PortfolioProjectEditorScreen(projectId: 'project'),
        content: PortfolioContent(
          projects: [
            PortfolioProject(
              id: 'project',
              title: 'Project',
              description: '',
              technologies: const [],
              imagePaths: [old],
            ),
          ],
        ),
      );
      await _tap(tester, 'media_gallery');
      expect(h.content.projects.single.imagePaths, [old]);
      await _tap(tester, 'builder_form_apply');
      expect(h.content.projects.single.imagePaths, [old, _path('owner', 'a')]);
      expect(h.draft.saves, 0);
    },
  );

  testWidgets('Guest uploads are disabled but manual fields can still apply', (
    tester,
  ) async {
    final h = await _pump(tester);
    expect(find.text(russianMediaStrings['media.guest']!), findsOneWidget);
    expect(_button(tester, 'media_gallery').onPressed, isNull);
    final field = find.byKey(const ValueKey('builder_form_name'));
    await tester.ensureVisible(field);
    await tester.enterText(
      find.descendant(of: field, matching: find.byType(TextFormField)),
      'Guest name',
    );
    await _tap(tester, 'builder_form_apply');
    expect(h.content.profile.name, 'Guest name');
  });

  testWidgets(
    'UID change suppresses stale prepared preview and upload result',
    (tester) async {
      final old = _MediaRepository()..pending = Completer<String>();
      final h = await _pump(tester, media: old);
      await _tap(tester, 'media_gallery', settle: false);
      h.container
          .read(_currentRepositoryProvider.notifier)
          .select(_MediaRepository('other'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('media_prepared_preview')),
        findsNothing,
      );
      old.pending!.complete(_path('owner', 'a'));
      await tester.pumpAndSettle();
      expect(h.content.profile.avatarPath, isEmpty);
      expect(old.deleted, [_path('owner', 'a')]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Private image never reads a foreign UID path; failure has retry',
    (tester) async {
      final media = _MediaRepository()..readFailure = true;
      final h = await _pump(
        tester,
        media: media,
        editor: Scaffold(
          body: Column(
            children: [
              PortfolioMediaImage(path: _path('other', 'b')),
              PortfolioMediaImage(path: _path('owner', 'a')),
            ],
          ),
        ),
      );
      expect(media.reads, [_path('owner', 'a')]);
      media.readFailure = false;
      await tester.tap(find.byType(IconButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(media.reads, [_path('owner', 'a'), _path('owner', 'a')]);
      h.container
          .read(_currentRepositoryProvider.notifier)
          .select(_MediaRepository('other'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey(('owner', _path('owner', 'a')))),
        findsNothing,
      );
    },
  );

  for (final locale in AppStrings.supportedLocales) {
    testWidgets(
      'Media form supports narrow viewport and scale 2 ${locale.languageCode}',
      (tester) async {
        await _pump(
          tester,
          media: _MediaRepository(),
          locale: locale,
          size: const Size(320, 568),
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, 'media_gallery');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'builder_form_cancel');
        expect(tester.takeException(), isNull);
      },
    );
  }
}

String _path(String owner, String hex) =>
    'accounts/$owner/media/${List.filled(32, hex).join()}.jpg';
final _imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);

StackCardButton _button(WidgetTester tester, String key) =>
    tester.widget<StackCardButton>(find.byKey(ValueKey(key)));

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<_Harness> _pump(
  WidgetTester tester, {
  _MediaRepository? media,
  _Picker? picker,
  PortfolioContent? content,
  Widget editor = const PortfolioProfileEditorScreen(),
  Locale locale = const Locale('ru'),
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final draft = _DraftRepository(content ?? PortfolioContent());
  final container = ProviderContainer(
    overrides: [
      portfolioDraftRepositoryProvider.overrideWithValue(draft),
      portfolioImagePickerProvider.overrideWithValue(picker ?? _Picker()),
      portfolioMediaRepositoryProvider.overrideWith(
        (ref) => ref.watch(_currentRepositoryProvider),
      ),
      accountSessionProvider.overrideWith(
        (ref) =>
            Stream.value(media == null ? null : const AuthUser(uid: 'owner')),
      ),
    ],
  );
  container.read(_currentRepositoryProvider.notifier).select(media);
  final router = GoRouter(
    initialLocation: '/return',
    routes: [
      GoRoute(
        path: '/return',
        builder: (_, _) => const Scaffold(body: Text('Back')),
      ),
      GoRoute(path: '/editor', builder: (_, _) => editor),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: StackCardTheme.light,
        darkTheme: StackCardTheme.dark,
        themeMode: ThemeMode.dark,
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
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    ),
  );
  router.push('/editor');
  await tester.pumpAndSettle();
  return _Harness(container, draft);
}

class _Harness {
  const _Harness(this.container, this.draft);
  final ProviderContainer container;
  final _DraftRepository draft;
  PortfolioContent get content =>
      container.read(portfolioDraftControllerProvider).content!;
}

class _Picker implements PortfolioImagePicker {
  int calls = 0;
  bool cancel = false;
  PortfolioMediaFailureKind? failure;
  @override
  Future<PreparedPortfolioImage?> pick(PortfolioImageSource source) async {
    calls++;
    if (failure != null) throw PortfolioMediaFailure(failure!);
    return cancel ? null : PreparedPortfolioImage(_imageBytes);
  }
}

class _MediaRepository implements PortfolioMediaRepository {
  _MediaRepository([this.ownerUid = 'owner']);
  @override
  final String ownerUid;
  Completer<String>? pending;
  void Function(double)? progress;
  bool failNext = false;
  bool readFailure = false;
  int uploads = 0;
  final deleted = <String>[];
  final reads = <String>[];
  @override
  Future<String> upload(
    PreparedPortfolioImage image, {
    required void Function(double) onProgress,
  }) async {
    uploads++;
    progress = onProgress;
    onProgress(.2);
    if (failNext) {
      failNext = false;
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);
    }
    return pending == null ? _path(ownerUid, 'a') : await pending!.future;
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);
  @override
  Future<Uint8List> read(String path) async {
    reads.add(path);
    if (readFailure) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);
    }
    return _imageBytes;
  }
}

class _DraftRepository implements PortfolioDraftRepository {
  _DraftRepository(this.content);
  final PortfolioContent content;
  int saves = 0;
  @override
  Future<PortfolioDraft?> read() async => PortfolioDraft(
    notes: '',
    revision: 1,
    updatedAt: DateTime.utc(2026, 10, 7),
    pendingSync: false,
    content: content,
  );
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    saves++;
    return PortfolioDraft(
      notes: notes,
      revision: expectedRevision + 1,
      updatedAt: DateTime.utc(2026, 10, 7),
      pendingSync: false,
      content: content,
    );
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) async => (await read())!;
}
