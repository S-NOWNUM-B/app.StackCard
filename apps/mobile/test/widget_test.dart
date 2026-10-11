import 'package:app_stackcard/features/home/home_screen.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/settings/settings_screen.dart';
import 'package:app_stackcard/main.dart';
import 'package:app_stackcard/shared/widgets/stackcard_poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  testWidgets('Demo entry validates email and opens navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const StackCardApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.ensureVisible(find.text('Продолжить'));
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Укажите корректную электронную почту'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'alex@example.dev');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Портфолио пока пустое'), findsOneWidget);
    expect(find.text('Привет, Alex'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'Three root branches keep Settings origin and do not push tab history',
    (tester) async {
      await tester.pumpWidget(const StackCardApp(initialLocation: '/home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(StackCardPoster), findsNothing);
      for (final filter in [0, 1, 2]) {
        expect(find.byKey(ValueKey('home.filter.$filter')), findsNothing);
      }
      expect(find.textContaining('%'), findsNothing);
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      for (final item in [
        (index: 1, label: 'Проекты', path: '/projects', title: 'Проекты: 4'),
        (index: 2, label: 'Редактор', path: '/editor', title: 'Профиль'),
        (
          index: 0,
          label: 'Главная',
          path: '/home',
          title: 'Портфолио пока пустое',
        ),
      ]) {
        await tester.tap(_destination(item.label));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, item.path);
        expect(
          item.path == '/projects'
              ? find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.label == item.title,
                )
              : find.text(item.title),
          findsOneWidget,
        );
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          item.index,
        );
        expect(
          router.canPop(),
          isFalse,
          reason: 'Switching a root branch must not push another root',
        );
        await tester.tap(find.byKey(const Key('app.settings')));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, item.path);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          item.index,
        );
      }
      await tester.tap(find.byKey(const Key('app.settings')));
      await tester.pumpAndSettle();
      final signIn = find.byKey(const Key('account.sessionAction'));
      await tester.ensureVisible(signIn);
      await tester.tap(signIn);
      await tester.pumpAndSettle();
      expect(find.text('Продолжить'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saved Home and main Editor read the selected document without changing Library or private notes',
    (tester) async {
      final repository = MemoryPortfolioDraftRepository();
      final date = DateTime.utc(2026, 10, 7);
      final archived = PortfolioDocument(
        id: 'resume-a',
        title: 'Archived resume',
        kind: PortfolioDocumentKind.resume,
        createdAt: date,
        updatedAt: date,
        content: PortfolioContent(
          profile: const PortfolioProfile(name: 'Archived name'),
        ),
      );
      final main = PortfolioDocument(
        id: 'portfolio-a',
        title: 'Selected work',
        kind: PortfolioDocumentKind.portfolio,
        createdAt: date,
        updatedAt: date,
        content: PortfolioContent(
          profile: const PortfolioProfile(name: 'Selected name'),
        ),
      );
      final library = [
        PortfolioProject(
          id: 'library-a',
          title: 'Library survives',
          description: '',
          technologies: const [],
        ),
      ];
      await repository.save(
        PortfolioContent(
          profile: const PortfolioProfile(name: 'Legacy shared name'),
          projects: library,
          documents: [archived, main],
          mainPortfolioId: main.id,
        ),
        expectedRevision: 0,
        notes: 'Private notes',
      );
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/home',
          providerOverrides: [
            portfolioDraftRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Selected name'), findsOneWidget);
      expect(find.text('Archived name'), findsNothing);
      expect(find.text('Legacy shared name'), findsNothing);
      expect(find.text('Private notes'), findsNothing);
      expect(find.byKey(ValueKey('document.open.${main.id}')), findsNothing);
      await tester.tap(_destination('Редактор'));
      await tester.pumpAndSettle();
      expect(find.byType(MainPortfolioEditorScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      final input = find.descendant(
        of: find.byKey(const Key('main.editor.name')),
        matching: find.byType(TextFormField),
      );
      expect(
        tester.widget<TextFormField>(input).controller!.text,
        'Selected name',
      );
      await tester.tap(_destination('Главная'));
      await tester.pumpAndSettle();
      expect(find.text('Selected name'), findsOneWidget);
      final restored = (await repository.read())!;
      expect(restored.revision, 1);
      expect(restored.notes, 'Private notes');
      expect(restored.content!.profile.name, 'Legacy shared name');
      expect(restored.content!.projects, library);
      expect(restored.content!.documents, [archived, main]);
      expect(restored.content!.mainPortfolioId, main.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Project search filters by technology and resets without creating tab history',
    (tester) async {
      await tester.pumpWidget(const StackCardApp(initialLocation: '/projects'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'React');
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Проекты: 1',
        ),
        findsOneWidget,
      );
      expect(find.text('Readme Studio'), findsOneWidget);
      expect(find.text('Atlas UI Kit'), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'no-such-project');
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await tester.ensureVisible(find.text('Очистить поиск'));
      await tester.tap(find.text('Очистить поиск'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Проекты: 4',
        ),
        findsOneWidget,
      );
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      expect(router.routeInformationProvider.value.uri.path, '/projects');
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Settings opens application, GitHub and account routes with working back',
    (tester) async {
      await tester.pumpWidget(const StackCardApp(initialLocation: '/settings'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      final router = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .routerConfig;
      final appearance = find.byKey(const Key('settings.group.appearance'));
      await tester.ensureVisible(appearance);
      await tester.tap(appearance);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsAppearanceScreen), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Приложение'))).brightness,
        Brightness.light,
      );
      expect(find.text('Тёмная'), findsNothing);
      expect(find.text('Системная'), findsNothing);
      expect(find.text('English'), findsNothing);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router),
      );
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      final github = find.byKey(const Key('settings.group.github'));
      await tester.ensureVisible(github);
      await tester.tap(github);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsGitHubScreen), findsOneWidget);
      expect(find.byKey(const Key('settings.github.username')), findsOneWidget);
      expect(find.byKey(const Key('settings.github.save')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router),
      );
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      final account = find.byKey(const Key('settings.group.account'));
      await tester.ensureVisible(account);
      await tester.tap(account);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsAccountScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Keyboard reaches form, submits and activates a navigation control',
    (tester) async {
      await tester.pumpWidget(const StackCardApp());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Портфолио пока пустое'), findsOneWidget);
      expect(find.text('Привет, Alex'), findsNothing);
      final destination = _destination('Проекты');
      var focused = false;
      for (var i = 0; i < 24 && !focused; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        focused = identical(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TextButton>(),
          tester.widget<TextButton>(destination),
        );
      }
      expect(
        focused,
        isTrue,
        reason:
            'Tab reaches the Projects destination\n${debugDescribeFocusTree()}',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Проекты: 4',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Keyboard exits populated Home and reverses through shell controls',
    (tester) async {
      final repository = MemoryPortfolioDraftRepository();
      final date = DateTime.utc(2026, 10, 12);
      await repository.save(
        PortfolioContent(
          mainPortfolioId: 'main',
          documents: [
            PortfolioDocument(
              id: 'main',
              title: 'Портфолио',
              kind: PortfolioDocumentKind.portfolio,
              createdAt: date,
              updatedAt: date,
              content: PortfolioContent(
                profile: const PortfolioProfile(name: 'Сохранённый профиль'),
              ),
            ),
          ],
        ),
        expectedRevision: 0,
        notes: 'Приватные заметки',
      );
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/home',
          providerOverrides: [
            portfolioDraftRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final projects = tester.widget<TextButton>(_destination('Проекты'));
      var focused = false;
      for (var index = 0; index < 24 && !focused; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        focused = identical(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TextButton>(),
          projects,
        );
      }
      expect(focused, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TextButton>(),
        same(tester.widget<TextButton>(_destination('Главная'))),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _destination(String label) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.widgetWithText(TextButton, label),
);
