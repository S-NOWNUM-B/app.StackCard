import 'dart:typed_data';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _time = DateTime.utc(2026, 11, 17);

PortfolioProject _project(String id, String title, List<String> tech) =>
    PortfolioProject(id: id, title: title, description: '', technologies: tech);

Future<MemoryPortfolioDraftRepository> _repository({bool empty = false}) async {
  final repository = MemoryPortfolioDraftRepository();
  await repository.save(
    empty
        ? PortfolioContent()
        : PortfolioContent(
            mainPortfolioId: 'main',
            projects: [
              _project('web', 'Веб-сайт', ['React']),
              _project('app', 'Мобильное приложение', ['Flutter', 'Dart']),
            ],
            documents: [
              PortfolioDocument(
                id: 'main',
                title: 'Основное',
                kind: PortfolioDocumentKind.portfolio,
                createdAt: _time,
                updatedAt: _time,
                content: PortfolioContent(
                  profile: const PortfolioProfile(
                    name: 'Имя',
                    headline: 'Mobile разработчик',
                  ),
                  skills: const [
                    Skill(id: 's1', name: 'Flutter'),
                    Skill(id: 's2', name: 'Dart'),
                  ],
                ),
                projects: const [
                  PortfolioProjectAttachment(projectId: 'web'),
                  PortfolioProjectAttachment(projectId: 'app'),
                ],
              ),
            ],
          ),
    expectedRevision: 0,
    notes: 'private',
  );
  return repository;
}

class _Pdf implements PortfolioPdfGenerator {
  PortfolioContent? content;
  @override
  Future<Uint8List> generate(
    PortfolioContent savedContent, {
    Uint8List? avatarBytes,
  }) async {
    content = savedContent;
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]);
  }
}

class _Files implements PortfolioPdfFileActions {
  String? filename;
  @override
  Future<bool> savePdf(
    Uint8List bytes, {
    String filename = 'stackcard-portfolio.pdf',
  }) async {
    this.filename = filename;
    return true;
  }
}

class _Harness {
  _Harness(this.container, this.repository, this.pdf, this.files);
  final ProviderContainer container;
  final MemoryPortfolioDraftRepository repository;
  final _Pdf pdf;
  final _Files files;
}

Future<_Harness> _open(
  WidgetTester tester, {
  bool empty = false,
  ThemeData? theme,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = await _repository(empty: empty);
  final pdf = _Pdf();
  final files = _Files();
  final router = GoRouter(
    initialLocation: '/vacancy',
    routes: [
      GoRoute(path: '/vacancy', builder: (_, _) => const VacancyMatchScreen()),
      GoRoute(path: '/editor', builder: (_, _) => const Text('editor stub')),
      GoRoute(path: '/projects', builder: (_, _) => const Text('projects')),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      portfolioDraftRepositoryProvider.overrideWithValue(repository),
      portfolioPdfGeneratorProvider.overrideWithValue(pdf),
      portfolioPdfFileActionsProvider.overrideWithValue(files),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme ?? StackCardTheme.light,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container, repository, pdf, files);
}

Future<void> _enter(WidgetTester tester, String value) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('vacancy.input')),
      matching: find.byType(TextField),
    ),
    value,
  );
  await tester.pump();
}

Future<void> _compare(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('vacancy.compare')));
  await tester.tap(find.byKey(const Key('vacancy.compare')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Without a saved portfolio the screen asks to fill it first', (
    tester,
  ) async {
    await _open(tester, empty: true);
    expect(find.text('Сначала заполните портфолио'), findsOneWidget);
    expect(find.byKey(const Key('vacancy.input')), findsNothing);
  });

  testWidgets('A short text is rejected and Compare stays disabled', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byKey(const Key('vacancy.tooShort')), findsNothing);
    await _enter(tester, 'React');
    expect(find.byKey(const Key('vacancy.tooShort')), findsOneWidget);
    final button = find.descendant(
      of: find.byKey(const Key('vacancy.compare')),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('Compare shows matched and missing requirements and projects', (
    tester,
  ) async {
    await _open(tester);
    await _enter(tester, 'Ищем: Flutter, Dart, Firebase и Docker обязательно');
    await _compare(tester);
    expect(find.text('Совпало 2 из 4'), findsOneWidget);
    expect(find.text('50% соответствия'), findsOneWidget);
    expect(find.text('Не хватает'), findsOneWidget);
    expect(find.text('Firebase'), findsOneWidget);
    expect(find.text('Мобильное приложение'), findsOneWidget);
    // Релевантный проект идёт первым.
    final app = tester.getTopLeft(find.text('Мобильное приложение'));
    final web = tester.getTopLeft(find.text('Веб-сайт'));
    expect(app.dy, lessThan(web.dy));
  });

  testWidgets('A text without known requirements explains it', (tester) async {
    await _open(tester);
    await _enter(tester, 'Дружная команда, кофе по пятницам и пицца');
    await _compare(tester);
    expect(find.byKey(const Key('vacancy.noRequirements')), findsOneWidget);
    expect(find.byKey(const Key('vacancy.apply')), findsNothing);
  });

  testWidgets('A vacancy with no matches says so', (tester) async {
    await _open(tester);
    await _enter(tester, 'Нужны Rust, Kafka и Terraform в команде');
    await _compare(tester);
    expect(find.byKey(const Key('vacancy.noMatches')), findsOneWidget);
    expect(find.text('Совпало 0 из 3'), findsOneWidget);
  });

  testWidgets('Apply order hands the order to the Editor without saving', (
    tester,
  ) async {
    final h = await _open(tester);
    final before = await h.repository.read();
    await _enter(tester, 'Flutter и Dart для мобильной разработки');
    await _compare(tester);
    await tester.ensureVisible(find.byKey(const Key('vacancy.apply')));
    await tester.tap(find.byKey(const Key('vacancy.apply')));
    await tester.pumpAndSettle();
    expect(find.text('editor stub'), findsOneWidget);
    final order = h.container.read(mainPortfolioEditorOrderProvider)!;
    expect(order.projects, ['app', 'web']);
    final after = await h.repository.read();
    expect(after!.revision, before!.revision);
  });

  testWidgets(
    'The vacancy never reaches the draft, history or Hive-like stores',
    (tester) async {
      final h = await _open(tester);
      const secret = 'СЕКРЕТНАЯ-ВАКАНСИЯ Flutter Dart Docker';
      final before = h.container.read(portfolioDraftControllerProvider).content;
      final revision = (await h.repository.read())!.revision;
      await _enter(tester, secret);
      await _compare(tester);
      await tester.ensureVisible(find.byKey(const Key('vacancy.export')));
      await tester.tap(find.byKey(const Key('vacancy.export')));
      await tester.pumpAndSettle();
      final state = h.container.read(portfolioDraftControllerProvider);
      expect(state.content, before);
      expect(state.hasUnsavedChanges, isFalse);
      final stored = await h.repository.read();
      expect(stored!.revision, revision);
      expect(stored.notes, 'private');
      expect(stored.toString(), isNot(contains('СЕКРЕТНАЯ')));
      // История версий пишется только при Save, подбор её не трогает.
      expect(
        await h.container.read(portfolioHistoryRepositoryProvider)!.list(),
        isEmpty,
      );
      expect(h.container.read(mainPortfolioEditorOrderProvider), isNull);
    },
  );

  testWidgets('PDF export keeps only chosen projects and sections in order', (
    tester,
  ) async {
    final h = await _open(tester);
    await _enter(tester, 'Flutter, Dart и React для мобильной разработки');
    await _compare(tester);
    final web = find.byKey(const Key('vacancy.project.web'));
    await tester.ensureVisible(web);
    await tester.tap(web);
    await tester.pump();
    final education = find.byKey(const Key('vacancy.section.education'));
    await tester.ensureVisible(education);
    await tester.tap(education);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('vacancy.export')));
    await tester.tap(find.byKey(const Key('vacancy.export')));
    await tester.pumpAndSettle();
    final content = h.pdf.content!;
    expect(content.projects.map((p) => p.id), ['app']);
    final hidden = content.blocks
        .where((block) => !block.visible)
        .map((block) => block.kind);
    expect(hidden, contains(PortfolioBlockKind.education));
    expect(hidden, isNot(contains(PortfolioBlockKind.skills)));
    expect(h.files.filename, 'stackcard-vacancy.pdf');
  });

  testWidgets('A hundred lines and very long words fit without overflow', (
    tester,
  ) async {
    await _open(tester, width: 320);
    final text = [
      for (var i = 0; i < 120; i++) 'Строка требований номер $i',
      'Flutter ${'длинноеслово' * 20}',
    ].join('\n');
    await _enter(tester, text);
    await _compare(tester);
    expect(find.byKey(const Key('vacancy.summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'light': StackCardTheme.light,
    'dark': StackCardTheme.dark,
  }.entries) {
    for (final width in [320.0, 390.0]) {
      testWidgets('Screen fits in ${entry.key} at $width', (tester) async {
        await _open(tester, theme: entry.value, width: width);
        await _enter(tester, 'Flutter, Dart, Firebase, Docker, Kubernetes');
        await _compare(tester);
        expect(find.byKey(const Key('vacancy.summary')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final scaffold = tester.element(find.byType(Scaffold).first);
        expect(
          Theme.of(scaffold).brightness,
          entry.key == 'dark' ? Brightness.dark : Brightness.light,
        );
      });
    }
  }
}
