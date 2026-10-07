import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_document_base_review_screen.dart';
import 'package:app_stackcard/features/media/media.dart';
import 'package:app_stackcard/shared/widgets/stackcard_avatar.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _repositoryProvider =
    NotifierProvider<_RepositorySelection, PortfolioDraftRepository>(
      _RepositorySelection.new,
    );

class _RepositorySelection extends Notifier<PortfolioDraftRepository> {
  @override
  PortfolioDraftRepository build() => _Repository();
  void select(PortfolioDraftRepository repository) => state = repository;
}

void main() {
  test('Review and editor action translations have ru/en key parity', () {
    final russian = AppStrings(const Locale('ru'));
    final english = AppStrings(const Locale('en'));
    final keys = russian.keys.where((key) => key.startsWith('baseReview.'));
    expect(keys, isNotEmpty);
    expect(
      keys.toSet(),
      english.keys.where((key) => key.startsWith('baseReview.')).toSet(),
    );
    for (final key in [
      ...keys,
      'documentEditor.baseReview',
      'documentEditor.baseReviewStale',
    ]) {
      expect(russian.tr(key), isNotEmpty);
      expect(english.tr(key), isNotEmpty);
    }
  });

  testWidgets(
    'Inherited changes are selected and local overrides require explicit choice',
    (tester) async {
      final harness = await _open(tester, review: _profileReview());
      expect(_selected(tester, 'bio:'), isTrue);
      expect(_selected(tester, 'headline:'), isFalse);
      expect(find.text('Есть локальная правка'), findsOneWidget);
      expect(find.text('Local role'), findsOneWidget);
      expect(find.text('New base role'), findsOneWidget);
      expect(
        tester.getSize(_row('headline:')).height,
        greaterThanOrEqualTo(56),
      );
      expect(
        find.text('Изменения попадут в редактор. Сохраните документ отдельно.'),
        findsOneWidget,
      );
      expect(harness.repository.saves, 0);
      expect(harness.result, isNull);
    },
  );

  testWidgets('Apply returns only explicitly chosen changes without saving', (
    tester,
  ) async {
    final review = _profileReview();
    final harness = await _open(tester, review: review);
    await _tap(tester, _row('headline:'));
    await _tap(tester, _row('bio:'));
    await _tap(tester, find.byKey(const ValueKey('base-review-apply')));
    expect(harness.result!.content.profile.headline, 'New base role');
    expect(harness.result!.content.profile.bio, 'Previous bio');
    expect(harness.result!.baseSnapshot, review.base);
    expect(review.document.content.profile.headline, 'Local role');
    expect(harness.repository.saves, 0);
    expect(find.text('Return'), findsOneWidget);
  });

  testWidgets('Keyboard Space toggles the focused, field-labelled selection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _open(tester, review: _profileReview());
      expect(
        tester.getSemantics(_row('headline:')).label,
        contains('Профессиональная роль'),
      );
      var focused = false;
      for (var step = 0; step < 12 && !focused; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final element = FocusManager.instance.primaryFocus?.context;
        if (element is Element) {
          element.visitAncestorElements((ancestor) {
            if (ancestor.widget.key ==
                const ValueKey('base-review-headline:')) {
              focused = true;
              return false;
            }
            return true;
          });
        }
      }
      expect(focused, isTrue);
      expect(_selected(tester, 'headline:'), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_selected(tester, 'headline:'), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final action in ['cancel', 'back']) {
    testWidgets('$action returns no document and performs no save', (
      tester,
    ) async {
      final harness = await _open(tester, review: _profileReview());
      await _tap(tester, _row('headline:'));
      await _tap(tester, find.byKey(ValueKey('base-review-$action')));
      expect(harness.result, isNull);
      expect(harness.returned, isTrue);
      expect(harness.repository.saves, 0);
    });
  }

  testWidgets(
    'Legacy review explains missing baseline and unchecked Apply preserves local data',
    (tester) async {
      final review = _profileReview(legacy: true);
      final harness = await _open(tester, review: review);
      expect(
        find.byKey(const ValueKey('base-review-no-baseline')),
        findsOneWidget,
      );
      for (final change in review.changes) {
        expect(_selected(tester, change.key), isFalse);
      }
      await _tap(tester, find.byKey(const ValueKey('base-review-apply')));
      expect(harness.result!.content, review.document.content);
      expect(harness.result!.baseSnapshot, review.base);
      expect(harness.repository.saves, 0);
    },
  );

  testWidgets(
    'Structured changes show readable records, empty values and deleted items',
    (tester) async {
      final previous = PortfolioContent(
        profile: const PortfolioProfile(name: 'Before', locationText: 'Almaty'),
        skills: const [Skill(id: 'removed', name: 'Old skill')],
      );
      final incoming = previous.copyWith(
        profile: previous.profile.copyWith(locationText: ''),
        skills: const [Skill(id: 'new', name: 'Dart')],
        experience: const [
          Experience(
            id: 'job',
            role: 'Engineer',
            organization: 'Team',
            period: '2025–2026',
            description: 'Built an app',
          ),
        ],
        education: const [
          Education(
            id: 'school',
            institution: 'University',
            qualification: 'Software Engineering',
            period: '2024–2027',
            description: 'Degree details',
          ),
        ],
        links: const [
          SocialLink(
            id: 'website',
            label: 'Portfolio',
            url: 'https://example.com',
          ),
        ],
      );
      final review = PortfolioDocumentBaseReview(
        document: _document(previous),
        base: incoming,
      );
      await _open(tester, review: review);
      expect(find.text('Не заполнено'), findsOneWidget);
      await _reveal(tester, 'skills:removed');
      expect(find.text('Удалено из общей базы'), findsOneWidget);
      await _reveal(tester, 'skills:new');
      expect(find.text('Dart'), findsOneWidget);
      expect(find.text('Не добавлено в документ'), findsWidgets);
      await _reveal(tester, 'experience:job');
      expect(
        find.text('Engineer\nTeam · 2025–2026\nBuilt an app'),
        findsOneWidget,
      );
      await _reveal(tester, 'education:school');
      expect(
        find.text(
          'Software Engineering\nUniversity · 2024–2027\nDegree details',
        ),
        findsOneWidget,
      );
      await _reveal(tester, 'links:website');
      expect(find.text('Portfolio\nhttps://example.com'), findsOneWidget);
      expect(find.textContaining('Instance of'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Avatar changes use existing private media widget without exposing paths',
    (tester) async {
      final previous = PortfolioContent();
      final path = 'accounts/first/media/${'a' * 32}.jpg';
      final incoming = previous.copyWith(
        profile: previous.profile.copyWith(avatarPath: path),
      );
      await _open(
        tester,
        review: PortfolioDocumentBaseReview(
          document: _document(previous),
          base: incoming,
        ),
      );
      expect(find.byType(StackCardAvatar), findsOneWidget);
      expect(
        tester
            .widget<PortfolioMediaImage>(find.byType(PortfolioMediaImage))
            .path,
        path,
      );
      expect(find.text(path), findsNothing);
      expect(find.text('Не заполнено'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Repository transition hides captured values and Apply', (
    tester,
  ) async {
    final harness = await _open(tester, review: _profileReview());
    harness.container.read(_repositoryProvider.notifier).select(_Repository());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('base-review-owner-changed')),
      findsOneWidget,
    );
    expect(find.text('Local role'), findsNothing);
    expect(find.byKey(const ValueKey('base-review-apply')), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('base-review-back')));
    expect(harness.result, isNull);
    expect(harness.repository.saves, 0);
  });

  testWidgets(
    'UID transition hides old data even when repository identity remains the same',
    (tester) async {
      final auth = _Auth();
      final harness = await _open(tester, review: _profileReview(), auth: auth);
      auth.select(const AuthUser(uid: 'second'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('base-review-owner-changed')),
        findsOneWidget,
      );
      expect(find.text('New base role'), findsNothing);
      expect(find.byKey(const ValueKey('base-review-apply')), findsNothing);
      auth.select(const AuthUser(uid: 'first'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('base-review-apply')), findsNothing);
      expect(harness.result, isNull);
    },
  );

  testWidgets('Sign out without guest access removes private choices', (
    tester,
  ) async {
    final auth = _Auth();
    await _open(tester, review: _profileReview(), auth: auth);
    auth.select(null);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('base-review-owner-changed')),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byKey(const ValueKey('base-review-apply')), findsNothing);
  });

  testWidgets(
    'Caller invalidated before route builds never exposes captured data',
    (tester) async {
      final harness = await _open(
        tester,
        review: _profileReview(),
        isActive: () => false,
      );
      expect(
        find.byKey(const ValueKey('base-review-owner-changed')),
        findsOneWidget,
      );
      expect(find.text('Local role'), findsNothing);
      expect(find.text('New base role'), findsNothing);
      expect(find.byKey(const ValueKey('base-review-apply')), findsNothing);
      expect(harness.result, isNull);
    },
  );

  testWidgets('Empty review is explicit and Apply disabled', (tester) async {
    final base = PortfolioContent(
      profile: const PortfolioProfile(name: 'Same'),
    );
    final harness = await _open(
      tester,
      review: PortfolioDocumentBaseReview(
        document: _document(base),
        base: base,
      ),
    );
    expect(find.byKey(const ValueKey('base-review-empty')), findsOneWidget);
    final button = tester.widget<StackCardButton>(
      find.byKey(const ValueKey('base-review-apply')),
    );
    expect(button.onPressed, isNull);
    await _tap(tester, find.byKey(const ValueKey('base-review-cancel')));
    expect(harness.result, isNull);
  });

  for (final locale in AppStrings.supportedLocales) {
    for (final size in [
      const Size(320, 568),
      const Size(568, 320),
      const Size(800, 1024),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'Review ${locale.languageCode} $size scale $scale with keyboard remains usable',
          (tester) async {
            final harness = await _open(
              tester,
              review: _profileReview(),
              locale: locale,
              size: size,
              scale: scale,
              keyboard: 180,
            );
            await _tap(tester, _row('headline:'));
            await _tap(tester, find.byKey(const ValueKey('base-review-apply')));
            expect(harness.result!.content.profile.headline, 'New base role');
            expect(harness.repository.saves, 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

PortfolioDocumentBaseReview _profileReview({bool legacy = false}) {
  final previous = PortfolioContent(
    profile: const PortfolioProfile(
      name: 'Alex',
      headline: 'Previous role',
      bio: 'Previous bio',
    ),
  );
  final document = _document(previous, legacy: legacy).copyWith(
    content: previous.copyWith(
      profile: previous.profile.copyWith(headline: 'Local role'),
    ),
  );
  final incoming = previous.copyWith(
    profile: previous.profile.copyWith(
      headline: 'New base role',
      bio: 'New base bio',
    ),
  );
  return PortfolioDocumentBaseReview(document: document, base: incoming);
}

PortfolioDocument _document(PortfolioContent base, {bool legacy = false}) =>
    PortfolioDocument(
      id: 'resume',
      title: 'Private CV',
      kind: PortfolioDocumentKind.resume,
      createdAt: DateTime.utc(2026, 10, 7),
      updatedAt: DateTime.utc(2026, 10, 7),
      content: base,
      baseSnapshot: legacy ? null : developerProfileData(base),
    );

Finder _row(String key) => find.byKey(ValueKey('base-review-$key'));
bool _selected(WidgetTester tester, String key) =>
    tester.widget<CheckboxListTile>(_row(key)).value!;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey('base-review-card-$key')));
  await tester.pumpAndSettle();
}

Future<_Harness> _open(
  WidgetTester tester, {
  required PortfolioDocumentBaseReview review,
  _Auth? auth,
  Locale locale = const Locale('ru'),
  Size size = const Size(390, 844),
  double scale = 1,
  double keyboard = 0,
  bool Function()? isActive,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _Repository();
  final container = ProviderContainer(
    overrides: [
      portfolioDraftRepositoryProvider.overrideWith(
        (ref) => ref.watch(_repositoryProvider),
      ),
      if (auth != null) accountAuthRepositoryProvider.overrideWithValue(auth),
    ],
  );
  container.read(_repositoryProvider.notifier).select(repository);
  if (auth != null) {
    container.read(accountSessionProvider);
    addTearDown(auth.close);
  }
  addTearDown(container.dispose);
  final harness = _Harness(container, repository);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        theme: locale.languageCode == 'ru'
            ? StackCardTheme.dark
            : StackCardTheme.light,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-review'),
              onPressed: () async {
                harness.result = await Navigator.of(context)
                    .push<PortfolioDocument>(
                      MaterialPageRoute(
                        builder: (_) => PortfolioDocumentBaseReviewScreen(
                          review: review,
                          isActive: isActive,
                        ),
                      ),
                    );
                harness.returned = true;
              },
              child: const Text('Return'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, find.byKey(const ValueKey('open-review')));
  return harness;
}

class _Harness {
  _Harness(this.container, this.repository);
  final ProviderContainer container;
  final _Repository repository;
  PortfolioDocument? result;
  bool returned = false;
}

class _Repository implements PortfolioDraftRepository {
  var saves = 0;
  @override
  Future<PortfolioDraft?> read() async => null;
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    saves++;
    return PortfolioDraft(
      content: content,
      notes: notes,
      revision: expectedRevision + 1,
      pendingSync: false,
      updatedAt: DateTime.utc(2026, 10, 7),
    );
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) async =>
      save(PortfolioContent(), expectedRevision: 0, notes: notes);
}

class _Auth implements AccountAuthRepository {
  final _changes = StreamController<AuthUser?>.broadcast(sync: true);
  AuthUser? _current = const AuthUser(uid: 'first');
  void select(AuthUser? user) {
    _current = user;
    _changes.add(user);
  }

  Future<void> close() => _changes.close();
  @override
  Stream<AuthUser?> watchSession() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> signOut() async => select(null);
  @override
  Future<void> signInEmail(String email, String password) async {}
  @override
  Future<void> registerEmail(String email, String password) async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signInGoogle() async {}
}
