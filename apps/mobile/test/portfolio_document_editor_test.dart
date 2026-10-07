import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/media/media.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
    'wizard preserves input across steps and saves an independent document with library relations',
    (tester) async {
      final repository = await _repository();
      await _open(tester, repository);
      await _enter(tester, 'title', 'Frontend CV');
      await _enter(tester, 'headline', 'Frontend Developer');
      await _tap(tester, 'document.next');
      expect(find.textContaining('Шаг 2 из 5'), findsOneWidget);
      await _tap(tester, 'document.previous');
      expect(_value(tester, 'headline'), 'Frontend Developer');
      await _tap(tester, 'document.next');
      await _tap(tester, 'document.next');
      await _tap(tester, 'document.next');
      await _tap(tester, 'document.select.project.library-project');
      await _tap(tester, 'document.next');
      expect(find.textContaining('Шаг 5 из 5'), findsOneWidget);
      expect(find.text('Frontend Developer'), findsOneWidget);
      await _tap(tester, 'document.save');
      expect(find.text('Library'), findsOneWidget);
      final workspace = (await repository.read())!.content!;
      final document = workspace.documents.single;
      expect(document.title, 'Frontend CV');
      expect(document.content.profile.headline, 'Frontend Developer');
      expect(workspace.profile.headline, 'Fullstack Developer');
      expect(document.projects.single.projectId, 'library-project');
      expect(document.content.projects, isEmpty);
      expect(document.baseSnapshot, developerProfileData(workspace));
      expect(workspace.projects.single.id, 'library-project');
      expect((await repository.read())!.notes, 'private note');
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, repository, documentId: document.id);
      expect(
        find.byKey(const ValueKey('document.section.profile')),
        findsOneWidget,
      );
      await _tap(tester, 'document.section.profile');
      expect(_value(tester, 'headline'), 'Frontend Developer');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'required first step cannot be skipped or advanced without document title',
    (tester) async {
      final repository = await _repository();
      await _open(tester, repository);
      final skip = tester.widget<StackCardButton>(
        find.byKey(const Key('document.skip')),
      );
      expect(skip.onPressed, isNull);
      await _tap(tester, 'document.next');
      expect(find.textContaining('Шаг 1 из 5'), findsOneWidget);
      expect((await repository.read())!.content!.documents, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'existing document opens focused editor and a failed Save retains its local input',
    (tester) async {
      final memory = await _repository(existing: true);
      final repository = _FailsOnce(memory);
      await _open(tester, repository, documentId: 'existing');
      expect(find.textContaining('Шаг 1 из 5'), findsNothing);
      await _tap(tester, 'document.section.profile');
      await _enter(tester, 'headline', 'Role retained after failure');
      await _tap(tester, 'document.save');
      expect(find.textContaining('Не удалось сохранить.'), findsOneWidget);
      expect(_value(tester, 'headline'), 'Role retained after failure');
      expect(
        (await memory.read())!
            .content!
            .documents
            .single
            .content
            .profile
            .headline,
        'Original role',
      );
      await _tap(tester, 'document.save');
      expect(find.text('Library'), findsOneWidget);
      expect(
        (await memory.read())!
            .content!
            .documents
            .single
            .content
            .profile
            .headline,
        'Role retained after failure',
      );
      expect(
        (await memory.read())!.content!.profile.headline,
        'Fullstack Developer',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dirty navigation offers Stay and Discard without persisting', (
    tester,
  ) async {
    final repository = await _repository();
    await _open(tester, repository);
    await _enter(tester, 'title', 'Unsaved CV');
    await _tap(tester, 'document.back');
    expect(find.text('Сохранить изменения?'), findsOneWidget);
    await _tap(tester, 'document.leave.stay');
    expect(_value(tester, 'title'), 'Unsaved CV');
    await _tap(tester, 'document.back');
    await _tap(tester, 'document.leave.discard');
    expect(find.text('Library'), findsOneWidget);
    expect((await repository.read())!.content!.documents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'repository transition hides the previous owner buffer and blocks Save',
    (tester) async {
      final first = await _repository();
      final container = await _open(tester, first);
      await _enter(tester, 'title', 'Private owner title');
      final second = await _repository();
      container.updateOverrides([
        portfolioDraftRepositoryProvider.overrideWithValue(second),
      ]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Аккаунт изменился'), findsOneWidget);
      expect(find.text('Private owner title'), findsNothing);
      expect(find.byKey(const Key('document.save')), findsNothing);
      expect(find.byKey(const ValueKey('builder_form_title')), findsNothing);
      expect((await first.read())!.content!.documents, isEmpty);
      expect((await second.read())!.content!.documents, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final modal in ['project', 'contact']) {
    testWidgets(
      '$modal dialog scrubs and closes after repository owner transition',
      (tester) async {
        final first = await _repository(existing: true);
        final container = await _open(tester, first, documentId: 'existing');
        if (modal == 'project') {
          await _tap(tester, 'document.section.projects');
          await _tap(tester, 'document.addProject');
          await _enter(tester, 'title', 'Private project modal input');
        } else {
          await _tap(tester, 'document.section.contacts');
          await _tapFinder(tester, find.text('Добавить свою ссылку'));
          await _enter(tester, 'label', 'Private contact modal input');
        }
        final second = await _repository();
        container.updateOverrides([
          portfolioDraftRepositoryProvider.overrideWithValue(second),
        ]);
        await tester.pumpAndSettle();
        expect(find.textContaining('Private'), findsNothing);
        expect(
          find.byKey(const ValueKey('builder_record_apply')),
          findsNothing,
        );
        expect(find.textContaining('Аккаунт изменился'), findsOneWidget);
        expect((await first.read())!.content!.projects.length, 1);
        expect((await second.read())!.content!.projects.length, 1);
        expect(
          (await first.read())!.content!.documents.single.content.links.length,
          1,
        );
        expect((await second.read())!.content!.documents, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('320px and text scale two keeps the wizard and footer usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    final repository = await _repository();
    await _open(tester, repository, textScale: 2, locale: const Locale('en'));
    await _enter(tester, 'title', 'Accessible resume');
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(
      tester.getBottomRight(find.byKey(const Key('document.next'))).dy,
      lessThanOrEqualTo(644),
    );
    await _tap(tester, 'document.next');
    expect(find.textContaining('Step 2 of 5'), findsOneWidget);
    await _tap(tester, 'document.previous');
    expect(_value(tester, 'title'), 'Accessible resume');
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner read gate scrolls in narrow landscape at text scale two', (
    tester,
  ) async {
    final repository = await _repository();
    final container = await _open(tester, repository, textScale: 2);
    tester.view.physicalSize = const Size(320, 240);
    container.updateOverrides([
      portfolioDraftRepositoryProvider.overrideWithValue(await _repository()),
    ]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Аккаунт изменился'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'conflict requires a scoped reload and preserves unsaved base and notes',
    (tester) async {
      final repository = await _repository(existing: true);
      final container = await _open(tester, repository, documentId: 'existing');
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      controller.updateNotes('unsaved private notes');
      controller.updateContent(
        controller.workingContent!.copyWith(
          profile: controller.workingContent!.profile.copyWith(
            bio: 'unsaved base biography',
          ),
        ),
      );
      await _tap(tester, 'document.section.profile');
      await _enter(tester, 'headline', 'Local document input');
      final saved = (await repository.read())!;
      final remote = saved.content!.documents.single;
      await repository.save(
        saved.content!.copyWith(
          documents: [
            remote.copyWith(
              content: remote.content.copyWith(
                profile: remote.content.profile.copyWith(
                  headline: 'Remote document role',
                ),
              ),
              updatedAt: remote.updatedAt.add(const Duration(seconds: 1)),
            ),
          ],
        ),
        expectedRevision: saved.revision,
        notes: saved.notes,
      );
      await _tap(tester, 'document.save');
      expect(find.textContaining('Этот документ изменился'), findsOneWidget);
      expect(_value(tester, 'headline'), 'Local document input');
      await _tap(tester, 'document.reload');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Загрузить новую версию'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_value(tester, 'headline'), 'Remote document role');
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'unsaved private notes',
      );
      expect(controller.workingContent!.profile.bio, 'unsaved base biography');
      await _enter(tester, 'headline', 'Reviewed role');
      await _tap(tester, 'document.save');
      expect(find.text('Library'), findsOneWidget);
      expect(
        (await repository.read())!
            .content!
            .documents
            .single
            .content
            .profile
            .headline,
        'Reviewed role',
      );
      expect((await repository.read())!.content!.profile.bio, isEmpty);
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'unsaved private notes',
      );
      expect(controller.workingContent!.profile.bio, 'unsaved base biography');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'input entered while Save is pending survives completion and is saved by a second action',
    (tester) async {
      final memory = await _repository(existing: true);
      final repository = _PendingOnce(memory);
      await _open(tester, repository, documentId: 'existing');
      await _tap(tester, 'document.section.profile');
      await _enter(tester, 'headline', 'Captured document role');
      await tester.tap(find.byKey(const Key('document.save')));
      await tester.pump();
      await _enter(tester, 'headline', 'New input during Save');
      repository.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsNothing);
      expect(_value(tester, 'headline'), 'New input during Save');
      expect(
        (await memory.read())!
            .content!
            .documents
            .single
            .content
            .profile
            .headline,
        'Captured document role',
      );
      await _tap(tester, 'document.save');
      expect(find.text('Library'), findsOneWidget);
      expect(
        (await memory.read())!
            .content!
            .documents
            .single
            .content
            .profile
            .headline,
        'New input during Save',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'photo selection stays mounted across wizard steps and is retained only after Save',
    (tester) async {
      final repository = await _repository();
      final media = _Media();
      await _open(tester, repository, media: media, picker: _Picker());
      await _enter(tester, 'title', 'Resume with a photo');
      await _tap(tester, 'media_gallery');
      final mediaState = tester.state(find.byType(PortfolioMediaEditor));
      final path = media.uploaded.single;
      await _tap(tester, 'document.next');
      expect(
        tester.state(find.byType(PortfolioMediaEditor, skipOffstage: false)),
        same(mediaState),
      );
      expect(media.deleted, isEmpty);
      await _tap(tester, 'document.previous');
      expect(find.byKey(ValueKey('media_remove_$path')), findsOneWidget);
      for (var step = 0; step < 4; step++) {
        await _tap(tester, 'document.next');
      }
      await _tap(tester, 'document.save');
      expect(
        (await repository.read())!
            .content!
            .documents
            .single
            .content
            .profile
            .avatarPath,
        path,
      );
      expect((await repository.read())!.content!.profile.avatarPath, isEmpty);
      expect(media.deleted, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discard cleans the new document photo without persisting a reference',
    (tester) async {
      final repository = await _repository();
      final media = _Media();
      await _open(tester, repository, media: media, picker: _Picker());
      await _enter(tester, 'title', 'Unsaved photo');
      await _tap(tester, 'media_camera');
      await _tap(tester, 'document.back');
      await _tap(tester, 'document.leave.discard');
      expect(media.deleted, media.uploaded);
      expect((await repository.read())!.content!.documents, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a saved photo survives a later replacement that is discarded', (
    tester,
  ) async {
    final memory = await _repository(existing: true);
    final repository = _PendingOnce(memory);
    final media = _Media();
    await _open(
      tester,
      repository,
      documentId: 'existing',
      media: media,
      picker: _Picker(),
    );
    await _tap(tester, 'document.section.profile');
    await _tap(tester, 'media_gallery');
    final savedPath = media.uploaded.single;
    await _enter(tester, 'headline', 'Captured photo version');
    await tester.tap(find.byKey(const Key('document.save')));
    await tester.pump();
    expect(
      tester
          .widget<StackCardButton>(find.byKey(const Key('media_gallery')))
          .onPressed,
      isNull,
    );
    await _enter(tester, 'headline', 'Working newer version');
    repository.pending.complete();
    await tester.pumpAndSettle();
    await _tap(tester, 'media_gallery');
    final unsavedPath = media.uploaded.last;
    expect(unsavedPath, isNot(savedPath));
    expect(media.deleted, isEmpty);
    await _tap(tester, 'document.back');
    await _tap(tester, 'document.back');
    await _tap(tester, 'document.leave.discard');
    expect(media.deleted, [unsavedPath]);
    expect(
      (await memory.read())!
          .content!
          .documents
          .single
          .content
          .profile
          .avatarPath,
      savedPath,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'portfolio project order and visibility belong to document relations and detach keeps the library',
    (tester) async {
      final repository = await _repository(
        existing: true,
        kind: PortfolioDocumentKind.portfolio,
        secondProject: true,
      );
      await _open(
        tester,
        repository,
        documentId: 'existing',
        kind: PortfolioDocumentKind.portfolio,
      );
      await _tap(tester, 'document.section.projects');
      await _tap(tester, 'document.select.project.library-project');
      await _tap(tester, 'document.select.project.second-project');
      Finder attachment(String id) =>
          find.byKey(ValueKey('document.attachment.$id'));
      await _tapFinder(
        tester,
        find.descendant(
          of: attachment('library-project'),
          matching: find.widgetWithText(CheckboxListTile, 'Показывать'),
        ),
      );
      await _tapFinder(
        tester,
        find.descendant(
          of: attachment('second-project'),
          matching: find.widgetWithText(CheckboxListTile, 'Основной проект'),
        ),
      );
      await _tapFinder(
        tester,
        find.descendant(
          of: attachment('second-project'),
          matching: find.byTooltip('Выше'),
        ),
      );
      await _tap(tester, 'document.save');
      final saved = (await repository.read())!.content!;
      expect(saved.documents.single.projects.map((item) => item.projectId), [
        'second-project',
        'library-project',
      ]);
      expect(saved.documents.single.projects.first.featured, isTrue);
      expect(saved.documents.single.projects.last.visible, isFalse);
      expect(saved.projects.every((item) => item.visible), isTrue);
      expect(saved.projects.any((item) => item.featured), isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await _open(
        tester,
        repository,
        documentId: 'existing',
        kind: PortfolioDocumentKind.portfolio,
      );
      await _tap(tester, 'document.section.projects');
      await _tapFinder(
        tester,
        find.descendant(
          of: attachment('second-project'),
          matching: find.text('Убрать из документа'),
        ),
      );
      await _tap(tester, 'document.save');
      final detached = (await repository.read())!.content!;
      expect(
        detached.documents.single.projects.single.projectId,
        'library-project',
      );
      expect(detached.projects.map((item) => item.id), [
        'library-project',
        'second-project',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'create project in a document attaches it locally and saves both atomically for reopen',
    (tester) async {
      final repository = await _repository();
      final before = (await repository.read())!;
      final container = await _open(tester, repository);
      await _enter(tester, 'title', 'Resume with a new project');
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      controller.updateContent(
        controller.workingContent!.copyWith(
          projects: [
            ...controller.workingContent!.projects,
            PortfolioProject(
              id: 'unsaved-working-project',
              title: 'Unrelated unsaved project',
              description: '',
              technologies: const [],
            ),
          ],
        ),
      );
      for (var step = 0; step < 3; step++) {
        await _tap(tester, 'document.next');
      }
      expect(
        find.byKey(
          const ValueKey('document.select.project.unsaved-working-project'),
        ),
        findsNothing,
      );
      await _createProject(tester, 'Created in resume');
      expect((await repository.read())!.revision, before.revision);
      expect(
        (await repository.read())!.content!.projects,
        before.content!.projects,
      );
      await _tap(tester, 'document.next');
      expect(find.text('Created in resume'), findsOneWidget);
      await _tap(tester, 'document.save');
      final saved = (await repository.read())!;
      final created = saved.content!.projects.last;
      expect(saved.revision, before.revision + 1);
      expect(created.title, 'Created in resume');
      expect(created.technologies, ['Dart', 'Flutter']);
      expect(created.repositoryUrl, 'https://github.com/example/project');
      expect(created.liveUrl, 'https://example.com/project');
      expect(
        saved.content!.documents.single.projects.single.projectId,
        created.id,
      );
      expect(saved.content!.documents.single.content.projects, isEmpty);
      expect(
        controller.workingContent!.projects.any(
          (item) => item.id == 'unsaved-working-project',
        ),
        isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _open(
        tester,
        repository,
        documentId: saved.content!.documents.single.id,
      );
      await _tap(tester, 'document.section.projects');
      final selected = tester.widget<CheckboxListTile>(
        find.byKey(ValueKey('document.select.project.${created.id}')),
      );
      expect(selected.value, isTrue);
      expect(
        find.byKey(ValueKey('document.attachment.${created.id}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discard document does not create its locally added project in the library',
    (tester) async {
      final repository = await _repository(existing: true);
      final before = (await repository.read())!;
      await _open(tester, repository, documentId: 'existing');
      await _tap(tester, 'document.section.projects');
      await _createProject(tester, 'Discarded project');
      await _tap(tester, 'document.back');
      await _tap(tester, 'document.back');
      await _tap(tester, 'document.leave.discard');
      expect(find.text('Library'), findsOneWidget);
      final after = (await repository.read())!;
      expect(after.revision, before.revision);
      expect(after.content!.projects, before.content!.projects);
      expect(after.content!.documents, before.content!.documents);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'base review Apply changes only the buffer; Save and reopen retain local role',
    (tester) async {
      final repository = await _reviewRepository();
      final before = (await repository.read())!;
      final container = await _open(tester, repository, documentId: 'reviewed');
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      controller.updateNotes('unsaved neighbouring notes');
      controller.updateContent(
        controller.workingContent!.copyWith(
          profile: before.content!.profile.copyWith(bio: 'unsaved base input'),
        ),
      );
      await _tap(tester, 'document.section.profile');
      await _enter(tester, 'headline', 'Unsaved local role');
      await _tap(tester, 'document.back');
      await _tap(tester, 'document.baseReview');
      expect(find.text('Saved new bio'), findsOneWidget);
      expect(find.text('unsaved base input'), findsNothing);
      expect(find.text('Unsaved local role'), findsOneWidget);
      await _tap(tester, 'base-review-apply');
      expect((await repository.read())!, before);
      await _tap(tester, 'document.section.profile');
      expect(_value(tester, 'headline'), 'Unsaved local role');
      expect(_value(tester, 'bio'), 'Saved new bio');
      await _tap(tester, 'document.save');
      final after = (await repository.read())!;
      final reviewed = after.content!.documents.singleWhere(
        (item) => item.id == 'reviewed',
      );
      expect(reviewed.content.profile.headline, 'Unsaved local role');
      expect(reviewed.baseSnapshot, developerProfileData(before.content!));
      expect(after.content!.documents.last, before.content!.documents.last);
      expect(after.content!.profile, before.content!.profile);
      expect(after.notes, before.notes);
      expect(controller.workingContent!.profile.bio, 'unsaved base input');
      expect(
        container.read(portfolioDraftControllerProvider).notes,
        'unsaved neighbouring notes',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, repository, documentId: 'reviewed');
      await _tap(tester, 'document.baseReview');
      expect(find.byKey(const ValueKey('base-review-bio:')), findsNothing);
      await _tap(tester, 'base-review-cancel');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'base review Cancel discards choices and leaves durable revision unchanged',
    (tester) async {
      final repository = await _reviewRepository();
      final before = (await repository.read())!;
      await _open(tester, repository, documentId: 'reviewed');
      await _tap(tester, 'document.baseReview');
      await _tap(tester, 'base-review-cancel');
      await _tap(tester, 'document.section.profile');
      expect(_value(tester, 'bio'), 'Old bio');
      expect(_value(tester, 'headline'), 'Frontend role');
      await _tap(tester, 'document.back');
      await _tap(tester, 'document.back');
      expect(find.text('Library'), findsOneWidget);
      expect((await repository.read())!, before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a changed saved base rejects the captured review and preserves document input',
    (tester) async {
      final repository = await _reviewRepository();
      final container = await _open(tester, repository, documentId: 'reviewed');
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      await _tap(tester, 'document.baseReview');
      controller.updateContent(
        controller.workingContent!.copyWith(
          profile: controller.workingContent!.profile.copyWith(
            bio: 'Newest base',
          ),
        ),
      );
      expect(
        await controller.saveDeveloperProfile(expectedRepository: repository),
        isTrue,
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'base-review-apply');
      expect(
        find.textContaining('База или документ изменились'),
        findsOneWidget,
      );
      await _tap(tester, 'document.section.profile');
      expect(_value(tester, 'bio'), 'Old bio');
      expect(_value(tester, 'headline'), 'Frontend role');
      expect(
        (await repository.read())!.content!.documents.first.content.profile.bio,
        'Old bio',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'owner transition hides base review without writing either owner',
    (tester) async {
      final first = await _reviewRepository();
      final second = await _repository();
      final firstBefore = (await first.read())!;
      final secondBefore = (await second.read())!;
      final container = await _open(tester, first, documentId: 'reviewed');
      await _tap(tester, 'document.baseReview');
      container.updateOverrides([
        portfolioDraftRepositoryProvider.overrideWithValue(second),
      ]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('base-review-apply')), findsNothing);
      expect(find.text('Saved new bio'), findsNothing);
      expect((await first.read())!, firstBefore);
      expect((await second.read())!, secondBefore);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<MemoryPortfolioDraftRepository> _reviewRepository() async {
  final repository = MemoryPortfolioDraftRepository();
  final old = PortfolioContent(
    profile: const PortfolioProfile(
      name: 'Alex',
      headline: 'Fullstack role',
      bio: 'Old bio',
    ),
  );
  final date = DateTime.utc(2026, 10, 7);
  final document = PortfolioDocument(
    id: 'reviewed',
    title: 'Resume',
    kind: PortfolioDocumentKind.resume,
    createdAt: date,
    updatedAt: date,
    content: seedDocumentContent(old)
        .copyWith(profile: old.profile.copyWith(headline: 'Frontend role')),
    baseSnapshot: developerProfileData(old),
  );
  await repository.save(
    old.copyWith(
      profile: old.profile.copyWith(
        headline: 'New base role',
        bio: 'Saved new bio',
      ),
      documents: [
        document,
        document.copyWith(id: 'neighbour', title: 'Other resume'),
      ],
    ),
    expectedRevision: 0,
    notes: 'private notes',
  );
  return repository;
}

Future<MemoryPortfolioDraftRepository> _repository({
  bool existing = false,
  PortfolioDocumentKind kind = PortfolioDocumentKind.resume,
  bool secondProject = false,
}) async {
  final repository = MemoryPortfolioDraftRepository();
  final base = PortfolioContent(
    profile: const PortfolioProfile(
      name: 'Alex Morgan',
      headline: 'Fullstack Developer',
    ),
    projects: [
      PortfolioProject(
        id: 'library-project',
        title: 'Shared project',
        description: 'From the library',
        technologies: const ['Flutter'],
      ),
      if (secondProject)
        PortfolioProject(
          id: 'second-project',
          title: 'Second shared project',
          description: 'Also kept in the library',
          technologies: const ['Dart'],
        ),
    ],
    skills: const [Skill(id: 'flutter', name: 'Flutter')],
    links: const [
      SocialLink(id: 'site', label: 'Site', url: 'https://example.com'),
    ],
  );
  final time = DateTime.utc(2026, 10, 7);
  final content = base.copyWith(
    documents: [
      if (existing)
        PortfolioDocument(
          id: 'existing',
          title: 'Existing CV',
          kind: kind,
          createdAt: time,
          updatedAt: time,
          content: seedDocumentContent(
            base,
          ).copyWith(profile: base.profile.copyWith(headline: 'Original role')),
        ),
    ],
  );
  await repository.save(content, expectedRevision: 0, notes: 'private note');
  return repository;
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  PortfolioDraftRepository repository, {
  String? documentId,
  PortfolioDocumentKind kind = PortfolioDocumentKind.resume,
  double textScale = 1,
  Locale locale = const Locale('ru'),
  PortfolioMediaRepository? media,
  PortfolioImagePicker? picker,
}) async {
  final container = ProviderContainer(
    overrides: [
      portfolioDraftRepositoryProvider.overrideWithValue(repository),
      if (media != null)
        portfolioMediaRepositoryProvider.overrideWithValue(media),
      if (picker != null)
        portfolioImagePickerProvider.overrideWithValue(picker),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(portfolioDraftControllerProvider.notifier)
      .ensureLoaded();
  final router = GoRouter(
    initialLocation: '/editor',
    routes: [
      GoRoute(
        path: '/editor',
        builder: (_, _) =>
            PortfolioDocumentEditorScreen(documentId: documentId, kind: kind),
      ),
      GoRoute(
        path: '/resumes',
        builder: (_, _) => const Scaffold(body: Text('Library')),
      ),
      GoRoute(
        path: '/portfolio',
        builder: (_, _) => const Scaffold(body: Text('Library')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: StackCardTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _field(String name) => find.descendant(
  of: find.byKey(ValueKey('builder_form_$name')),
  matching: find.byType(TextFormField),
);
String _value(WidgetTester tester, String name) =>
    tester.widget<TextFormField>(_field(name)).controller!.text;
Future<void> _enter(WidgetTester tester, String name, String value) async {
  await tester.ensureVisible(_field(name));
  await tester.enterText(_field(name), value);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await _tapFinder(tester, find.byKey(ValueKey(key)));
}

Future<void> _tapFinder(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _createProject(WidgetTester tester, String title) async {
  await _tap(tester, 'document.addProject');
  await _enter(tester, 'title', title);
  await _enter(tester, 'description', 'Project created inside a document');
  await _enter(tester, 'technologies', 'Dart, Flutter');
  await _enter(tester, 'repositoryUrl', 'https://github.com/example/project');
  await _enter(tester, 'liveUrl', 'https://example.com/project');
  await _tap(tester, 'builder_record_apply');
}

class _FailsOnce implements PortfolioDraftRepository {
  _FailsOnce(this.delegate);
  final PortfolioDraftRepository delegate;
  var _failed = false;
  @override
  Future<PortfolioDraft?> read() => delegate.read();
  @override
  Future<PortfolioDraft> saveNotes(String notes) => delegate.saveNotes(notes);
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) {
    if (!_failed) {
      _failed = true;
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.unavailable);
    }
    return delegate.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }
}

class _PendingOnce implements PortfolioDraftRepository {
  _PendingOnce(this.delegate);
  final PortfolioDraftRepository delegate;
  final pending = Completer<void>();
  var _waited = false;
  @override
  Future<PortfolioDraft?> read() => delegate.read();
  @override
  Future<PortfolioDraft> saveNotes(String notes) => delegate.saveNotes(notes);
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    if (!_waited) {
      _waited = true;
      await pending.future;
    }
    return delegate.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }
}

final _imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);

class _Picker implements PortfolioImagePicker {
  @override
  Future<PreparedPortfolioImage?> pick(PortfolioImageSource source) async =>
      PreparedPortfolioImage(_imageBytes);
}

class _Media implements PortfolioMediaRepository {
  @override
  String get ownerUid => 'owner';
  final uploaded = <String>[];
  final deleted = <String>[];
  @override
  Future<String> upload(
    PreparedPortfolioImage image, {
    required void Function(double) onProgress,
  }) async {
    final hex = (uploaded.length + 1).toRadixString(16).padLeft(32, '0');
    final path = 'accounts/owner/media/$hex.jpg';
    uploaded.add(path);
    onProgress(1);
    return path;
  }

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
  }

  @override
  Future<Uint8List> read(String path) async => _imageBytes;
}
