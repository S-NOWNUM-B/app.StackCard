import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/app_router.dart';
import 'app/local_runtime.dart';
import 'core/localization/app_strings.dart';
import 'core/state/app_settings.dart';
import 'core/state/appearance_controller.dart';
import 'core/state/settings_repository.dart';
import 'core/theme/stackcard_theme.dart';
import 'features/github_import/github_import.dart';
import 'features/auth/auth.dart';
import 'features/media/media.dart';
import 'features/portfolio_draft/portfolio_draft.dart';
import 'features/projects/projects.dart';
import 'shared/widgets/stackcard_states.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StackCardBootstrap());
}

class StackCardBootstrap extends StatefulWidget {
  const StackCardBootstrap({super.key, this.loadRuntime});

  final Future<LocalRuntime> Function()? loadRuntime;

  @override
  State<StackCardBootstrap> createState() => _StackCardBootstrapState();
}

class _StackCardBootstrapState extends State<StackCardBootstrap> {
  late Future<LocalRuntime> _runtime = _load();
  LocalRuntime? _loaded;

  Future<LocalRuntime> _load() {
    final future = _loadRuntime();
    // Retry может завершиться ошибкой до следующего кадра FutureBuilder.
    future.ignore();
    return future;
  }

  Future<LocalRuntime> _loadRuntime() async {
    final runtime =
        await (widget.loadRuntime?.call() ??
            LocalRuntime.load(configureAuth: true));
    if (!mounted) {
      await runtime.storage.close();
    } else {
      _loaded = runtime;
    }
    return runtime;
  }

  @override
  void dispose() {
    // После удаления дерева уже нет UI для close failure; обе boxes закрываются.
    _loaded?.storage.close().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LocalRuntime>(
    future: _runtime,
    builder: (context, snapshot) {
      if (snapshot.data case final runtime?) {
        return StackCardApp(
          initialSettings: runtime.settings,
          settingsRepository: runtime.settingsRepository,
          providerOverrides: [
            githubResponseCacheProvider.overrideWithValue(runtime.githubCache),
            accountAuthRepositoryProvider.overrideWithValue(
              runtime.authRepository,
            ),
            portfolioDraftRepositoryFactoryProvider.overrideWithValue(
              runtime.repositoryForUser,
            ),
            portfolioMediaRepositoryFactoryProvider.overrideWithValue(
              runtime.mediaRepositoryForUser,
            ),
            guestDraftTransferProvider.overrideWithValue(
              runtime.transferGuestToUser,
            ),
            guestDraftAvailableProvider.overrideWith((ref) {
              final session = ref.watch(accountSessionProvider);
              final user = !session.isLoading && !session.hasError
                  ? session.value
                  : null;
              return user == null
                  ? Future.value(false)
                  : runtime.draftAccounts.hasGuestDraft(forUid: user.uid);
            }),
          ],
        );
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: StackCardTheme.dark,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Builder(
                builder: (context) => StackCardStateView(
                  kind: snapshot.hasError
                      ? StackCardViewState.error
                      : StackCardViewState.loading,
                  title: context.strings.tr(
                    snapshot.hasError ? 'startup.error' : 'startup.loading',
                  ),
                  message: context.strings.tr(
                    snapshot.hasError ? 'startup.errorHint' : 'startup.hint',
                  ),
                  onRetry: snapshot.hasError
                      ? () => setState(() {
                          _runtime = _load();
                        })
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class StackCardApp extends StatefulWidget {
  const StackCardApp({
    super.key,
    this.initialLocation = '/sign-in',
    this.initialThemeMode = ThemeMode.dark,
    this.providerOverrides = const [],
    this.initialSettings,
    this.settingsRepository,
  });

  final String initialLocation;
  final ThemeMode initialThemeMode;
  final List<Override> providerOverrides;
  final AppSettings? initialSettings;
  final SettingsRepository? settingsRepository;

  @override
  State<StackCardApp> createState() => _StackCardAppState();
}

class _StackCardAppState extends State<StackCardApp> {
  @override
  Widget build(BuildContext context) {
    return riverpod.ProviderScope(
      overrides: widget.providerOverrides,
      child: ChangeNotifierProvider(
        create: (_) => AppearanceController(
          themeMode: widget.initialThemeMode,
          initialSettings: widget.initialSettings,
          settingsRepository: widget.settingsRepository,
        ),
        child: _RoutedStackCardApp(initialLocation: widget.initialLocation),
      ),
    );
  }
}

class _RoutedStackCardApp extends riverpod.ConsumerStatefulWidget {
  const _RoutedStackCardApp({required this.initialLocation});
  final String initialLocation;

  @override
  riverpod.ConsumerState<_RoutedStackCardApp> createState() =>
      _RoutedStackCardAppState();
}

class _RoutedStackCardAppState
    extends riverpod.ConsumerState<_RoutedStackCardApp> {
  final _access = AppRouteAccess();
  late final GoRouter _router;
  String _identity = 'local';

  @override
  void initState() {
    super.initState();
    _updateAccess();
    _router = createAppRouter(
      initialLocation: widget.initialLocation,
      access: _access,
    );
  }

  void _updateAccess() {
    final configured = ref.read(accountAuthRepositoryProvider) != null;
    final session = ref.read(accountSessionProvider);
    final guest = ref.read(guestAccessProvider);
    final user = !session.hasError && !session.isLoading ? session.value : null;
    _identity = !configured
        ? 'local'
        : session.isLoading
        ? 'restoring'
        : session.hasError
        ? 'locked'
        : user != null
        ? 'account:${user.uid}'
        : guest
        ? 'guest'
        : 'signedOut';
    _access.update(
      configured: configured,
      restoring: session.isLoading || session.hasError,
      authenticated: user != null,
      guest: guest,
    );
  }

  void _sessionChanged() {
    final previous = _identity;
    _updateAccess();
    if (previous == _identity) return;
    // Discard private form widget state and filter state at an identity boundary.
    ref.invalidate(portfolioDraftControllerProvider);
    ref.invalidate(projectFiltersProvider);
    if (previous.startsWith('account:') || previous == 'guest') {
      _router.go(_access.authenticated ? '/home' : '/sign-in');
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _router.dispose();
    _access.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountSessionProvider, (_, _) => _sessionChanged());
    ref.listen(guestAccessProvider, (_, _) => _sessionChanged());
    return Selector<AppearanceController, (ThemeMode, Locale)>(
      selector: (_, controller) => (controller.themeMode, controller.locale),
      builder: (context, appearance, _) => MaterialApp.router(
        key: ValueKey(_identity),
        title: 'StackCard',
        debugShowCheckedModeBanner: false,
        theme: StackCardTheme.light,
        darkTheme: StackCardTheme.dark,
        themeMode: appearance.$1,
        locale: appearance.$2,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeAnimationDuration: Duration.zero,
        routerConfig: _router,
      ),
    );
  }
}
