import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/localization/mobile_parity_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_colors.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/core/theme/stackcard_tokens.dart';
import 'package:app_stackcard/features/media/media.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/projects/projects.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:app_stackcard/shared/widgets/stackcard_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Parity labels retain complete ru/en coverage', () {
    expect(
      russianMobileParityStrings.keys.toSet(),
      englishMobileParityStrings.keys.toSet(),
    );
    for (final locale in AppStrings.supportedLocales) {
      expect(
        AppStrings(locale).keys,
        containsAll(englishMobileParityStrings.keys),
      );
    }
  });

  testWidgets('Compact rows contain only text and a stock icon', (
    tester,
  ) async {
    await _pump(
      tester,
      child: const ProjectLibraryCard(
        title: 'Проект',
        description: 'Описание',
        iconId: 'camera',
      ),
    );
    expect(find.byType(PortfolioMediaImage), findsNothing);
    expect(find.textContaining('Обложка'), findsNothing);
    expect(find.text('Нет ссылки'), findsNothing);
    expect(find.text('Копировать'), findsNothing);
    expect(find.text('Dart'), findsNothing);
    expect(find.text('GitHub · source'), findsNothing);
    expect(
      tester.getSize(find.byType(ProjectLibraryCard)).height,
      lessThan(140),
    );
    final icon = tester.widget<StackCardIcon>(find.byType(StackCardIcon));
    expect(icon.name, 'camera');
  });

  testWidgets('Row actions are explicit and do not open the project', (
    tester,
  ) async {
    var edited = 0;
    var deleted = 0;
    var opened = 0;
    await _pump(
      tester,
      child: ProjectLibraryCard(
        title: 'Проект',
        description: '',
        onEdit: () => edited++,
        onDelete: () => deleted++,
        onOpen: () => opened++,
        openKey: const ValueKey('project.open'),
      ),
    );
    final remove = find.byTooltip('Удалить проект');
    final edit = find.byType(StackCardButton);
    final cardRect = tester.getRect(find.byType(ProjectLibraryCard));
    expect(
      tester.getRect(edit).left,
      closeTo(cardRect.left + StackCardSpacing.md, 1),
    );
    expect(
      tester.getRect(remove).right,
      closeTo(cardRect.right - StackCardSpacing.md, 1),
    );
    expect(
      tester.getRect(remove).top,
      closeTo(cardRect.top + StackCardSpacing.md, 1),
    );
    expect(
      tester.getRect(edit).right,
      closeTo(cardRect.right - StackCardSpacing.md, 1),
    );
    expect(
      tester.getRect(edit).top,
      greaterThan(tester.getRect(remove).bottom),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final colors = tester.element(edit).colors;
    expect(button.style!.side!.resolve({})!.color, colors.primaryOutline);
    expect(button.style!.backgroundColor!.resolve({}), colors.surface);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).color,
      colors.textPrimary,
    );
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Удалить'), findsNothing);
    await tester.tap(find.text('Редактировать'));
    await tester.tap(find.byTooltip('Удалить проект'));
    expect(edited, 1);
    expect(deleted, 1);
    expect(opened, 0);
    await tester.tap(find.byKey(const ValueKey('project.open')));
    expect(opened, 1);
    expect(find.text('Описание'), findsNothing);
  });

  testWidgets(
    'Icon picker exposes only the stable catalog and retains cancellation',
    (tester) async {
      String? selected;
      await _pump(
        tester,
        size: const Size(320, 640),
        scale: 2,
        child: Builder(
          builder: (context) => StackCardButton(
            label: 'Выбрать',
            onPressed: () async {
              selected = await showProjectIconPicker(
                context,
                selectedIconId: 'camera',
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Выбрать'));
      await tester.pumpAndSettle();
      for (final id in portfolioProjectIconIds) {
        expect(find.byKey(ValueKey('project.icon.$id')), findsOneWidget);
      }
      expect(find.textContaining('Загрузить'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('project.icon.home')),
      );
      await tester.tap(find.byKey(const ValueKey('project.icon.home')));
      await tester.pumpAndSettle();
      expect(selected, 'home');
      await tester.tap(find.text('Выбрать'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Иконка проекта'))).pop();
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in [const Locale('ru'), const Locale('en')]) {
    testWidgets('Compact actions and long text fit 320px scale2 $locale', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        scale: 2,
        locale: locale,
        child: ProjectLibraryCard(
          title: 'Очень длинное название проекта для проверки переносов',
          description: List.filled(20, 'Подробное описание проекта').join(' '),
          onEdit: () {},
          onDelete: () {},
        ),
      );
      for (final button in find.byType(StackCardButton).evaluate()) {
        expect(
          tester.getSize(find.byWidget(button.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(
        tester.getSize(find.byTooltip('Удалить проект')),
        const Size(48, 48),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  Size size = const Size(390, 844),
  double scale = 1,
  Locale locale = const Locale('ru'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: StackCardTheme.light,
      locale: locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
