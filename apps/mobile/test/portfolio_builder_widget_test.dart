import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
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
    'Starting Builder preserves notes and creates only an empty unsaved portfolio',
    (tester) async {
      final repository = MemoryPortfolioDraftRepository();
      await repository.saveNotes('PRIVATE_NOTES_NEVER_PUBLIC');
      await _open(tester, repository);
      expect(find.text('Портфолио ещё не создано'), findsOneWidget);
      await _tap(tester, 'builder_start');
      final container = _container(tester);
      final state = container.read(portfolioDraftControllerProvider);
      expect(state.notes, 'PRIVATE_NOTES_NEVER_PUBLIC');
      expect(state.content!.profile.name, isEmpty);
      expect(state.content!.projects, isEmpty);
      expect(find.text('Готовность: 0%'), findsOneWidget);
      expect(find.text('Есть несохранённые изменения'), findsOneWidget);
      expect((await repository.read())!.content, isNull);
      await _tap(tester, 'builder_save');
      expect((await repository.read())!.content, PortfolioContent());
      expect(find.text('Сохранено на устройстве'), findsOneWidget);
      expect((await repository.read())!.notes, 'PRIVATE_NOTES_NEVER_PUBLIC');
      await _tap(tester, 'builder_preview');
      expect(find.text('В видимых блоках пока нет данных'), findsOneWidget);
      expect(find.textContaining('PRIVATE_NOTES_NEVER_PUBLIC'), findsNothing);
    },
  );

  testWidgets(
    'Project flags and confirmed deletion change working content until Save',
    (tester) async {
      final repository = await _repository(_content());
      await _open(tester, repository);
      await _tap(tester, 'builder_featured_project-1');
      expect(_state(tester).content!.projects.single.featured, isFalse);
      await _tap(tester, 'builder_visible_project-1');
      expect(_state(tester).content!.projects.single.visible, isFalse);
      expect(_state(tester).completion!.percent, 80);
      await _tap(tester, 'builder_delete_project-1');
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(_state(tester).content!.projects.length, 1);
      await _tap(tester, 'builder_delete_project-1');
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(_state(tester).content!.projects, isEmpty);
      expect((await repository.read())!.content!.projects.length, 1);
      await _tap(tester, 'builder_save');
      expect((await repository.read())!.content!.projects, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Block order and visibility plus independent light theme apply immediately to preview',
    (tester) async {
      final repository = await _repository(_content());
      await _open(tester, repository);
      expect(find.text('Готовность: 100%'), findsOneWidget);
      await _tap(tester, 'builder_block_up_about');
      await _tap(tester, 'builder_block_profile');
      expect(_state(tester).completion!.percent, 100);
      await _tap(tester, 'builder_theme_light');
      expect(_state(tester).content!.theme, PortfolioTheme.light);
      final router = GoRouter.of(
        tester.element(find.byType(PortfolioBuilderScreen)),
      );
      router.push('/portfolio/preview');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('portfolio_block_profile')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('portfolio_block_about')),
        findsOneWidget,
      );
      final cards =
          tester.widgetList(find.byType(PortfolioContentView)).single
              as PortfolioContentView;
      expect(cards.content.blocks.first.kind, PortfolioBlockKind.about);
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('portfolio_block_about'))),
        ).brightness,
        Brightness.light,
      );
      expect(find.text('Есть несохранённые изменения'), findsOneWidget);
      expect(find.textContaining('PRIVATE_NOTES_NEVER_PUBLIC'), findsNothing);
      expect((await repository.read())!.content!.theme, PortfolioTheme.dark);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Conflict retains edits and reload dialog Cancel never discards them',
    (tester) async {
      final repository = await _repository(_content());
      await _open(tester, repository);
      final container = _container(tester);
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      controller.updateContent(
        _content().copyWith(resumeText: 'My unsaved resume'),
      );
      controller.updateNotes('My unsaved private notes');
      await repository.save(
        _content().copyWith(resumeText: 'External durable resume'),
        expectedRevision: 1,
        notes: 'External private notes',
      );
      await tester.pump();
      await _tap(tester, 'builder_save');
      expect(
        find.textContaining('Сохранённая версия изменилась'),
        findsOneWidget,
      );
      expect(_state(tester).content!.resumeText, 'My unsaved resume');
      await _tap(tester, 'builder_reload');
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(_state(tester).notes, 'My unsaved private notes');
      await _tap(tester, 'builder_reload');
      await tester.tap(find.text('Открыть сохранённое'));
      await tester.pumpAndSettle();
      expect(_state(tester).content!.resumeText, 'External durable resume');
      expect(_state(tester).notes, 'External private notes');
      expect(_state(tester).hasUnsavedChanges, isFalse);
      expect(_state(tester).draft!.revision, 2);
    },
  );

  testWidgets(
    'Direct preview shows typed load failure and explicitly retries',
    (tester) async {
      final repository = _ReadFailureSource();
      await _open(tester, repository, route: '/portfolio/preview');
      expect(find.text('Не удалось открыть черновик'), findsOneWidget);
      expect(find.text('Портфолио ещё не создано'), findsNothing);
      expect(find.textContaining('/private/'), findsNothing);
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Test Developer'), findsOneWidget);
      expect(repository.reads, 2);
      expect(find.textContaining('PRIVATE_NOTES_NEVER_PUBLIC'), findsNothing);
    },
  );

  testWidgets('English Builder labels and theme are localized', (tester) async {
    await _open(
      tester,
      await _repository(_content()),
      language: AppLanguage.en,
    );
    expect(find.text('Portfolio editor'), findsOneWidget);
    expect(find.text('Save portfolio'), findsOneWidget);
    expect(find.text('Completion: 100%'), findsOneWidget);
    await _tap(tester, 'builder_theme_light');
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Редактор портфолио'), findsNothing);
  });

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    for (final viewport in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(768, 1024),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Builder and preview ${theme.name} $viewport text $scale', (
          tester,
        ) async {
          tester.view.physicalSize = viewport;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final content = _content().copyWith(
            theme: theme == AppTheme.light
                ? PortfolioTheme.light
                : PortfolioTheme.dark,
          );
          await _open(tester, await _repository(content), theme: theme);
          expect(tester.takeException(), isNull);
          await _tap(tester, 'builder_theme_light');
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            final semantics = tester.ensureSemantics();
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            // Scroll clipping сокращает semantics rect у крайних строк.
            // Проверяем полные layout targets каждого типа control.
            final targets = find.byWidgetPredicate(
              (widget) =>
                  widget is FilledButton ||
                  widget is IconButton ||
                  widget is SwitchListTile ||
                  widget is RadioListTile<PortfolioTheme>,
            );
            for (var index = 0; index < targets.evaluate().length; index++) {
              final size = tester.getSize(targets.at(index));
              expect(size.width, greaterThanOrEqualTo(48));
              expect(size.height, greaterThanOrEqualTo(48));
            }
            semantics.dispose();
          }
          final router = GoRouter.of(
            tester.element(find.byType(PortfolioBuilderScreen)),
          );
          router.push('/portfolio/preview');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(SingleChildScrollView).last,
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.textContaining('PRIVATE_NOTES_NEVER_PUBLIC'),
            findsNothing,
          );
        });
      }
    }
  }
}

Future<MemoryPortfolioDraftRepository> _repository(
  PortfolioContent content,
) async {
  final repository = MemoryPortfolioDraftRepository();
  await repository.save(
    content,
    expectedRevision: 0,
    notes: 'PRIVATE_NOTES_NEVER_PUBLIC',
  );
  return repository;
}

PortfolioContent _content() => PortfolioContent(
  profile: const PortfolioProfile(
    name: 'Test Developer',
    username: 'test-dev',
    headline: 'Flutter developer',
    bio: 'My public bio',
    locationText: 'Almaty',
  ),
  skills: const [Skill(id: 'skill-1', name: 'Flutter')],
  projects: [
    PortfolioProject(
      id: 'project-1',
      title: 'Manual project with a descriptive title',
      description: 'Project description',
      technologies: ['Flutter'],
      repositoryUrl: 'https://github.com/example/project',
      featured: true,
    ),
  ],
  experience: const [
    Experience(
      id: 'experience-1',
      role: 'Developer',
      organization: 'Studio',
      period: '2024–2026',
      description: 'Built applications',
    ),
  ],
  education: const [
    Education(
      id: 'education-1',
      institution: 'University',
      qualification: 'Engineering',
      period: '2022–2026',
      description: '',
    ),
  ],
  links: const [
    SocialLink(id: 'link-1', label: 'Website', url: 'https://example.com'),
  ],
  resumeText: 'Resume line one\nResume line two',
);

Future<void> _open(
  WidgetTester tester,
  PortfolioDraftRepository repository, {
  String route = '/portfolio/builder',
  AppTheme theme = AppTheme.dark,
  AppLanguage language = AppLanguage.ru,
}) async {
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: route,
      initialSettings: AppSettings(theme: theme, language: language),
      providerOverrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(PortfolioBuilderScreen)),
);
PortfolioDraftState _state(WidgetTester tester) =>
    _container(tester).read(portfolioDraftControllerProvider);

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _ReadFailureSource implements PortfolioDraftRepository {
  int reads = 0;
  @override
  Future<PortfolioDraft?> read() async {
    if (++reads == 1) throw StateError('/private/storage-detail');
    return PortfolioDraft(
      notes: 'PRIVATE_NOTES_NEVER_PUBLIC',
      revision: 1,
      updatedAt: DateTime.utc(2026),
      pendingSync: true,
      content: _content(),
    );
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) async =>
      throw UnimplementedError();
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async => throw UnimplementedError();
}
