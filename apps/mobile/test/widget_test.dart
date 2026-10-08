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
    await tester.ensureVisible(find.text('Открыть демо'));
    await tester.tap(find.text('Открыть демо'));
    await tester.pumpAndSettle();
    expect(find.text('Укажите корректный email'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'alex@example.dev');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Здесь появятся твои работы'), findsOneWidget);
    expect(find.text('Привет, Alex'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'Four root branches keep Settings origin and do not push tab history',
    (tester) async {
      await tester.pumpWidget(const StackCardApp(initialLocation: '/home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(StackCardPoster), findsNothing);
      for (final filter in [0, 1, 2]) {
        expect(find.byKey(ValueKey('home.filter.$filter')), findsOneWidget);
      }
      expect(find.textContaining('%'), findsNothing);
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      for (final item in [
        (index: 1, label: 'Резюме', path: '/resumes', title: 'Пока нет резюме'),
        (index: 2, label: 'Проекты', path: '/projects', title: 'Проекты: 4'),
        (
          index: 3,
          label: 'Портфолио',
          path: '/portfolio',
          title: 'Пока нет портфолио',
        ),
        (
          index: 0,
          label: 'Главная',
          path: '/home',
          title: 'Здесь появятся твои работы',
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
      await tester.ensureVisible(find.text('Вернуться ко входу'));
      await tester.tap(find.text('Вернуться ко входу'));
      await tester.pumpAndSettle();
      expect(find.text('Открыть демо'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Document libraries open the selected document in its standalone editor',
    (tester) async {
      final repository = MemoryPortfolioDraftRepository();
      final date = DateTime.utc(2026, 10, 7);
      final resume = PortfolioDocument(
        id: 'resume-a',
        title: 'Backend role',
        kind: PortfolioDocumentKind.resume,
        createdAt: date,
        updatedAt: date,
        content: PortfolioContent(
          profile: const PortfolioProfile(name: 'Resume name'),
        ),
      );
      final portfolio = PortfolioDocument(
        id: 'portfolio-a',
        title: 'Selected work',
        kind: PortfolioDocumentKind.portfolio,
        createdAt: date,
        updatedAt: date,
        content: PortfolioContent(
          profile: const PortfolioProfile(name: 'Portfolio name'),
        ),
      );
      await repository.save(
        PortfolioContent(
          profile: const PortfolioProfile(name: 'Shared name'),
          documents: [resume, portfolio],
        ),
        expectedRevision: 0,
        notes: 'Private notes',
      );
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/resumes',
          providerOverrides: [
            portfolioDraftRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );
      await tester.pumpAndSettle();
      for (final document in [resume, portfolio]) {
        if (document.kind == PortfolioDocumentKind.portfolio) {
          await tester.tap(_destination('Портфолио'));
          await tester.pumpAndSettle();
        }
        final card = find.byKey(ValueKey('document.open.${document.id}'));
        expect(card, findsOneWidget);
        final other = document.id == resume.id ? portfolio : resume;
        expect(find.byKey(ValueKey('document.open.${other.id}')), findsNothing);
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        final editor = tester.widget<PortfolioDocumentEditorScreen>(
          find.byType(PortfolioDocumentEditorScreen),
        );
        expect(editor.documentId, document.id);
        expect(editor.kind, document.kind);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.text(document.title), findsOneWidget);
        await tester.tap(find.byKey(const Key('document.section.profile')));
        await tester.pumpAndSettle();
        for (final field in [
          (name: 'title', value: document.title),
          (name: 'name', value: document.content.profile.name),
        ]) {
          final input = find.descendant(
            of: find.byKey(ValueKey('builder_form_${field.name}')),
            matching: find.byType(TextFormField),
          );
          expect(
            tester.widget<TextFormField>(input).controller!.text,
            field.value,
          );
        }
        await tester.tap(find.byKey(const Key('document.back')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('document.back')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('document.open.${document.id}')),
          findsOneWidget,
        );
        expect((await repository.read())!.revision, 1);
        expect((await repository.read())!.content!.profile.name, 'Shared name');
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Project search filters by technology, empty result can reset and details close',
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
      final preview = find.byKey(
        const ValueKey('project_preview_Atlas UI Kit'),
      );
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'Settings opens appearance and account routes with working back',
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
      await tester.tap(find.text('Светлая'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Внешний вид'))).brightness,
        Brightness.light,
      );
      await tester.tap(find.text('Тёмная'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Внешний вид'))).brightness,
        Brightness.dark,
      );
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
      expect(find.text('Здесь появятся твои работы'), findsOneWidget);
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
      expect(focused, isTrue, reason: 'Tab reaches the Projects destination');
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
}

Finder _destination(String label) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.widgetWithText(TextButton, label),
);
