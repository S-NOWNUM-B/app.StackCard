import 'dart:async';

import 'package:app_stackcard/app/app_shell.dart';
import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      font.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
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
    view.resetViewInsets();
  });

  testWidgets('empty main portfolio saves without required personal fields', (
    tester,
  ) async {
    final repository = await _repository();
    await _open(tester, repository);
    await _tap(tester, 'main.editor.save');
    final workspace = (await repository.read())!.content!;
    expect(mainPortfolioDocument(workspace)!.content.profile.name, isEmpty);
    expect(mainPortfolioDocument(workspace)!.content.profile.headline, isEmpty);
    expect(workspace.documents.length, 1);
    expect(find.text('Изменения сохранены'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'skill tags validate, cancel and remove locally before explicit Save at 320px text2',
    (tester) async {
      tester.view.physicalSize = const Size(320, 680);
      final repository = await _repository(
        skills: const [
          Skill(id: 'dart', name: 'Dart'),
          Skill(id: 'raw', name: 'Team, tools'),
        ],
      );
      final before = (await repository.read())!;
      await _open(tester, repository, textScale: 2);
      final headings = [
        'Контакты и ссылки',
        'Навыки',
        'Реализованные проекты',
        'Опыт работы',
        'Образование',
      ];
      for (var index = 1; index < headings.length; index++) {
        expect(
          tester.getTopLeft(find.text(headings[index])).dy,
          greaterThan(tester.getTopLeft(find.text(headings[index - 1])).dy),
        );
      }
      await _tap(tester, 'main.editor.addSkill');
      for (final invalid in ['', ' dart ', 'x' * 61]) {
        await _enterKey(tester, 'main.editor.skill.name', invalid);
        await _tap(tester, 'main.editor.skill.confirm');
        expect(find.byKey(const Key('main.editor.skill.name')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await _enterKey(tester, 'main.editor.skill.name', ' React ');
      await _tap(tester, 'main.editor.skill.confirm');
      await _tap(tester, 'main.editor.addSkill');
      await _enterKey(tester, 'main.editor.skill.name', 'Cancelled');
      await _tap(tester, 'main.editor.skill.cancel');
      expect(find.text('Cancelled'), findsNothing);
      await _tap(tester, 'main.editor.skill.remove.0');
      expect((await repository.read())!.revision, before.revision);
      expect(
        mainPortfolioDocument((await repository.read())!.content!)!
            .content
            .skills,
        const [
          Skill(id: 'dart', name: 'Dart'),
          Skill(id: 'raw', name: 'Team, tools'),
        ],
      );
      if (const bool.fromEnvironment('UPDATE_SINGLE_PORTFOLIO_PREVIEWS')) {
        await tester.ensureVisible(find.byKey(const Key('main.editor.skills')));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('/private/tmp/stackcard-main-skill-tags.png'),
        );
      }
      await _tap(tester, 'main.editor.save');
      final saved = (await repository.read())!.content!;
      final skills = mainPortfolioDocument(saved)!.content.skills;
      expect(skills.map((skill) => skill.name), ['Team, tools', 'React']);
      expect(skills.first.id, 'raw');
      expect(skills.map((skill) => skill.id).toSet(), hasLength(2));
      expect(saved.skills, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owner transition clears and closes the pending skill dialog', (
    tester,
  ) async {
    final first = await _repository(name: 'Первый');
    final second = await _repository(name: 'Второй');
    final container = await _open(tester, first);
    await _tap(tester, 'main.editor.addSkill');
    await _enterKey(tester, 'main.editor.skill.name', 'Private skill');
    container.updateOverrides([
      portfolioDraftRepositoryProvider.overrideWithValue(second),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Private skill'), findsNothing);
    expect(find.byKey(const Key('main.editor.skill.confirm')), findsNothing);
    expect(_value(tester, 'main.editor.name'), 'Второй');
    expect(
      mainPortfolioDocument((await second.read())!.content!)!.content.skills,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed save retains input and saved read content remains unchanged',
    (tester) async {
      final memory = await _repository(name: 'Сохранённое имя');
      final repository = _FailsOnce(memory);
      final container = await _open(tester, repository);
      await _enter(tester, 'name', 'Несохранённое имя');
      final state = container.read(portfolioDraftControllerProvider);
      expect(
        mainPortfolioDocument(state.content!)!.content.profile.name,
        'Несохранённое имя',
      );
      expect(
        mainPortfolioDocument(state.draft!.content!)!.content.profile.name,
        'Сохранённое имя',
      );
      await _tap(tester, 'main.editor.save');
      expect(find.byKey(const Key('main.editor.error')), findsOneWidget);
      expect(_value(tester, 'main.editor.name'), 'Несохранённое имя');
      expect(
        mainPortfolioDocument((await memory.read())!.content!)!
            .content
            .profile
            .name,
        'Сохранённое имя',
      );
      await _tap(tester, 'main.editor.save');
      expect(
        mainPortfolioDocument((await memory.read())!.content!)!
            .content
            .profile
            .name,
        'Несохранённое имя',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'project selector is library only and removing attachment preserves project',
    (tester) async {
      final repository = await _repository(
        projects: [
          PortfolioProject(
            id: 'one',
            title: 'Первый проект',
            description: '',
            technologies: const [],
          ),
          PortfolioProject(
            id: 'two',
            title: 'Второй проект',
            description: '',
            technologies: const [],
          ),
        ],
      );
      await _open(tester, repository);
      await _tap(tester, 'main.editor.addProject');
      expect(find.text('Создать проект'), findsNothing);
      await _tap(tester, 'main.projectSelection.one');
      await _tap(tester, 'main.projectSelection.two');
      await _tap(tester, 'main.projectSelection.apply');
      await _tap(tester, 'main.editor.up.two');
      await _tap(tester, 'main.editor.save');
      var workspace = (await repository.read())!.content!;
      expect(
        mainPortfolioDocument(workspace)!.projects
            .map((item) => item.projectId),
        ['two', 'one'],
      );
      await _tap(tester, 'main.editor.removeProject.one');
      await _tap(tester, 'main.editor.save');
      workspace = (await repository.read())!.content!;
      expect(workspace.projects.map((item) => item.id), ['one', 'two']);
      expect(
        mainPortfolioDocument(workspace)!.projects.single.projectId,
        'two',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late Save acknowledgement preserves newer text in the working buffer',
    (tester) async {
      final memory = await _repository(name: 'Сохранённое имя');
      final repository = _BlockingSave(memory);
      final container = await _open(tester, repository);
      await _enter(tester, 'name', 'Первый ввод');
      await tester.tap(find.byKey(const Key('main.editor.save')));
      await tester.pump();
      expect(repository.started.isCompleted, isTrue);
      final input = tester.widget<TextFormField>(
        find.descendant(
          of: find.byKey(const Key('main.editor.name')),
          matching: find.byType(TextFormField),
        ),
      );
      input.controller!.text = 'Более поздний ввод';
      repository.release.complete();
      await tester.pumpAndSettle();
      expect(
        mainPortfolioDocument((await memory.read())!.content!)!
            .content
            .profile
            .name,
        'Первый ввод',
      );
      expect(_value(tester, 'main.editor.name'), 'Более поздний ввод');
      expect(
        mainPortfolioDocument(
          container.read(portfolioDraftControllerProvider).content!,
        )!.content.profile.name,
        'Более поздний ввод',
      );
      expect(find.text('Есть несохранённые изменения'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved GitHub changes refresh an unedited field without losing dirty profile input',
    (tester) async {
      final repository = await _repository(
        name: 'Сохранённое имя',
        githubUsername: 'old-owner',
      );
      final container = await _open(tester, repository);
      await _enter(tester, 'name', 'Новое имя');
      expect(
        await container
            .read(portfolioDraftControllerProvider.notifier)
            .saveGitHubIdentity('new-owner', expectedRepository: repository),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(_value(tester, 'main.editor.github'), 'new-owner');
      expect(_value(tester, 'main.editor.name'), 'Новое имя');
      expect(find.text('Есть несохранённые изменения'), findsOneWidget);
      final before = (await repository.read())!;
      expect(
        mainPortfolioDocument(before.content!)!.content.profile.name,
        'Сохранённое имя',
      );
      await _tap(tester, 'main.editor.save');
      final saved = (await repository.read())!;
      expect(saved.content!.githubUsername, 'new-owner');
      expect(
        mainPortfolioDocument(saved.content!)!.content.profile.name,
        'Новое имя',
      );
      expect(saved.revision, before.revision + 1);
      expect(saved.notes, 'private');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved GitHub changes conflict with edited identity and preserve all editor input',
    (tester) async {
      final repository = await _repository(
        name: 'Сохранённое имя',
        githubUsername: 'old-owner',
      );
      final container = await _open(tester, repository);
      await _enter(tester, 'name', 'Несохранённое имя');
      await _enter(tester, 'github', 'my-edited-owner');
      expect(
        await container
            .read(portfolioDraftControllerProvider.notifier)
            .saveGitHubIdentity('other-owner', expectedRepository: repository),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(_value(tester, 'main.editor.github'), 'my-edited-owner');
      expect(_value(tester, 'main.editor.name'), 'Несохранённое имя');
      expect(
        find.text(
          'Сохранённая версия изменилась. Ваш ввод сохранён в редакторе.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<StackCardButton>(find.byKey(const Key('main.editor.save')))
            .onPressed,
        isNull,
      );
      final saved = (await repository.read())!;
      expect(saved.content!.githubUsername, 'other-owner');
      expect(
        mainPortfolioDocument(saved.content!)!.content.profile.name,
        'Сохранённое имя',
      );
      final working = container.read(portfolioDraftControllerProvider);
      expect(working.content!.githubUsername, 'my-edited-owner');
      expect(
        mainPortfolioDocument(working.content!)!.content.profile.name,
        'Несохранённое имя',
      );
      expect(working.hasUnsavedChanges, isTrue);
      expect(saved.notes, 'private');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'repository owner transition clears private editor input and rejects late Save',
    (tester) async {
      final first = await _repository(
        name: 'Первый владелец',
        githubUsername: 'first-owner',
      );
      final second = await _repository(
        name: 'Второй владелец',
        githubUsername: 'second-owner',
      );
      final repository = _BlockingSave(first);
      final container = await _open(tester, repository);
      await _enter(tester, 'name', 'Секрет первого владельца');
      await _enter(tester, 'github', 'first-private-owner');
      await tester.ensureVisible(find.byKey(const Key('main.editor.save')));
      await tester.tap(find.byKey(const Key('main.editor.save')));
      await tester.pump();
      container.updateOverrides([
        portfolioDraftRepositoryProvider.overrideWithValue(second),
      ]);
      await tester.pumpAndSettle();
      expect(_value(tester, 'main.editor.name'), 'Второй владелец');
      expect(_value(tester, 'main.editor.github'), 'second-owner');
      expect(find.text('Секрет первого владельца'), findsNothing);
      repository.release.complete();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_value(tester, 'main.editor.name'), 'Второй владелец');
      expect(_value(tester, 'main.editor.github'), 'second-owner');
      expect(
        mainPortfolioDocument((await second.read())!.content!)!
            .content
            .profile
            .name,
        'Второй владелец',
      );
      expect((await second.read())!.content!.githubUsername, 'second-owner');
      expect(find.text('Секрет первого владельца'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty project selector has exact state and library navigation', (
    tester,
  ) async {
    final repository = await _repository();
    await _open(tester, repository);
    await _tap(tester, 'main.editor.addProject');
    expect(find.text('Проектов пока нет'), findsOneWidget);
    expect(find.text('Создать проект'), findsNothing);
    await _tap(tester, 'main.projectSelection.library');
    expect(find.text('Библиотека проектов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chosen stock icon and GitHub identity save atomically', (
    tester,
  ) async {
    final repository = await _repository(
      projects: [
        PortfolioProject(
          id: 'one',
          title: 'Проект',
          description: '',
          technologies: const [],
          imagePaths: const [
            'accounts/test-owner/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg',
          ],
        ),
      ],
      attachments: const [PortfolioProjectAttachment(projectId: 'one')],
    );
    await _open(tester, repository);
    await _tap(tester, 'main.editor.icon.one');
    await _tap(tester, 'project.icon.camera');
    await _enter(tester, 'github', 'https://github.com/SNOWNUMB');
    await _tap(tester, 'main.editor.save');
    final workspace = (await repository.read())!.content!;
    expect(workspace.githubUsername, 'snownumb');
    expect(workspace.profile.username, isEmpty);
    expect(workspace.projects.single.iconId, 'camera');
    expect(workspace.projects.single.imagePaths, isNotEmpty);
    expect(
      resolvedMainPortfolioContent(workspace)!.projects.single.imagePaths,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact validation remains open and preserves entered values', (
    tester,
  ) async {
    final repository = await _repository();
    await _open(tester, repository);
    await _tap(tester, 'main.editor.addLink');
    await _enterForm(tester, 'label', 'Сайт');
    await _enterForm(tester, 'url', 'javascript:alert(1)');
    await _tap(tester, 'main.contact.apply');
    expect(find.byKey(const Key('main.contact.apply')), findsOneWidget);
    expect(_value(tester, 'builder_form_url'), 'javascript:alert(1)');
    await _enterForm(tester, 'url', 'https://example.com');
    await _tap(tester, 'main.contact.apply');
    await _tap(tester, 'main.editor.save');
    final link = mainPortfolioDocument((await repository.read())!.content!)!
        .content
        .links
        .single;
    expect(link.url, 'https://example.com');
    expect(link.publishAllowed, isTrue);
    expect(link.visible, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact modal clears private input when repository changes', (
    tester,
  ) async {
    final first = await _repository();
    final second = await _repository(name: 'Другой владелец');
    final container = await _open(tester, first);
    await _tap(tester, 'main.editor.addLink');
    await _enterForm(tester, 'label', 'Личный контакт прежнего владельца');
    await _enterForm(tester, 'url', 'https://private.example');
    container.updateOverrides([
      portfolioDraftRepositoryProvider.overrideWithValue(second),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('main.contact.apply')), findsNothing);
    expect(find.text('Личный контакт прежнего владельца'), findsNothing);
    expect(find.text('https://private.example'), findsNothing);
    expect(
      mainPortfolioDocument((await second.read())!.content!)!.content.links,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'navigation guard saves, cancels and discards the same local buffer',
    (tester) async {
      final repository = await _repository(name: 'Прежнее имя');
      final container = await _open(tester, repository);
      await _enter(tester, 'name', 'Новое имя');
      var operation = container.read(mainPortfolioEditorNavigationProvider)!();
      await tester.pumpAndSettle();
      await _tap(tester, 'main.editor.leave.stay');
      expect(await operation, isFalse);
      expect(_value(tester, 'main.editor.name'), 'Новое имя');
      operation = container.read(mainPortfolioEditorNavigationProvider)!();
      await tester.pumpAndSettle();
      await _tap(tester, 'main.editor.leave.discard');
      expect(await operation, isTrue);
      expect(_value(tester, 'main.editor.name'), 'Прежнее имя');
      expect(
        container.read(portfolioDraftControllerProvider).hasUnsavedChanges,
        isFalse,
      );
      await _enter(tester, 'name', 'Сохранённое новое имя');
      operation = container.read(mainPortfolioEditorNavigationProvider)!();
      await tester.pumpAndSettle();
      await _tap(tester, 'main.editor.leave.save');
      expect(await operation, isTrue);
      expect(
        mainPortfolioDocument((await repository.read())!.content!)!
            .content
            .profile
            .name,
        'Сохранённое новое имя',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fresh editor initializes main without attaching existing library projects',
    (tester) async {
      final repository = MemoryPortfolioDraftRepository();
      await repository.save(
        PortfolioContent(
          projects: [
            PortfolioProject(
              id: 'one',
              title: 'Library only',
              description: '',
              technologies: const [],
            ),
          ],
        ),
        expectedRevision: 0,
        notes: 'Private note',
      );
      await _open(tester, repository);
      final main = mainPortfolioDocument((await repository.read())!.content!);
      expect(main, isNotNull);
      expect(main!.projects, isEmpty);
      expect(find.byKey(const Key('main.editor.name')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'migration requires explicit choice and preserves original source',
    (tester) async {
      final repository = MemoryPortfolioDraftRepository();
      final first = _document('first', 'Первый', 'Имя первого');
      final second = _document('second', 'Второй', 'Имя второго');
      await repository.save(
        PortfolioContent(documents: [first, second]),
        expectedRevision: 0,
        notes: 'private',
      );
      await _open(tester, repository, migration: true);
      expect(
        tester
            .widget<StackCardButton>(
              find.byKey(const Key('main.migration.apply')),
            )
            .onPressed,
        isNull,
      );
      await _tap(tester, 'main.migration.preview.second');
      expect(find.text('Имя второго'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      await _tap(tester, 'main.migration.source.second');
      await _tap(tester, 'main.migration.apply');
      final workspace = (await repository.read())!.content!;
      expect(workspace.mainPortfolioId, 'second');
      expect(workspace.legacyMainSnapshot, second);
      expect(workspace.documents.first, first);
      expect(
        mainPortfolioDocument(workspace)!.content.profile.name,
        'Имя второго',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'read view omits empty sections and every project image/editor control',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _app(
            Scaffold(
              body: MainPortfolioContentView(
                content: PortfolioContent(
                  projects: [
                    PortfolioProject(
                      id: 'one',
                      title: 'Один проект',
                      description: '',
                      technologies: const [],
                      imagePaths: const [
                        'accounts/test-owner/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg',
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Один проект'), findsOneWidget);
      expect(find.text('Навыки'), findsNothing);
      expect(find.text('Контакты и ссылки'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Редактировать'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editor and modal work at width320 with text2 and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    final repository = await _repository(
      projects: [
        PortfolioProject(
          id: 'one',
          title: 'Длинное название для проверки переноса текста',
          description: '',
          technologies: const [],
        ),
      ],
      attachments: const [PortfolioProjectAttachment(projectId: 'one')],
    );
    await _open(tester, repository, textScale: 2);
    await _enter(tester, 'name', 'Очень длинное имя пользователя');
    await _tap(tester, 'main.editor.addProject');
    await _tap(tester, 'main.projectSelection.apply');
    await _tap(tester, 'main.editor.icon.one');
    await _tap(tester, 'project.icon.folder');
    await _enter(tester, 'github', 'snownumb');
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    final saveRect = tester.getRect(find.byKey(const Key('main.editor.save')));
    expect(saveRect.bottom, lessThanOrEqualTo(680 - 220));
    await _tap(tester, 'main.editor.save');
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (const Size(320, 640), 2.0),
    (const Size(320, 390), 1.0),
    (const Size(320, 390), 2.0),
    (const Size(568, 320), 2.0),
  ]) {
    testWidgets(
      'migration guidance scrolls within real shell ${scenario.$1} text${scenario.$2}',
      (tester) async {
        final previousHitTestPolicy =
            WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() {
          WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy;
        });
        tester.view.physicalSize = scenario.$1;
        final repository = MemoryPortfolioDraftRepository();
        await repository.save(
          PortfolioContent(
            profile: const PortfolioProfile(name: 'Прежний профиль'),
          ),
          expectedRevision: 0,
          notes: 'Приватные заметки',
        );
        final before = (await repository.read())!;
        await _open(tester, repository, textScale: scenario.$2, shell: true);
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('main.editor.statusScroll')),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const Key('main.editor.migrate')),
        );
        await tester.pumpAndSettle();
        final size = tester.getSize(
          find.byKey(const Key('main.editor.migrate')),
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        expect((await repository.read())!.content!.mainPortfolioId, isNull);
        expect(tester.takeException(), isNull);
        await _tap(tester, 'main.editor.migrate');
        expect(find.text('Выберите основу портфолио'), findsOneWidget);
        final after = (await repository.read())!;
        expect(after.revision, before.revision);
        expect(after.content, before.content);
        expect(after.notes, 'Приватные заметки');
        expect(find.text('Приватные заметки'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

PortfolioDocument _document(
  String id,
  String title,
  String name, {
  List<PortfolioProjectAttachment> attachments = const [],
  List<Skill> skills = const [],
}) => PortfolioDocument(
  id: id,
  title: title,
  kind: PortfolioDocumentKind.portfolio,
  createdAt: DateTime.utc(2026, 10, 11),
  updatedAt: DateTime.utc(2026, 10, 11),
  content: PortfolioContent(
    profile: PortfolioProfile(name: name),
    skills: skills,
  ),
  projects: attachments,
);

Future<MemoryPortfolioDraftRepository> _repository({
  String name = '',
  String githubUsername = '',
  List<PortfolioProject> projects = const [],
  List<PortfolioProjectAttachment> attachments = const [],
  List<Skill> skills = const [],
}) async {
  final repository = MemoryPortfolioDraftRepository();
  await repository.save(
    PortfolioContent(
      mainPortfolioId: 'main',
      githubUsername: githubUsername,
      projects: projects,
      documents: [
        _document(
          'main',
          'Основное',
          name,
          attachments: attachments,
          skills: skills,
        ),
      ],
    ),
    expectedRevision: 0,
    notes: 'private',
  );
  return repository;
}

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
  theme: StackCardTheme.light,
  locale: const Locale('ru'),
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppStrings.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

Future<ProviderContainer> _open(
  WidgetTester tester,
  PortfolioDraftRepository repository, {
  bool migration = false,
  double textScale = 1,
  bool shell = false,
}) async {
  final container = ProviderContainer(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: migration ? '/portfolio/migrate' : '/editor',
    routes: [
      GoRoute(
        path: '/editor',
        builder: (_, _) => shell
            ? const AppShell(
                location: '/editor',
                child: MainPortfolioEditorScreen(),
              )
            : const MainPortfolioEditorScreen(),
      ),
      GoRoute(
        path: '/portfolio/migrate',
        builder: (_, _) => const MainPortfolioMigrationScreen(),
      ),
      GoRoute(
        path: '/projects',
        builder: (_, _) => const Scaffold(body: Text('Библиотека проектов')),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Главная')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
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
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String field, String value) =>
    _enterKey(tester, 'main.editor.$field', value);
Future<void> _enterForm(WidgetTester tester, String field, String value) =>
    _enterKey(tester, 'builder_form_$field', value);
Future<void> _enterKey(WidgetTester tester, String key, String value) async {
  final finder = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

String _value(WidgetTester tester, String key) => tester
    .widget<TextFormField>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextFormField),
      ),
    )
    .controller!
    .text;

class _FailsOnce implements PortfolioDraftRepository {
  _FailsOnce(this.delegate);
  final PortfolioDraftRepository delegate;
  var fail = true;
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
    if (fail) {
      fail = false;
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.unavailable);
    }
    return delegate.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }
}

class _BlockingSave implements PortfolioDraftRepository {
  _BlockingSave(this.delegate);
  final PortfolioDraftRepository delegate;
  final started = Completer<void>();
  final release = Completer<void>();
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
    started.complete();
    await release.future;
    return delegate.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }
}
