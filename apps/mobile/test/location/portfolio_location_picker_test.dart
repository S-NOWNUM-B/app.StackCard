import 'dart:async';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/localization/location_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/location/location.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _selectedLocationProvider =
    NotifierProvider<_LocationSelection, PortfolioLocationRepository>(
      _LocationSelection.new,
    );

class _LocationSelection extends Notifier<PortfolioLocationRepository> {
  @override
  PortfolioLocationRepository build() => _LocationRepository();
  void select(PortfolioLocationRepository repository) => state = repository;
}

final _selectedDraftProvider =
    NotifierProvider<_DraftSelection, PortfolioDraftRepository>(
      _DraftSelection.new,
    );

class _DraftSelection extends Notifier<PortfolioDraftRepository> {
  @override
  PortfolioDraftRepository build() => _DraftRepository();
  void select(PortfolioDraftRepository repository) => state = repository;
}

void main() {
  test('Location messages have matching keys in both app catalogues', () {
    expect(
      russianLocationStrings.keys.toSet(),
      englishLocationStrings.keys.toSet(),
    );
    for (final locale in AppStrings.supportedLocales) {
      expect(AppStrings(locale).keys, containsAll(englishLocationStrings.keys));
    }
  });

  testWidgets('Opening never requests location and legacy text is not parsed', (
    tester,
  ) async {
    final repository = _LocationRepository();
    final h = await _pump(tester, repository: repository);
    await _openPicker(tester);
    expect(repository.calls, 0);
    expect(find.text('Сейчас: Almaty, district, Kazakhstan'), findsOneWidget);
    expect(_text(tester, 'location_city'), isEmpty);
    expect(_text(tester, 'location_country'), isEmpty);
    await _tap(tester, 'location_back');
    expect(h.result, isNull);
  });

  testWidgets(
    'Detected suggestion needs explicit confirmation and stays editable',
    (tester) async {
      final repository = _LocationRepository();
      final h = await _pump(tester, repository: repository);
      await _openPicker(tester);
      await _tap(tester, 'location_detect');
      expect(repository.calls, 1);
      expect(_text(tester, 'location_city'), 'Almaty');
      expect(_text(tester, 'location_country'), 'Kazakhstan');
      expect(find.byKey(const ValueKey('location_suggestion')), findsOneWidget);
      expect(h.result, isNull);
      await _enter(tester, 'location_city', ' Astana ');
      await _tap(tester, 'location_confirm');
      expect(h.result!.displayText, 'Astana, Kazakhstan');
    },
  );

  for (final failure in PortfolioLocationFailureKind.values) {
    testWidgets('${failure.name} leaves manual selection available', (
      tester,
    ) async {
      final repository = _LocationRepository()..failure = failure;
      final h = await _pump(tester, repository: repository);
      await _openPicker(tester);
      await _tap(tester, 'location_detect');
      expect(
        find.text(russianLocationStrings['location.${failure.name}']!),
        findsOneWidget,
      );
      if (failure == PortfolioLocationFailureKind.permanentlyDenied) {
        await _tap(tester, 'location_app_settings');
        expect(repository.appSettingsCalls, 1);
        expect(repository.calls, 1);
      }
      if (failure == PortfolioLocationFailureKind.serviceDisabled) {
        await _tap(tester, 'location_device_settings');
        expect(repository.locationSettingsCalls, 1);
        expect(repository.calls, 1);
      }
      await _enter(tester, 'location_city', 'Almaty');
      await _enter(tester, 'location_country', 'Kazakhstan');
      await _tap(tester, 'location_confirm');
      expect(h.result!.displayText, 'Almaty, Kazakhstan');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Retry is explicit and failed settings do not block manual input',
    (tester) async {
      final repository = _LocationRepository()
        ..failure = PortfolioLocationFailureKind.permanentlyDenied
        ..settingsOpen = false;
      await _pump(tester, repository: repository);
      await _openPicker(tester);
      await _tap(tester, 'location_detect');
      await _tap(tester, 'location_app_settings');
      expect(
        find.byKey(const ValueKey('location_settings_error')),
        findsOneWidget,
      );
      expect(repository.calls, 1);
      repository.failure = null;
      await _tap(tester, 'location_detect');
      expect(repository.calls, 2);
      expect(find.byKey(const ValueKey('location_error')), findsNothing);
      expect(
        find.byKey(const ValueKey('location_settings_error')),
        findsNothing,
      );
      expect(_text(tester, 'location_city'), 'Almaty');
    },
  );

  testWidgets(
    'Confirmation validates both fields and cancel returns no selection',
    (tester) async {
      final h = await _pump(tester);
      await _openPicker(tester);
      await _tap(tester, 'location_confirm');
      expect(
        find.text(russianAppStrings['builderForm.required']!),
        findsNWidgets(2),
      );
      await _enter(tester, 'location_city', 'a' * 101);
      await _enter(tester, 'location_country', 'Kazakhstan');
      await _tap(tester, 'location_confirm');
      expect(
        find.text(
          AppStrings(const Locale('ru'))
              .tr('builderForm.tooLong', {'limit': 100}),
        ),
        findsOneWidget,
      );
      await _tap(tester, 'location_back');
      expect(h.result, isNull);
    },
  );

  testWidgets('Late detected place never overwrites manual input', (
    tester,
  ) async {
    final repository = _LocationRepository()
      ..pending = Completer<PortfolioPlace>();
    final h = await _pump(tester, repository: repository);
    await _openPicker(tester);
    await _tap(tester, 'location_detect', settle: false);
    expect(_button(tester, 'location_confirm').onPressed, isNull);
    await _enter(tester, 'location_city', 'Astana');
    await _enter(tester, 'location_country', 'Kazakhstan');
    repository.pending!.complete(
      PortfolioPlace(city: 'Almaty', country: 'Kazakhstan'),
    );
    await tester.pumpAndSettle();
    expect(_text(tester, 'location_city'), 'Astana');
    expect(find.byKey(const ValueKey('location_suggestion')), findsNothing);
    await _tap(tester, 'location_confirm');
    expect(h.result!.city, 'Astana');
  });

  testWidgets('Cancel ignores a detection completing during dismissal', (
    tester,
  ) async {
    final repository = _LocationRepository()
      ..pending = Completer<PortfolioPlace>();
    final h = await _pump(tester, repository: repository);
    await _openPicker(tester);
    await _tap(tester, 'location_detect', settle: false);
    await _tap(tester, 'location_back', settle: false);
    repository.pending!.complete(
      PortfolioPlace(city: 'Almaty', country: 'Kazakhstan'),
    );
    await tester.pumpAndSettle();
    expect(h.result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Repository transition hides old form and rejects late results', (
    tester,
  ) async {
    final repository = _LocationRepository()
      ..pending = Completer<PortfolioPlace>();
    final h = await _pump(tester, repository: repository);
    await _openPicker(tester);
    await _tap(tester, 'location_detect', settle: false);
    h.container
        .read(_selectedLocationProvider.notifier)
        .select(_LocationRepository());
    await tester.pump();
    expect(
      find.byKey(const ValueKey('location_owner_changed')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('location_city')), findsNothing);
    repository.pending!.complete(
      PortfolioPlace(city: 'Almaty', country: 'Kazakhstan'),
    );
    await tester.pumpAndSettle();
    expect(h.result, isNull);
    await _tap(tester, 'location_back');
  });

  testWidgets(
    'UID transition hides old suggestion and rejects late detection',
    (tester) async {
      final auth = _Auth();
      final repository = _LocationRepository()
        ..pending = Completer<PortfolioPlace>();
      final h = await _pump(tester, repository: repository, auth: auth);
      await _openPicker(tester);
      await _tap(tester, 'location_detect', settle: false);
      auth.select(const AuthUser(uid: 'second'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('location_owner_changed')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('location_confirm')), findsNothing);
      repository.pending!.complete(
        PortfolioPlace(city: 'Almaty', country: 'Kazakhstan'),
      );
      await tester.pumpAndSettle();
      expect(h.result, isNull);
    },
  );

  testWidgets('Confirmed location changes only form until Apply and Save', (
    tester,
  ) async {
    final h = await _pump(tester, profile: true);
    await _tap(tester, 'profile_pick_location');
    await _enter(tester, 'location_city', 'Astana');
    await _enter(tester, 'location_country', 'Kazakhstan');
    await _tap(tester, 'location_confirm');
    expect(_text(tester, 'builder_form_locationText'), 'Astana, Kazakhstan');
    expect(h.content.profile.locationText, 'Original location');
    expect(h.draft.saves, 0);
    await _tap(tester, 'builder_form_apply');
    expect(h.content.profile.locationText, 'Astana, Kazakhstan');
    expect(h.draft.content.profile.locationText, 'Original location');
    expect(h.draft.saves, 0);
    await _tap(tester, 'test_save');
    expect(h.draft.content.profile.locationText, 'Astana, Kazakhstan');
    expect(h.draft.saves, 1);
  });

  testWidgets('Cancel after a confirmed picker preserves working profile', (
    tester,
  ) async {
    final h = await _pump(tester, profile: true);
    await _tap(tester, 'profile_pick_location');
    await _enter(tester, 'location_city', 'Astana');
    await _enter(tester, 'location_country', 'Kazakhstan');
    await _tap(tester, 'location_confirm');
    await _tap(tester, 'builder_form_cancel');
    expect(h.content.profile.locationText, 'Original location');
    expect(h.draft.saves, 0);
  });

  testWidgets('Profile ignores result when draft owner changes during picker', (
    tester,
  ) async {
    final h = await _pump(tester, profile: true);
    await _tap(tester, 'profile_pick_location');
    await _enter(tester, 'location_city', 'Astana');
    await _enter(tester, 'location_country', 'Kazakhstan');
    h.container
        .read(_selectedDraftProvider.notifier)
        .select(_DraftRepository());
    await tester.pumpAndSettle();
    await _tap(tester, 'location_confirm');
    expect(find.byKey(const ValueKey('location_confirm')), findsNothing);
    await _tap(tester, 'location_back');
    expect(_button(tester, 'builder_form_apply').onPressed, isNull);
    expect(h.content.profile.locationText, 'Original location');
    expect(h.draft.saves, 0);
  });

  testWidgets(
    'Profile rejects a returned place after UID changes even with the same repository',
    (tester) async {
      final auth = _Auth();
      final h = await _pump(tester, profile: true, auth: auth);
      await _tap(tester, 'profile_pick_location');
      auth.select(const AuthUser(uid: 'second'));
      await tester.pump();
      // Даже внешнее завершение route не должно обойти guard в вызывающей форме.
      Navigator.of(tester.element(find.byType(PortfolioLocationPicker)))
          .pop(PortfolioPlace(city: 'Astana', country: 'Kazakhstan'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'builder_form_locationText'), 'Original location');
      expect(h.content.profile.locationText, 'Original location');
      expect(h.draft.saves, 0);
    },
  );

  for (final locale in AppStrings.supportedLocales) {
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      testWidgets(
        'Picker supports ${locale.languageCode} $size scale 2 and keyboard',
        (tester) async {
          final repository = _LocationRepository()
            ..failure = PortfolioLocationFailureKind.permanentlyDenied;
          final h = await _pump(
            tester,
            repository: repository,
            locale: locale,
            size: size,
            scale: 2,
            keyboard: 180,
          );
          await _openPicker(tester);
          await _tap(tester, 'location_detect');
          expect(
            find.text(AppStrings(locale).tr('location.permanentlyDenied')),
            findsOneWidget,
          );
          await _enter(tester, 'location_city', 'Almaty');
          await _enter(tester, 'location_country', 'Kazakhstan');
          await _tap(tester, 'location_confirm');
          expect(h.result!.displayText, 'Almaty, Kazakhstan');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _openPicker(WidgetTester tester) =>
    _tap(tester, 'test_open_picker');

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  final finder = find.byKey(ValueKey(key));
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pump();
  final filled = find.descendant(
    of: finder,
    matching: find.byType(FilledButton),
  );
  await tester.tap(filled.evaluate().isEmpty ? finder : filled);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final field = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) => tester
    .widget<TextFormField>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextFormField),
      ),
    )
    .controller!
    .text;

StackCardButton _button(WidgetTester tester, String key) =>
    tester.widget<StackCardButton>(find.byKey(ValueKey(key)));

Future<_Harness> _pump(
  WidgetTester tester, {
  _LocationRepository? repository,
  _Auth? auth,
  bool profile = false,
  Locale locale = const Locale('ru'),
  Size size = const Size(390, 844),
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final draft = _DraftRepository();
  final container = ProviderContainer(
    overrides: [
      portfolioDraftRepositoryProvider.overrideWith(
        (ref) => ref.watch(_selectedDraftProvider),
      ),
      portfolioLocationRepositoryProvider.overrideWith(
        (ref) => ref.watch(_selectedLocationProvider),
      ),
      if (auth != null) accountAuthRepositoryProvider.overrideWithValue(auth),
    ],
  );
  container
      .read(_selectedLocationProvider.notifier)
      .select(repository ?? _LocationRepository());
  container.read(_selectedDraftProvider.notifier).select(draft);
  // Session не начинается при открытии picker: она уже восстановлена app boundary.
  if (auth != null) container.read(accountSessionProvider);
  final h = _Harness(container, draft);
  final router = GoRouter(
    initialLocation: '/return',
    routes: [
      GoRoute(path: '/return', builder: (_, _) => _Launcher(h)),
      GoRoute(
        path: '/editor',
        builder: (_, _) => const PortfolioProfileEditorScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  if (auth != null) addTearDown(auth.close);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: StackCardTheme.light,
        darkTheme: StackCardTheme.dark,
        themeMode: locale.languageCode == 'en'
            ? ThemeMode.light
            : ThemeMode.dark,
        locale: locale,
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
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (profile) {
    router.push('/editor');
    await tester.pumpAndSettle();
  }
  return h;
}

class _Launcher extends ConsumerWidget {
  const _Launcher(this.harness);
  final _Harness harness;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        TextButton(
          key: const ValueKey('test_open_picker'),
          onPressed: () async {
            harness.result = await Navigator.of(context).push<PortfolioPlace>(
              MaterialPageRoute(
                builder: (_) => const PortfolioLocationPicker(
                  currentLocation: 'Almaty, district, Kazakhstan',
                ),
              ),
            );
          },
          child: const Text('Open'),
        ),
        TextButton(
          key: const ValueKey('test_save'),
          onPressed: () =>
              ref.read(portfolioDraftControllerProvider.notifier).save(),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _Harness {
  _Harness(this.container, this.draft);
  final ProviderContainer container;
  final _DraftRepository draft;
  PortfolioPlace? result;
  PortfolioContent get content =>
      container.read(portfolioDraftControllerProvider).content!;
}

class _LocationRepository implements PortfolioLocationRepository {
  PortfolioLocationFailureKind? failure;
  Completer<PortfolioPlace>? pending;
  int calls = 0;
  int appSettingsCalls = 0;
  int locationSettingsCalls = 0;
  bool settingsOpen = true;
  @override
  Future<PortfolioPlace> currentPlace() async {
    ++calls;
    if (failure != null) throw PortfolioLocationFailure(failure!);
    return pending == null
        ? PortfolioPlace(city: 'Almaty', country: 'Kazakhstan')
        : pending!.future;
  }

  @override
  Future<bool> openAppSettings() async {
    ++appSettingsCalls;
    return settingsOpen;
  }

  @override
  Future<bool> openLocationSettings() async {
    ++locationSettingsCalls;
    return settingsOpen;
  }
}

class _DraftRepository implements PortfolioDraftRepository {
  PortfolioContent content = PortfolioContent(
    profile: PortfolioProfile(locationText: 'Original location'),
  );
  int saves = 0;
  @override
  Future<PortfolioDraft?> read() async => PortfolioDraft(
    notes: '',
    revision: 1,
    updatedAt: DateTime.utc(2026, 10, 7),
    pendingSync: false,
    content: content,
  );
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    ++saves;
    this.content = content;
    return PortfolioDraft(
      notes: notes,
      revision: expectedRevision + 1,
      updatedAt: DateTime.utc(2026, 10, 7),
      pendingSync: false,
      content: content,
    );
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) async => (await read())!;
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
