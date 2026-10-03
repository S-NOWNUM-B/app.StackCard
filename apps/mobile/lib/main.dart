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
import 'features/portfolio_draft/portfolio_draft.dart';
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
    final runtime = await (widget.loadRuntime?.call() ?? LocalRuntime.load());
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
            portfolioDraftRepositoryProvider.overrideWithValue(
              runtime.draftRepository,
            ),
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
  late final GoRouter _router = createAppRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

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
        child: Selector<AppearanceController, (ThemeMode, Locale)>(
          selector: (_, controller) =>
              (controller.themeMode, controller.locale),
          builder: (context, appearance, _) => MaterialApp.router(
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
        ),
      ),
    );
  }
}
