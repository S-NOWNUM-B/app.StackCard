import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/core/diagnostics/app_diagnostics.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Настоящий native UI с synthetic memory fixture; SDK journey проверяется отдельно.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_HARDENING_UI_ACCEPTANCE');
  testWidgets(
    'three roots, dirty guard, unavailable publication and privacy settings',
    (tester) async {
      final repository = MemoryPortfolioDraftRepository();
      final time = DateTime.utc(2026, 10, 23);
      await repository.save(
        PortfolioContent(
          mainPortfolioId: 'main',
          projects: [
            PortfolioProject(
              id: 'library',
              title: 'Проект библиотеки',
              description: '',
              technologies: const [],
            ),
          ],
          documents: [
            PortfolioDocument(
              id: 'main',
              title: 'Основное портфолио',
              kind: PortfolioDocumentKind.portfolio,
              createdAt: time,
              updatedAt: time,
              content: PortfolioContent(
                profile: const PortfolioProfile(name: 'Сохранённый профиль'),
              ),
            ),
          ],
        ),
        expectedRevision: 0,
        notes: 'Synthetic private note',
      );
      var consent = false;
      final diagnostics = AppDiagnostics(
        sink: _FixtureSink(),
        readConsent: () async => consent,
        writeConsent: (value) async {
          consent = value;
        },
      );
      addTearDown(diagnostics.dispose);
      await diagnostics.initialize();
      await tester.pumpWidget(
        StackCardApp(
          initialLocation: '/home',
          providerOverrides: [
            portfolioDraftRepositoryProvider.overrideWithValue(repository),
            appDiagnosticsProvider.overrideWithValue(diagnostics),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .length,
        3,
      );
      expect(find.text('Сохранённый профиль'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(NavigationBar))).brightness,
        Brightness.light,
      );
      await _root(tester, 'Редактор');
      final name = find.descendant(
        of: find.byKey(const Key('main.editor.name')),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Несохранённый профиль');
      await tester.pumpAndSettle();
      await _root(tester, 'Главная');
      await _tap(tester, find.byKey(const Key('main.editor.leave.discard')));
      expect(find.text('Сохранённый профиль'), findsOneWidget);
      expect(
        mainPortfolioDocument((await repository.read())!.content!)!
            .content
            .profile
            .name,
        'Сохранённый профиль',
      );
      _passed('light_ru_three_roots_saved_home_dirty_discard');
      await _root(tester, 'Проекты');
      expect(find.text('Проект библиотеки'), findsOneWidget);
      await _root(tester, 'Главная');
      await _tap(tester, find.byKey(const Key('home.share')));
      await _tap(tester, find.text('Отправить ссылку'));
      expect(
        find.text(
          'Публикация недоступна: нужен аккаунт и настроенный сервер публикации.',
        ),
        findsOneWidget,
      );
      _passed('library_and_unavailable_publication_no_mock_success');
      await _tap(tester, find.byKey(const Key('app.settings')));
      await _tap(tester, find.byKey(const Key('settings.group.appearance')));
      final toggle = find.byKey(const Key('settings.diagnostics'));
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await _tap(tester, toggle);
      expect(consent, isTrue);
      await _tap(tester, toggle);
      expect(consent, isFalse);
      await _tap(tester, find.byTooltip('Назад'));
      await _tap(tester, find.byKey(const Key('settings.group.about')));
      expect(find.text('Приватность'), findsOneWidget);
      expect(find.textContaining('Гостевой черновик хранится'), findsOneWidget);
      expect(find.textContaining('Камера и галерея'), findsOneWidget);
      await tester.ensureVisible(find.text('Приватность'));
      await tester.pumpAndSettle();
      _passed('explicit_diagnostics_opt_in_out_and_privacy_help');
      expect(tester.takeException(), isNull);
    },
    skip: !enabled || !(Platform.isIOS || Platform.isAndroid),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _root(WidgetTester tester, String label) => _tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);
void _passed(String checkpoint) {
  // Только статический checkpoint, без содержимого и идентификаторов аккаунта.
  debugPrint(
    'STACKCARD_HARDENING_UI:${jsonEncode({'checkpoint': checkpoint})}',
  );
}

class _FixtureSink implements DiagnosticsSink {
  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
  @override
  Future<void> deleteUnsentReports() async {}
  @override
  Future<void> record(
    DiagnosticCode code,
    StackTrace stack, {
    required bool fatal,
  }) async {}
}
