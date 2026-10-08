import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<MemoryPortfolioDraftRepository> _seed() async {
  final repository = MemoryPortfolioDraftRepository();
  final now = DateTime.utc(2026, 10, 8);
  await repository.save(
    PortfolioContent(
      profile: const PortfolioProfile(name: 'Original', locationText: 'Almaty'),
      links: const [
        SocialLink(id: 'link', label: 'Website', url: 'https://example.com'),
      ],
      documents: [
        PortfolioDocument(
          id: 'document',
          title: 'Existing',
          kind: PortfolioDocumentKind.resume,
          createdAt: now,
          updatedAt: now,
          content: PortfolioContent(
            profile: const PortfolioProfile(name: 'Document'),
          ),
        ),
      ],
    ),
    expectedRevision: 0,
    notes: 'private notes',
  );
  return repository;
}

Future<void> _open(
  WidgetTester tester,
  PortfolioDraftRepository repository,
  String path,
) async {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const Text('Settings hub')),
      GoRoute(
        path: '/settings/profile',
        builder: (_, _) => const SettingsProfileScreen(),
      ),
      GoRoute(
        path: '/settings/contacts',
        builder: (_, _) => const SettingsContactsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, _) => const SettingsPrivacyScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: StackCardTheme.dark,
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
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'contact helper text stays readable at narrow width and doubled text',
    (tester) async {
      tester.view.physicalSize = const Size(640, 1440);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(tester, await _seed(), '/settings/contacts');
      const strings = AppStrings(Locale('ru'));
      for (final key in ['publicEmailHint', 'phoneHint']) {
        final hint = find.text(strings.tr('settingsManagement.$key'));
        await tester.ensureVisible(hint);
        await tester.pumpAndSettle();
        expect(
          tester.renderObject<RenderParagraph>(hint).didExceedMaxLines,
          isFalse,
          reason:
              '$key: ${tester.renderObject<RenderParagraph>(hint).toStringDeep()}',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'profile Save writes only base and preserves document snapshot and private notes',
    (tester) async {
      final repository = await _seed();
      await _open(tester, repository, '/settings/profile');
      await tester.enterText(
        find.byKey(const Key('settings.profile.name')),
        'Updated',
      );
      expect((await repository.read())!.content!.profile.name, 'Original');
      await _tap(tester, find.byKey(const Key('settings.save')));
      final draft = (await repository.read())!;
      expect(draft.content!.profile.name, 'Updated');
      expect(draft.content!.documents.single.content.profile.name, 'Document');
      expect(draft.notes, 'private notes');
      expect(find.text('Изменения сохранены на устройстве'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed scoped Save retains form input and explicit retry writes it',
    (tester) async {
      final source = await _seed();
      final repository = _FailOnceRepository(source);
      await _open(tester, repository, '/settings/profile');
      await tester.enterText(
        find.byKey(const Key('settings.profile.name')),
        'Retry name',
      );
      await _tap(tester, find.byKey(const Key('settings.save')));
      expect((await source.read())!.content!.profile.name, 'Original');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('settings.profile.name')),
            )
            .controller!
            .text,
        'Retry name',
      );
      expect(find.textContaining('Не удалось сохранить'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('settings.save')));
      expect((await source.read())!.content!.profile.name, 'Retry name');
    },
  );

  testWidgets(
    'Contacts Save does not persist unsaved neighboring Builder input',
    (tester) async {
      final repository = await _seed();
      await _open(tester, repository, '/settings/contacts');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsContactsScreen)),
      );
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      final working = container.read(portfolioDraftControllerProvider).content!;
      controller.updateContent(
        working.copyWith(
          profile: working.profile.copyWith(name: 'Neighbor unsaved'),
        ),
      );
      await _tap(tester, find.text('Разрешить выбор в документах'));
      await _tap(tester, find.byKey(const Key('settings.save')));
      expect((await repository.read())!.content!.profile.name, 'Original');
      expect(
        container.read(portfolioDraftControllerProvider).content!.profile.name,
        'Neighbor unsaved',
      );
      expect(
        (await repository.read())!.content!.links.single.publishAllowed,
        isTrue,
      );
    },
  );

  testWidgets(
    'profile Cancel asks before discarding and never persists the buffer',
    (tester) async {
      final repository = await _seed();
      await _open(tester, repository, '/settings/profile');
      await tester.enterText(
        find.byKey(const Key('settings.profile.name')),
        'Discard me',
      );
      await _tap(tester, find.text('Отмена').last);
      await _tap(tester, find.text('Отменить изменения').last);
      expect((await repository.read())!.content!.profile.name, 'Original');
      expect(find.text('Settings hub'), findsOneWidget);
    },
  );
  testWidgets(
    'contact permission Save and reopen keeps document contact snapshot separate',
    (tester) async {
      final repository = await _seed();
      await _open(tester, repository, '/settings/contacts');
      await _tap(tester, find.text('Разрешить выбор в документах'));
      await _tap(tester, find.byKey(const Key('settings.save')));
      expect(
        (await repository.read())!.content!.links.single.publishAllowed,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await _open(tester, repository, '/settings/contacts');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.ancestor(
                of: find.text('Разрешить выбор в документах'),
                matching: find.byType(CheckboxListTile),
              ),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'primary public email and phone save canonical values with separate consent',
    (tester) async {
      final repository = await _seed();
      await _open(tester, repository, '/settings/contacts');
      await tester.enterText(
        find.byKey(const Key('settings.contacts.email')),
        'public@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('settings.contacts.phone')),
        '+77001234567',
      );
      await _tap(tester, find.text('Разрешить выбор почты в документах'));
      await _tap(tester, find.byKey(const Key('settings.save')));
      final content = (await repository.read())!.content!;
      final email = content.links.singleWhere(
        (link) => link.kind == SocialLinkKind.email,
      );
      final phone = content.links.singleWhere(
        (link) => link.kind == SocialLinkKind.phone,
      );
      expect(email.url, 'mailto:public@example.com');
      expect(email.publishAllowed, isTrue);
      expect(phone.url, 'tel:+77001234567');
      expect(phone.publishAllowed, isFalse);
      expect(content.documents.single.content.links, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await _open(tester, repository, '/settings/contacts');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('settings.contacts.email')),
            )
            .controller!
            .text,
        'public@example.com',
      );
    },
  );
  testWidgets('reordering social links preserves primary contact positions', (
    tester,
  ) async {
    final repository = await _seed();
    final initial = (await repository.read())!;
    await repository.save(
      initial.content!.copyWith(
        links: const [
          SocialLink(
            id: 'email',
            label: 'Public email',
            url: 'mailto:public@example.com',
            kind: SocialLinkKind.email,
          ),
          SocialLink(
            id: 'first',
            label: 'First',
            url: 'https://first.example.com',
          ),
          SocialLink(
            id: 'phone',
            label: 'Phone',
            url: 'tel:+77001234567',
            kind: SocialLinkKind.phone,
          ),
          SocialLink(
            id: 'second',
            label: 'Second',
            url: 'https://second.example.com',
          ),
        ],
      ),
      expectedRevision: initial.revision,
      notes: initial.notes,
    );
    await _open(tester, repository, '/settings/contacts');
    await _tap(tester, find.byTooltip('Выше').last);
    await _tap(tester, find.byKey(const Key('settings.save')));
    expect((await repository.read())!.content!.links.map((link) => link.id), [
      'email',
      'second',
      'phone',
      'first',
    ]);
  });
  testWidgets(
    'contact form rejects script URL without adding or persisting it',
    (tester) async {
      final repository = await _seed();
      await _open(tester, repository, '/settings/contacts');
      await _tap(tester, find.byKey(const Key('settings.contacts.add')));
      final inputs = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(inputs.at(0), 'Unsafe');
      await tester.enterText(inputs.at(1), 'javascript:alert(1)');
      await _tap(tester, find.text('Сохранить').last);
      expect(
        find.text('Проверьте адрес для выбранного типа контакта'),
        findsOneWidget,
      );
      expect((await repository.read())!.content!.links, hasLength(1));
    },
  );
  testWidgets(
    'privacy location consent persists independently from existing documents',
    (tester) async {
      final repository = await _seed();
      await _open(tester, repository, '/settings/privacy');
      await _tap(tester, find.text('Показывать местоположение'));
      await _tap(tester, find.byKey(const Key('settings.save')));
      final content = (await repository.read())!.content!;
      expect(content.profile.publishLocation, isTrue);
      expect(content.documents.single.content.profile.publishLocation, isFalse);
      final requests = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .last;
      expect(requests.onChanged, isNull);
      expect(requests.value, isFalse);
    },
  );
}

class _FailOnceRepository implements PortfolioDraftRepository {
  _FailOnceRepository(this.source);
  final PortfolioDraftRepository source;
  bool fail = true;
  @override
  Future<PortfolioDraft?> read() => source.read();
  @override
  Future<PortfolioDraft> saveNotes(String notes) => source.saveNotes(notes);
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
    return source.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }
}
