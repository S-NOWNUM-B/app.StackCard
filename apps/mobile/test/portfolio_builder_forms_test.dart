import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/localization/builder_form_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft_providers.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_draft_controller.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_draft_state.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_education_editor_screen.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_experience_editor_screen.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_links_editor_screen.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_profile_editor_screen.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_project_editor_screen.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_resume_editor_screen.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_skills_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'Project Save retains newer input and blocks closing until captured write completes',
    (tester) async {
      final h = await _pumpEditor(tester, const PortfolioProjectEditorScreen());
      await _enter(tester, 'title', 'Submitted project');
      h.repository.saveGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('builder_form_apply')));
      await tester.pump();
      expect(h.state.saving, isTrue);
      await _enter(tester, 'title', 'Newer project');
      await tester.tap(find.byKey(const ValueKey('builder_form_cancel')));
      await tester.pump();
      expect(find.text('Back destination'), findsNothing);
      h.repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(
        h.repository.draft.content!.projects.single.title,
        'Submitted project',
      );
      expect(_textController(tester, 'title').text, 'Newer project');
      expect(find.text('Back destination'), findsNothing);
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(
        h.repository.draft.content!.projects.single.title,
        'Newer project',
      );
      expect(h.repository.draft.content!.projects, hasLength(1));
      expect(find.text('Back destination'), findsOneWidget);
    },
  );

  test('Form translations have matching keys and reach the real catalogue', () {
    expect(
      builderFormRussianStrings.keys.toSet(),
      builderFormEnglishStrings.keys.toSet(),
    );
    for (final locale in AppStrings.supportedLocales) {
      final strings = AppStrings(locale);
      expect(strings.keys, containsAll(builderFormEnglishStrings.keys));
      expect(
        strings.tr('builderForm.tooLong', {'limit': 100}),
        contains('100'),
      );
    }
  });

  testWidgets(
    'Profile Apply merges only its section and does not save storage',
    (tester) async {
      final h = await _pumpEditor(
        tester,
        const PortfolioProfileEditorScreen(),
        content: _filledContent(),
      );
      await _enter(tester, 'name', 'New name');
      await _enter(tester, 'username', 'new-user');
      h.controller.updateContent(
        h.content.copyWith(resumeText: 'Edited elsewhere'),
      );
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(find.text('Back destination'), findsOneWidget);
      expect(h.content.profile.name, 'New name');
      expect(h.content.profile.username, 'new-user');
      expect(h.content.resumeText, 'Edited elsewhere');
      expect(h.content.skills.single.name, 'Dart');
      expect(h.state.notes, 'Private notes');
      expect(h.repository.saves, 0);
      expect(h.state.hasUnsavedChanges, isTrue);
    },
  );

  testWidgets('Profile Cancel leaves the complete working snapshot unchanged', (
    tester,
  ) async {
    final initial = _filledContent();
    final h = await _pumpEditor(
      tester,
      const PortfolioProfileEditorScreen(),
      content: initial,
    );
    await _enter(tester, 'name', 'Discarded name');
    await _tap(tester, const ValueKey('builder_form_cancel'));
    expect(h.content, initial);
    expect(h.state.hasUnsavedChanges, isFalse);
  });

  testWidgets(
    'English username and URL validation blocks Apply without losing input',
    (tester) async {
      final initial = _filledContent();
      final h = await _pumpEditor(
        tester,
        const PortfolioProfileEditorScreen(),
        content: initial,
        locale: const Locale('en'),
      );
      await _enter(tester, 'username', 'BAD USER');
      await _enter(
        tester,
        'avatarUrl',
        'https://person:secret@example.com/photo',
      );
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(
        find.text(builderFormEnglishStrings['builderForm.invalidUsername']!),
        findsOneWidget,
      );
      expect(
        find.text(builderFormEnglishStrings['builderForm.invalidUrl']!),
        findsOneWidget,
      );
      expect(h.content, initial);
      expect(_textController(tester, 'username').text, 'BAD USER');
    },
  );

  testWidgets('Profile field limit uses domain validation', (tester) async {
    final h = await _pumpEditor(
      tester,
      const PortfolioProfileEditorScreen(),
      content: _filledContent(),
    );
    await _enter(tester, 'name', List.filled(101, 'x').join());
    await _tap(tester, const ValueKey('builder_form_apply'));
    expect(find.text('Не более 100 символов.'), findsOneWidget);
    expect(h.content.profile.name, 'Original name');
  });

  testWidgets('Resume Apply preserves plain text and line breaks', (
    tester,
  ) async {
    final h = await _pumpEditor(
      tester,
      const PortfolioResumeEditorScreen(),
      content: _filledContent(),
    );
    const text = '# Plain heading\nExperience <text>\n\nFinal line\n';
    await _enter(tester, 'resumeText', text);
    h.controller.updateContent(h.content.copyWith(theme: PortfolioTheme.light));
    await _tap(tester, const ValueKey('builder_form_apply'));
    expect(h.content.resumeText, text);
    expect(h.content.theme, PortfolioTheme.light);
    expect(h.state.notes, 'Private notes');
    expect(h.repository.saves, 0);
  });

  testWidgets('Resume limit retains typed content and prevents Apply', (
    tester,
  ) async {
    final h = await _pumpEditor(tester, const PortfolioResumeEditorScreen());
    final text = List.filled(20001, 'a').join();
    await _enter(tester, 'resumeText', text);
    await _tap(tester, const ValueKey('builder_form_apply'));
    expect(find.text('Не более 20000 символов.'), findsOneWidget);
    expect(h.content.resumeText, isEmpty);
    expect(_textController(tester, 'resumeText').text, text);
  });

  testWidgets(
    'Manual project create validates, saves Library content and leaves document flags to attachments',
    (tester) async {
      final h = await _pumpEditor(tester, const PortfolioProjectEditorScreen());
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(find.text('Заполните поле.'), findsOneWidget);
      await _enter(tester, 'title', 'My project');
      await _enter(tester, 'description', 'Local case\nSecond line');
      await _enter(tester, 'contribution', 'Built the accessible interface');
      await _enter(
        tester,
        'technologies',
        List.generate(21, (index) => 'Tech$index').join(', '),
      );
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(find.text('Не более 20 технологий.'), findsOneWidget);
      await _enter(tester, 'technologies', 'Flutter, Dart,  ');
      await _enter(tester, 'repositoryUrl', '/relative');
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(
        find.text(builderFormRussianStrings['builderForm.invalidUrl']!),
        findsOneWidget,
      );
      await _enter(
        tester,
        'repositoryUrl',
        'https://github.com/example/project',
      );
      await _enter(tester, 'liveUrl', 'https://example.com/demo');
      expect(find.byKey(const ValueKey('builder_form_featured')), findsNothing);
      expect(find.byKey(const ValueKey('builder_form_visible')), findsNothing);
      await _tap(tester, const ValueKey('builder_form_apply'));
      final project = h.content.projects.single;
      expect(project.id, isNotEmpty);
      expect(project.title, 'My project');
      expect(project.description, 'Local case\nSecond line');
      expect(project.contribution, 'Built the accessible interface');
      expect(project.technologies, ['Flutter', 'Dart']);
      expect(project.repositoryUrl, 'https://github.com/example/project');
      expect(project.liveUrl, 'https://example.com/demo');
      expect(project.featured, isFalse);
      expect(project.visible, isTrue);
      expect(h.repository.saves, 1);
    },
  );

  testWidgets(
    'Project edit preserves stable identity and concurrent other-section changes',
    (tester) async {
      final h = await _pumpEditor(
        tester,
        const PortfolioProjectEditorScreen(projectId: 'project1'),
        content: _filledContent(),
      );
      await _enter(tester, 'title', 'Edited project');
      h.controller.updateContent(h.content.copyWith(resumeText: 'New resume'));
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(h.content.projects.single.id, 'project1');
      expect(h.content.projects.single.title, 'Edited project');
      expect(h.content.projects.single.featured, isTrue);
      expect(h.content.resumeText, 'New resume');
    },
  );

  testWidgets('Changing project identity resets buffered fields before Apply', (
    tester,
  ) async {
    final selectedId = ValueNotifier('project1');
    addTearDown(selectedId.dispose);
    final initial = _filledContent();
    final second = PortfolioProject(
      id: 'project2',
      title: 'Second project',
      description: '',
      technologies: [],
    );
    final h = await _pumpEditor(
      tester,
      ValueListenableBuilder<String>(
        valueListenable: selectedId,
        builder: (_, id, _) => PortfolioProjectEditorScreen(projectId: id),
      ),
      content: initial.copyWith(projects: [...initial.projects, second]),
    );
    await _enter(tester, 'title', 'Unapplied first edit');
    selectedId.value = 'project2';
    await tester.pumpAndSettle();
    expect(_textController(tester, 'title').text, 'Second project');
    await _enter(tester, 'title', 'Edited second');
    await _tap(tester, const ValueKey('builder_form_apply'));
    expect(h.content.projects.first.title, 'Original project');
    expect(h.content.projects.last.id, 'project2');
    expect(h.content.projects.last.title, 'Edited second');
  });

  testWidgets('New project Cancel does not append an entry', (tester) async {
    final h = await _pumpEditor(tester, const PortfolioProjectEditorScreen());
    await _enter(tester, 'title', 'Discarded project');
    await _tap(tester, const ValueKey('builder_form_cancel'));
    expect(find.byKey(const ValueKey('project.leave.stay')), findsOneWidget);
    await _tap(tester, const ValueKey('project.leave.stay'));
    expect(_textController(tester, 'title').text, 'Discarded project');
    await _tap(tester, const ValueKey('builder_form_cancel'));
    await _tap(tester, const ValueKey('project.leave.discard'));
    expect(find.text('Back destination'), findsOneWidget);
    expect(h.content.projects, isEmpty);
  });

  testWidgets('Missing project is honest and cannot apply', (tester) async {
    final h = await _pumpEditor(
      tester,
      const PortfolioProjectEditorScreen(projectId: 'missing'),
    );
    expect(find.text('Проект не найден'), findsOneWidget);
    expect(find.byKey(const ValueKey('builder_form_title')), findsNothing);
    expect(
      _button(tester, const ValueKey('builder_form_apply')).onPressed,
      isNull,
    );
    expect(h.content.projects, isEmpty);
  });

  for (final collection in _collections) {
    testWidgets('$collection CRUD is local until Apply and preserves IDs', (
      tester,
    ) async {
      final h = await _pumpEditor(
        tester,
        collection.screen,
        content: _filledContent(),
      );
      await _tap(
        tester,
        const ValueKey(('builder_collection_edit', 'existing')),
      );
      await _enter(tester, collection.firstField, 'Edited entry');
      await _tap(tester, const ValueKey('builder_record_apply'));
      expect(find.text('Edited entry'), findsOneWidget);
      expect(collection.titles(h.content), isNot(contains('Edited entry')));
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(collection.titles(h.content), ['Edited entry']);
      expect(collection.ids(h.content), ['existing']);

      await h.open(tester);
      await _tap(tester, const ValueKey('builder_collection_add'));
      for (final field in collection.newFields.entries) {
        await _enter(tester, field.key, field.value);
      }
      await _tap(tester, const ValueKey('builder_record_apply'));
      expect(collection.titles(h.content), hasLength(1));
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(collection.titles(h.content), hasLength(2));
      expect(collection.ids(h.content).toSet(), hasLength(2));

      await h.open(tester);
      await _tap(
        tester,
        const ValueKey(('builder_collection_delete', 'existing')),
      );
      await _tap(tester, const ValueKey('builder_form_apply'));
      expect(collection.titles(h.content), [
        collection.newFields[collection.firstField],
      ]);
      expect(h.repository.saves, 0);
    });

    testWidgets(
      '$collection empty record validation does not append invalid data',
      (tester) async {
        final h = await _pumpEditor(tester, collection.screen);
        await _tap(tester, const ValueKey('builder_collection_add'));
        await _tap(tester, const ValueKey('builder_record_apply'));
        expect(find.text('Заполните поле.'), findsWidgets);
        expect(collection.titles(h.content), isEmpty);
        await _tap(tester, const ValueKey('builder_record_cancel'));
        await _tap(tester, const ValueKey('builder_form_apply'));
        expect(collection.titles(h.content), isEmpty);
      },
    );
  }

  testWidgets(
    'Deleting from local collection then Cancel restores original state',
    (tester) async {
      final initial = _filledContent();
      final h = await _pumpEditor(
        tester,
        const PortfolioSkillsEditorScreen(),
        content: initial,
      );
      await _tap(
        tester,
        const ValueKey(('builder_collection_delete', 'existing')),
      );
      expect(find.text('Список пока пуст'), findsOneWidget);
      await _tap(tester, const ValueKey('builder_form_cancel'));
      expect(h.content, initial);
    },
  );

  testWidgets('Link URL uses the same public domain rule', (tester) async {
    final h = await _pumpEditor(
      tester,
      const PortfolioLinksEditorScreen(),
      locale: const Locale('en'),
    );
    await _tap(tester, const ValueKey('builder_collection_add'));
    await _enter(tester, 'linkLabel', 'My website');
    await _enter(tester, 'linkUrl', 'https://user@example.com');
    await _tap(tester, const ValueKey('builder_record_apply'));
    expect(
      find.text(builderFormEnglishStrings['builderForm.invalidUrl']!),
      findsOneWidget,
    );
    expect(h.content.links, isEmpty);
  });

  testWidgets(
    'Legacy notes do not become public content or create Builder implicitly',
    (tester) async {
      final h = await _pumpEditor(
        tester,
        const PortfolioProfileEditorScreen(),
        legacy: true,
      );
      expect(find.text('Builder ещё не начат'), findsOneWidget);
      expect(
        _button(tester, const ValueKey('builder_form_apply')).onPressed,
        isNull,
      );
      expect(h.state.content, isNull);
      expect(h.state.notes, 'Private notes');
      expect(h.repository.saves, 0);
    },
  );

  testWidgets('Read failure blocks forms and presents explicit retry', (
    tester,
  ) async {
    final h = await _pumpEditor(
      tester,
      const PortfolioProfileEditorScreen(),
      failure: PortfolioDraftFailureKind.corrupted,
    );
    expect(find.text('Редактор недоступен'), findsOneWidget);
    expect(
      find.text(builderFormRussianStrings['builderForm.corrupted']!),
      findsOneWidget,
    );
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.byKey(const ValueKey('builder_form_name')), findsNothing);
    expect(
      _button(tester, const ValueKey('builder_form_apply')).onPressed,
      isNull,
    );
    expect(h.repository.saves, 0);
  });

  testWidgets(
    'Keyboard Done on final profile field applies through the same validation',
    (tester) async {
      final h = await _pumpEditor(
        tester,
        const PortfolioProfileEditorScreen(),
        content: _filledContent(),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await _enter(tester, 'avatarUrl', 'https://example.com/avatar.png');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Back destination'), findsOneWidget);
      expect(h.content.profile.avatarUrl, 'https://example.com/avatar.png');
    },
  );

  final editors = <String, Widget>{
    'profile': const PortfolioProfileEditorScreen(),
    'skills': const PortfolioSkillsEditorScreen(),
    'experience': const PortfolioExperienceEditorScreen(),
    'education': const PortfolioEducationEditorScreen(),
    'links': const PortfolioLinksEditorScreen(),
    'resume': const PortfolioResumeEditorScreen(),
    'project': const PortfolioProjectEditorScreen(projectId: 'project1'),
  };
  for (final entry in editors.entries) {
    for (final layout in [
      (const Size(320, 640), const Locale('en'), ThemeMode.dark),
      (const Size(844, 390), const Locale('ru'), ThemeMode.light),
    ]) {
      testWidgets(
        'Large text form $entry $layout has no overflow and Apply is reachable',
        (tester) async {
          await _pumpEditor(
            tester,
            entry.value,
            content: _filledContent(),
            size: layout.$1,
            locale: layout.$2,
            theme: layout.$3,
            scale: 2,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('builder_form_apply')),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(
            _button(tester, const ValueKey('builder_form_apply')).onPressed,
            isNotNull,
          );
        },
      );
    }
  }
  for (final collection in _collections) {
    testWidgets(
      'Large text English $collection dialog stays scrollable with validation',
      (tester) async {
        await _pumpEditor(
          tester,
          collection.screen,
          size: const Size(320, 640),
          locale: const Locale('en'),
          scale: 2,
        );
        await _tap(tester, const ValueKey('builder_collection_add'));
        await _tap(tester, const ValueKey('builder_record_apply'));
        await tester.ensureVisible(
          find.byKey(const ValueKey('builder_record_cancel')),
        );
        await tester.pump();
        expect(find.text('Complete this field.'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final _collections = [
  _CollectionCase(
    'skills',
    const PortfolioSkillsEditorScreen(),
    'skillName',
    {'skillName': 'New skill'},
    (content) => content.skills.map((item) => item.name).toList(),
    (content) => content.skills.map((item) => item.id).toList(),
  ),
  _CollectionCase(
    'experience',
    const PortfolioExperienceEditorScreen(),
    'role',
    {
      'role': 'New role',
      'organization': 'Organization',
      'period': '2024–2026',
      'description': 'Description',
    },
    (content) => content.experience.map((item) => item.role).toList(),
    (content) => content.experience.map((item) => item.id).toList(),
  ),
  _CollectionCase(
    'education',
    const PortfolioEducationEditorScreen(),
    'institution',
    {
      'institution': 'New university',
      'qualification': 'Computer science',
      'period': '2020–2024',
      'description': 'Description',
    },
    (content) => content.education.map((item) => item.institution).toList(),
    (content) => content.education.map((item) => item.id).toList(),
  ),
  _CollectionCase(
    'links',
    const PortfolioLinksEditorScreen(),
    'linkLabel',
    {'linkLabel': 'New website', 'linkUrl': 'https://example.com/new'},
    (content) => content.links.map((item) => item.label).toList(),
    (content) => content.links.map((item) => item.id).toList(),
  ),
];

class _CollectionCase {
  const _CollectionCase(
    this.name,
    this.screen,
    this.firstField,
    this.newFields,
    this.titles,
    this.ids,
  );
  final String name;
  final Widget screen;
  final String firstField;
  final Map<String, String> newFields;
  final List<String> Function(PortfolioContent) titles;
  final List<String> Function(PortfolioContent) ids;
  @override
  String toString() => name;
}

PortfolioContent _filledContent() => PortfolioContent(
  profile: const PortfolioProfile(
    name: 'Original name',
    username: 'original-user',
    headline: 'Developer',
    bio: 'About me',
    locationText: 'Almaty',
  ),
  skills: const [Skill(id: 'existing', name: 'Dart')],
  projects: [
    PortfolioProject(
      id: 'project1',
      title: 'Original project',
      description: 'Description',
      technologies: ['Dart'],
      featured: true,
    ),
  ],
  experience: const [
    Experience(
      id: 'existing',
      role: 'Developer',
      organization: 'Original organization',
      period: '2024–2026',
      description: 'Description',
    ),
  ],
  education: const [
    Education(
      id: 'existing',
      institution: 'Original institution',
      qualification: 'Degree',
      period: '2020–2024',
      description: 'Description',
    ),
  ],
  links: const [
    SocialLink(
      id: 'existing',
      label: 'Original link',
      url: 'https://example.com',
      kind: SocialLinkKind.website,
    ),
  ],
  resumeText: 'Original resume',
);

Future<_Harness> _pumpEditor(
  WidgetTester tester,
  Widget editor, {
  PortfolioContent? content,
  bool legacy = false,
  Locale locale = const Locale('ru'),
  ThemeMode theme = ThemeMode.dark,
  Size size = const Size(390, 844),
  double scale = 1,
  PortfolioDraftFailureKind? failure,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _Repository(
    PortfolioDraft(
      notes: 'Private notes',
      revision: 7,
      updatedAt: DateTime.utc(2026, 10, 3),
      pendingSync: true,
      content: legacy ? null : content ?? PortfolioContent(),
    ),
    failure: failure,
  );
  final container = ProviderContainer(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(repository)],
  );
  final router = GoRouter(
    initialLocation: '/return',
    routes: [
      GoRoute(
        path: '/return',
        builder: (_, _) => const Scaffold(body: Text('Back destination')),
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
        themeMode: theme,
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
  final harness = _Harness(container, router, repository);
  await harness.open(tester);
  return harness;
}

class _Harness {
  const _Harness(this.container, this.router, this.repository);
  final ProviderContainer container;
  final GoRouter router;
  final _Repository repository;
  PortfolioContent get content => state.content!;
  PortfolioDraftState get state =>
      container.read(portfolioDraftControllerProvider);
  PortfolioDraftController get controller =>
      container.read(portfolioDraftControllerProvider.notifier);
  Future<void> open(WidgetTester tester) async {
    router.push('/editor');
    await tester.pumpAndSettle();
  }
}

class _Repository implements PortfolioDraftRepository {
  _Repository(this.draft, {this.failure});
  PortfolioDraft draft;
  final PortfolioDraftFailureKind? failure;
  int saves = 0;
  Completer<void>? saveGate;

  @override
  Future<PortfolioDraft?> read() async {
    if (failure != null) throw PortfolioDraftFailure(failure!);
    return draft;
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) async {
    saves++;
    draft = PortfolioDraft(
      notes: notes,
      revision: draft.revision + 1,
      updatedAt: DateTime.utc(2026, 10, 3),
      pendingSync: true,
      content: draft.content,
    );
    return draft;
  }

  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    await saveGate?.future;
    if (draft.revision != expectedRevision) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.conflict);
    }
    saves++;
    draft = PortfolioDraft(
      notes: notes,
      revision: draft.revision + 1,
      updatedAt: DateTime.utc(2026, 10, 3),
      pendingSync: true,
      content: content,
    );
    return draft;
  }
}

TextEditingController _textController(WidgetTester tester, String field) =>
    tester
        .widget<TextFormField>(
          find.descendant(
            of: find.byKey(ValueKey('builder_form_$field')),
            matching: find.byType(TextFormField),
          ),
        )
        .controller!;

Future<void> _enter(WidgetTester tester, String field, String value) async {
  final target = find.byKey(ValueKey('builder_form_$field'));
  if (field == 'technologies' && target.evaluate().isEmpty) {
    await _tap(tester, const ValueKey('project.technologies.edit'));
  }
  await tester.ensureVisible(target);
  await tester.enterText(target, value);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

FilledButton _button(WidgetTester tester, Key key) =>
    tester.widget<FilledButton>(
      find.descendant(of: find.byKey(key), matching: find.byType(FilledButton)),
    );
