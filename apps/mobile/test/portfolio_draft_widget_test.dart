import 'dart:async';

import 'package:app_stackcard/core/state/app_settings.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
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
    'Notes save on device and remain available in a new app session',
    (tester) async {
      final repository = MemoryPortfolioDraftRepository(
        clock: () => DateTime.utc(2026, 10, 3),
      );
      await _open(tester, repository);
      expect(find.text('Заметки ещё не сохранены'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);
      await tester.enterText(
        _notes,
        'Описание моего будущего портфолио\nВторая строка',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Есть несохранённые изменения'));
      expect(find.text('Есть несохранённые изменения'), findsOneWidget);
      await _save(tester);
      expect(find.text('Заметки сохранены на устройстве'), findsOneWidget);
      expect(find.text('Последняя сохранённая версия: 1'), findsOneWidget);
      expect(
        find.text(
          'Ожидает синхронизации. Облачная синхронизация пока не подключена.',
        ),
        findsOneWidget,
      );
      expect(_saveButton(tester).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, repository);
      final input = tester.widget<TextFormField>(
        find.descendant(of: _notes, matching: find.byType(TextFormField)),
      );
      expect(
        input.controller!.text,
        'Описание моего будущего портфолио\nВторая строка',
      );
      expect(find.text('Заметки сохранены на устройстве'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unsaved input survives leaving and reopening the route', (
    tester,
  ) async {
    final repository = MemoryPortfolioDraftRepository();
    await _open(tester, repository);
    await tester.enterText(_notes, 'Unwritten navigation note');
    await tester.pump();
    final router = GoRouter.of(tester.element(_notes));
    router.go('/portfolio');
    await tester.pumpAndSettle();
    expect(_notes, findsNothing);
    router.go('/portfolio-draft');
    await tester.pumpAndSettle();
    final input = tester.widget<TextFormField>(
      find.descendant(of: _notes, matching: find.byType(TextFormField)),
    );
    expect(input.controller!.text, 'Unwritten navigation note');
    expect(find.text('Есть несохранённые изменения'), findsOneWidget);
    expect(await repository.read(), isNull);
  });

  testWidgets('Pending write never announces successful persistence', (
    tester,
  ) async {
    final pending = Completer<PortfolioDraft>();
    await _open(tester, _Source(save: (_) => pending.future));
    await tester.enterText(_notes, 'Pending note');
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('portfolio_draft_save')),
    );
    await tester.tap(find.byKey(const ValueKey('portfolio_draft_save')));
    await tester.pump();
    await tester.ensureVisible(find.text('Сохраняем заметки…'));
    expect(find.text('Сохраняем заметки…'), findsOneWidget);
    expect(find.text('Заметки сохранены на устройстве'), findsNothing);
    pending.complete(_draft('Pending note'));
    await tester.pumpAndSettle();
    expect(find.text('Заметки сохранены на устройстве'), findsOneWidget);
  });

  testWidgets(
    'Save error retains user input and explicit save retries successfully',
    (tester) async {
      var writes = 0;
      final source = _Source(
        save: (notes) async {
          if (++writes == 1) {
            throw StateError('/private/internal-storage-detail');
          }
          return _draft(notes);
        },
      );
      await _open(tester, source);
      await tester.enterText(_notes, 'Keep this input');
      await tester.pump();
      await _save(tester);
      expect(find.text('Заметки не сохранены'), findsOneWidget);
      expect(find.text('Заметки сохранены на устройстве'), findsNothing);
      expect(find.textContaining('/private/'), findsNothing);
      final input = tester.widget<TextFormField>(
        find.descendant(of: _notes, matching: find.byType(TextFormField)),
      );
      expect(input.controller!.text, 'Keep this input');
      expect(writes, 1);
      await _save(tester);
      expect(find.text('Заметки сохранены на устройстве'), findsOneWidget);
      expect(writes, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Initial storage error disables unsafe editing and retries reading',
    (tester) async {
      var reads = 0;
      await _open(
        tester,
        _Source(
          read: () async {
            if (++reads == 1) {
              throw const PortfolioDraftFailure(
                PortfolioDraftFailureKind.unavailable,
              );
            }
            return _draft('Recovered note');
          },
        ),
      );
      expect(find.text('Не удалось открыть черновик'), findsOneWidget);
      final input = tester.widget<TextFormField>(
        find.descendant(of: _notes, matching: find.byType(TextFormField)),
      );
      expect(input.enabled, isFalse);
      await tester.ensureVisible(find.text('Повторить чтение'));
      await tester.tap(find.text('Повторить чтение'));
      await tester.pumpAndSettle();
      expect(find.text('Recovered note'), findsOneWidget);
      expect(reads, 2);
    },
  );

  for (final kind in [
    PortfolioDraftFailureKind.corrupted,
    PortfolioDraftFailureKind.unsupportedVersion,
  ]) {
    testWidgets(
      '$kind explains preserved record and never offers overwriting',
      (tester) async {
        await _open(
          tester,
          _Source(read: () async => throw PortfolioDraftFailure(kind)),
        );
        expect(
          find.textContaining(
            'Исходная запись сохранена; перезапись заблокирована.',
          ),
          findsOneWidget,
        );
        expect(_saveButton(tester).onPressed, isNull);
        expect(find.text('Заметки сохранены на устройстве'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('English locale translates form, statuses and typed failures', (
    tester,
  ) async {
    await _open(
      tester,
      _Source(
        save: (_) async => throw const PortfolioDraftFailure(
          PortfolioDraftFailureKind.unavailable,
        ),
      ),
      language: AppLanguage.en,
    );
    expect(find.text('Local draft'), findsOneWidget);
    expect(find.text('Portfolio notes'), findsOneWidget);
    expect(find.text('Save on device'), findsOneWidget);
    await tester.enterText(_notes, 'English note');
    await tester.pump();
    await tester.ensureVisible(find.text('You have unsaved changes'));
    expect(find.text('You have unsaved changes'), findsOneWidget);
    await _save(tester);
    expect(find.text('Notes were not saved'), findsOneWidget);
    expect(
      find.text('Local storage is unavailable. Try again later.'),
      findsOneWidget,
    );
    expect(find.text('Заметки'), findsNothing);
  });

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    for (final viewport in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(768, 1024),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Draft saved ${theme.name} $viewport text $scale', (
          tester,
        ) async {
          tester.view.physicalSize = viewport;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _open(
            tester,
            _Source(
              read: () async =>
                  _draft('Длинные заметки к портфолио\nВторая строка'),
            ),
            theme: theme,
          );
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            final semantics = tester.ensureSemantics();
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            semantics.dispose();
          }
        });
      }
    }
  }
}

final _notes = find.byKey(const ValueKey('portfolio_draft_notes'));

Future<void> _open(
  WidgetTester tester,
  PortfolioDraftRepository repository, {
  AppTheme theme = AppTheme.dark,
  AppLanguage language = AppLanguage.ru,
}) async {
  await tester.pumpWidget(
    StackCardApp(
      initialLocation: '/portfolio-draft',
      initialSettings: AppSettings(theme: theme, language: language),
      providerOverrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

FilledButton _saveButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(
    of: find.byKey(const ValueKey('portfolio_draft_save')),
    matching: find.byType(FilledButton),
  ),
);

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('portfolio_draft_save')),
  );
  await tester.tap(find.byKey(const ValueKey('portfolio_draft_save')));
  await tester.pumpAndSettle();
}

PortfolioDraft _draft(String notes) => PortfolioDraft(
  notes: notes,
  revision: 1,
  updatedAt: DateTime.utc(2026, 10, 3),
  pendingSync: true,
);

class _Source implements PortfolioDraftRepository {
  _Source({
    Future<PortfolioDraft?> Function()? read,
    Future<PortfolioDraft> Function(String)? save,
  }) : readNotes = read,
       saveNotesCallback = save;
  final Future<PortfolioDraft?> Function()? readNotes;
  final Future<PortfolioDraft> Function(String)? saveNotesCallback;

  @override
  Future<PortfolioDraft?> read() async =>
      readNotes == null ? null : await readNotes!();

  @override
  Future<PortfolioDraft> saveNotes(String notes) async =>
      saveNotesCallback == null
      ? _draft(notes)
      : await saveNotesCallback!(notes);
}
