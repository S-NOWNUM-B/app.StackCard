import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_stackcard/core/storage/local_storage.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/main.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Настоящие формы StackCardApp, named demo Auth SDK и отдельный Hive.
/// GitHub здесь — явно обозначенная fixture; сеть проверяется другим journey.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_MAIN_PORTFOLIO_ACCEPTANCE');
  const run = String.fromEnvironment('MAIN_PORTFOLIO_RUN_ID');
  const host = String.fromEnvironment(
    'MAIN_PORTFOLIO_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  const holdSeconds = int.fromEnvironment('MAIN_PORTFOLIO_TOUCH_HOLD_SECONDS');

  testWidgets(
    'native touch registration, optional onboarding, Library and saved Home',
    (tester) async {
      expect(run, matches(r'^[0-9a-f]{32}$'));
      expect(host, anyOf('10.0.2.2', '127.0.0.1', 'localhost'));
      expect(holdSeconds, inInclusiveRange(0, 60));
      final app = await Firebase.initializeApp(
        name: 'main-touch-$run',
        options: const FirebaseOptions(
          apiKey: 'emulator-only-key',
          appId: '1:123456789:android:0123456789abcdef',
          messagingSenderId: '123456789',
          projectId: 'demo-stackcard-test',
        ),
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      await auth.useAuthEmulator(host, 9099);
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/main-touch-$run');
      LocalStorage? storage;
      var ownsDirectory = false;
      String? ownedUid;
      final source = _FixtureGitHubSource();

      void passed(String checkpoint) => debugPrint(
        'STACKCARD_MAIN_TOUCH:${jsonEncode({'pid': pid, 'checkpoint': checkpoint})}',
      );

      Future<void> mount({String location = '/sign-in'}) async {
        final accounts = LocalDraftAccounts(storage!.portfolioDraft);
        final repositories = <String?, PortfolioDraftRepository>{};
        await tester.pumpWidget(
          StackCardApp(
            initialLocation: location,
            providerOverrides: [
              accountAuthRepositoryProvider.overrideWithValue(
                FirebaseAccountAuthRepository(auth: auth),
              ),
              portfolioDraftRepositoryFactoryProvider.overrideWithValue(
                (uid) => repositories.putIfAbsent(
                  uid,
                  () => uid == null
                      ? accounts.guestRepository
                      : accounts.repositoryForUser(uid),
                ),
              ),
              githubImportRepositoryProvider.overrideWithValue(source),
            ],
          ),
        );
      }

      Future<PortfolioDraft> saved() async =>
          (await LocalDraftAccounts(storage!.portfolioDraft)
              .repositoryForUser(auth.currentUser!.uid)
              .read())!;

      try {
        expect(auth.currentUser, isNull);
        expect(await directory.exists(), isFalse);
        ownsDirectory = true;
        storage = await LocalStorage.open(directory: directory);
        await mount();
        await _until(
          tester,
          () =>
              _key('account.submit').hitTestable().evaluate().isNotEmpty &&
              tester
                      .widget<StackCardButton>(_key('account.submit'))
                      .onPressed !=
                  null,
        );
        debugPrint('TOUCH_READY_SIGN_IN');
        await _tap(tester, find.text('Создать аккаунт'));
        await _until(
          tester,
          () => _key('account.confirmPassword').evaluate().isNotEmpty,
        );
        final password = 'Aa!${_randomHex(24)}';
        await _enter(tester, 'account.email', 'touch.$run@example.invalid');
        await _enter(tester, 'account.password', password);
        await _enter(tester, 'account.confirmPassword', password);
        await _tap(tester, _key('account.submit'));
        await _until(
          tester,
          () => _key('personalization.github').evaluate().isNotEmpty,
        );
        expect(auth.currentUser?.email, 'touch.$run@example.invalid');
        ownedUid = auth.currentUser!.uid;
        passed('touch_register_real_named_demo_auth');

        await _enter(
          tester,
          'personalization.github',
          'https://github.com/octocat',
        );
        await _tap(tester, _key('personalization.next'));
        await _until(
          tester,
          () => _key('personalization.name').evaluate().isNotEmpty,
        );
        await _enter(tester, 'personalization.name', 'Native Touch Author');
        // Должность и город остаются пустыми: это необязательные поля.
        await _tap(tester, _key('personalization.next'));
        await _until(
          tester,
          () => _key('personalization.bio').evaluate().isNotEmpty,
        );
        await _tap(tester, _key('personalization.next'));
        await _until(
          tester,
          () => find.text('Фотография').evaluate().isNotEmpty,
        );
        await _tap(tester, _key('personalization.next'));
        await _until(
          tester,
          () => _key('home.savedPortfolio').evaluate().isNotEmpty,
        );
        var durable = await saved();
        expect(
          durable.content!.personalization.status,
          PortfolioPersonalizationStatus.completed,
        );
        expect(durable.content!.githubUsername, 'octocat');
        final profile = mainPortfolioDocument(durable.content!)!
            .content
            .profile;
        expect(profile.name, 'Native Touch Author');
        expect(profile.headline, isEmpty);
        expect(profile.bio, isEmpty);
        expect(profile.locationText, isEmpty);
        expect(profile.avatarPath, isEmpty);
        passed('touch_optional_four_steps_saved');

        await _navigate(tester, 'Проекты');
        await _tap(tester, find.text('Создать'));
        await _until(
          tester,
          () => _key('builder_form_title').evaluate().isNotEmpty,
        );
        await _enter(tester, 'builder_form_title', 'Native manual project');
        await _enter(
          tester,
          'builder_form_description',
          'Created through the native project form',
        );
        await _tap(tester, _key('builder_form_apply'));
        await _until(
          tester,
          () => _key('project_search').evaluate().isNotEmpty,
        );
        durable = await saved();
        final manual = durable.content!.projects.single;
        expect(manual.title, 'Native manual project');
        expect(manual.githubRepositoryId, isNull);
        expect(mainPortfolioDocument(durable.content!)!.projects, isEmpty);
        passed('touch_manual_project_scoped_save');

        await _tap(tester, find.text('Импортировать'));
        await _until(
          tester,
          () => _key('github_repository_42').evaluate().isNotEmpty,
        );
        await _tap(tester, _key('github_repository_42'));
        await _tap(tester, _key('github_import_selected'));
        await _until(
          tester,
          () =>
              find.text('Проекты сохранены в библиотеке').evaluate().isNotEmpty,
        );
        durable = await saved();
        expect(durable.content!.projects, hasLength(2));
        expect(
          durable.content!.projects
              .where((p) => p.githubRepositoryId == 42)
              .single
              .title,
          'Native fixture repository',
        );
        expect(source.profileReads, 1);
        expect(source.pageReads, 1);
        expect(mainPortfolioDocument(durable.content!)!.projects, isEmpty);
        passed('touch_import_fixture_source_real_selection_scoped_save');
        await _tap(tester, find.byTooltip('Назад к проектам'));

        await _navigate(tester, 'Редактор');
        await _until(
          tester,
          () => _key('main.editor.headline').evaluate().isNotEmpty,
        );
        await _enter(
          tester,
          'main.editor.headline',
          'Saved from native Editor',
        );
        await _tap(
          tester,
          _key('main.editor.addProject'),
          scrollable: _inside('main.editor.scroll'),
        );
        for (final project in durable.content!.projects) {
          await _tap(tester, _key('main.projectSelection.${project.id}'));
        }
        await _tap(tester, _key('main.projectSelection.apply'));
        // Выбор и ввод остаются buffer до явного Save.
        expect(
          mainPortfolioDocument((await saved()).content!)!.projects,
          isEmpty,
        );
        expect(
          mainPortfolioDocument((await saved()).content!)!
              .content
              .profile
              .headline,
          isEmpty,
        );
        await _tap(
          tester,
          _key('main.editor.save'),
          scrollable: _inside('main.editor.scroll'),
        );
        final saveDeadline = DateTime.now().add(const Duration(seconds: 30));
        while (true) {
          final snapshot = await saved();
          final document = mainPortfolioDocument(snapshot.content!)!;
          if (document.projects.length == 2 &&
              document.content.profile.headline == 'Saved from native Editor') {
            break;
          }
          if (DateTime.now().isAfter(saveDeadline)) {
            fail(
              'Native Editor Save did not persist: ${document.projects.length} attachments, headline=${document.content.profile.headline}, errors=${_key('main.editor.error').evaluate().length}',
            );
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        durable = await saved();
        final main = mainPortfolioDocument(durable.content!)!;
        expect(
          main.projects.map((p) => p.projectId).toSet(),
          durable.content!.projects.map((p) => p.id).toSet(),
        );
        expect(main.content.profile.headline, 'Saved from native Editor');
        expect(durable.notes, isEmpty);
        passed('touch_attachment_and_explicit_editor_save');

        await _navigate(tester, 'Главная');
        await _assertHome(tester);
        await storage.portfolioDraft.flush();
        passed('touch_saved_home_contains_both_projects');
        for (var second = 0; second < holdSeconds; second++) {
          await tester.pump(const Duration(seconds: 1));
        }

        // Реальный close/reopen Hive и повторный запуск UI, без process-restart claim.
        final beforeReopen = durable.content;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await storage.close();
        storage = await LocalStorage.open(directory: directory);
        expect((await saved()).content, beforeReopen);
        expect(
          await LocalDraftAccounts(storage.portfolioDraft).guestRepository
              .read(),
          isNull,
        );
        expect(
          await LocalDraftAccounts(storage.portfolioDraft)
              .repositoryForUser('different-owner')
              .read(),
          isNull,
        );
        await mount(location: '/home');
        await _until(
          tester,
          () => _key('home.savedPortfolio').evaluate().isNotEmpty,
        );
        await _assertHome(tester);
        expect(_key('personalization.step'), findsNothing);
        expect(tester.takeException(), isNull);
        passed('touch_hive_reopen_home_onboarding_not_repeated_uid_isolation');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await storage?.close();
        if (ownedUid != null && auth.currentUser?.uid == ownedUid) {
          await auth.currentUser!.delete();
        }
        await app.delete();
        if (ownsDirectory && await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
    skip: !enabled || !(Platform.isAndroid || Platform.isIOS),
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

Finder _key(String key) => find.byKey(ValueKey(key));

Finder _inside(String key) =>
    find.descendant(of: _key(key), matching: find.byType(Scrollable)).first;

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Native touch UI state deadline');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
}) async {
  if (target.hitTestable().evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: scrollable ?? find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
}) async {
  await tester.pumpAndSettle();
  await _reveal(tester, target, scrollable: scrollable);
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final target = _key(key);
  await _reveal(tester, target);
  await tester.enterText(target, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
}

Future<void> _navigate(WidgetTester tester, String label) => _tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

Future<void> _assertHome(WidgetTester tester) async {
  expect(_key('home.savedPortfolio'), findsOneWidget);
  expect(find.text('Native Touch Author'), findsOneWidget);
  expect(find.text('Saved from native Editor'), findsOneWidget);
  for (final title in ['Native manual project', 'Native fixture repository']) {
    final target = find.text(title);
    await _reveal(tester, target, scrollable: _inside('home.savedPortfolio'));
    expect(target.hitTestable(), findsOneWidget);
  }
}

String _randomHex(int bytes) {
  final random = Random.secure();
  return List.generate(
    bytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

final class _FixtureGitHubSource implements GitHubImportRepository {
  var profileReads = 0;
  var pageReads = 0;

  @override
  Future<GitHubProfile> getProfile(String username) async {
    profileReads++;
    return GitHubProfile(
      id: 1,
      login: username,
      htmlUrl: 'https://github.com/$username',
      publicRepositories: 1,
    );
  }

  @override
  Future<GitHubRepositoriesPage> getRepositories(
    GitHubProfile profile, {
    Uri? page,
  }) async {
    pageReads++;
    return GitHubRepositoriesPage(
      repositories: [
        GitHubRepository(
          id: 42,
          name: 'Native fixture repository',
          fullName: '${profile.login}/native-fixture',
          htmlUrl: 'https://github.com/${profile.login}/native-fixture',
          stars: 0,
          forks: 0,
          isFork: false,
          archived: false,
          updatedAt: DateTime.utc(2026, 10, 21),
          language: 'Dart',
        ),
      ],
      readMetadata: GitHubReadMetadata(validatedAt: DateTime.utc(2026, 10, 21)),
    );
  }

  @override
  void cancelRequests() {}
}
