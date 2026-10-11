import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/state/appearance_controller.dart';
import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_input.dart';
import '../github_import/github_import.dart';
import '../auth/auth.dart';
import '../portfolio_draft/portfolio_draft.dart';
import 'account_settings_section.dart';
import 'settings_editor_scaffold.dart';
export 'settings_account_screen.dart';
// Совместимые архивные формы не входят в routes современного интерфейса.
export 'settings_base_editor_screen.dart';
export 'settings_providers.dart';
export 'settings_editor_scaffold.dart';

class SettingsScreen extends riverpod.ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final draft = ref.watch(portfolioDraftControllerProvider);
    final strings = context.strings;
    return _SettingsPage(
      titleKey: 'nav.settings',
      fallbackPath: '/home',
      children: [
        if (!draft.loaded && draft.failure != null) ...[
          const SizedBox(height: StackCardSpacing.md),
          StackCardStateView(
            kind: StackCardViewState.error,
            title: strings.tr('async.errorTitle'),
            message: strings.tr('async.errorMessage'),
            onRetry: () =>
                ref.read(portfolioDraftControllerProvider.notifier).load(),
          ),
        ],
        _SettingsRow(
          key: const Key('settings.group.account'),
          icon: Icons.shield_outlined,
          title: strings.tr('settings.accountSecurity'),
          onPressed: () => context.push('/settings/account'),
        ),
        _SettingsRow(
          key: const Key('settings.group.github'),
          icon: Icons.link_rounded,
          title: 'GitHub',
          onPressed: () => context.push('/settings/github'),
        ),
        _SettingsRow(
          key: const Key('settings.group.appearance'),
          icon: Icons.tune_rounded,
          title: strings.tr('settings.application'),
          onPressed: () => context.push('/settings/appearance'),
        ),
        _SettingsRow(
          key: const Key('settings.group.inbox'),
          icon: Icons.inbox_outlined,
          title: strings.tr('inbox.title'),
          onPressed: () => context.push('/inbox'),
        ),
        _SettingsRow(
          key: const Key('settings.group.notifications'),
          icon: Icons.notifications_none_rounded,
          title: strings.tr('settings.notifications'),
          onPressed: () => context.push('/settings/notifications'),
        ),
        _SettingsRow(
          key: const Key('settings.group.about'),
          icon: Icons.help_outline_rounded,
          title: 'Помощь и о приложении',
          onPressed: () => context.push('/settings/about'),
          showDivider: false,
        ),
        Divider(
          height: StackCardSpacing.lg,
          thickness: 1,
          color: context.colors.borderStrong,
        ),
        const AccountSettingsSection(),
      ],
    );
  }
}

/// Route /settings/appearance: сохраняет только существующий AppSettings.
class SettingsAppearanceScreen extends riverpod.ConsumerStatefulWidget {
  const SettingsAppearanceScreen({super.key});
  @override
  riverpod.ConsumerState<SettingsAppearanceScreen> createState() =>
      _SettingsAppearanceState();
}

class _SettingsAppearanceState
    extends riverpod.ConsumerState<SettingsAppearanceScreen> {
  bool _clearing = false;
  Future<void> _clearCache() async {
    final cache = ref.read(githubResponseCacheProvider);
    if (cache is! ClearableGitHubResponseCache) return;
    setState(() => _clearing = true);
    ref.read(githubImportRepositoryProvider).cancelRequests();
    ref.invalidate(githubImportControllerProvider);
    try {
      await cache.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Кэш GitHub очищен. Портфолио и проекты сохранены.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось очистить кэш. Повторите попытку.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceController>();
    final strings = context.strings;
    return _SettingsPage(
      titleKey: 'settings.application',
      children: [
        SwitchListTile.adaptive(
          key: const Key('settings.reducedMotion'),
          contentPadding: EdgeInsets.zero,
          title: Text(strings.tr('settings.reducedMotion')),
          subtitle: MediaQuery.disableAnimationsOf(context)
              ? Text(strings.tr('settingsManagement.systemMotion'))
              : null,
          value: appearance.reducedMotion,
          onChanged: appearance.setReducedMotion,
        ),
        if (appearance.isSaving)
          Semantics(
            liveRegion: true,
            child: Text(strings.tr('settings.saving')),
          ),
        if (appearance.saveFailure != null)
          StackCardStateView(
            kind: StackCardViewState.error,
            title: strings.tr('settings.saveError'),
            message: strings.tr('settings.saveErrorNote'),
            onRetry: appearance.retrySave,
          ),
        const SizedBox(height: StackCardSpacing.xl),
        StackCardButton(
          key: const Key('settings.clearCache'),
          label: 'Очистить кэш GitHub',
          loading: _clearing,
          onPressed:
              ref.watch(githubResponseCacheProvider)
                  is ClearableGitHubResponseCache
              ? _clearCache
              : null,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        const Text(
          'Удаляются только загруженные ответы GitHub. Ваши проекты, портфолио и фото сохраняются.',
        ),
      ],
    );
  }
}

class SettingsGitHubScreen extends riverpod.ConsumerStatefulWidget {
  const SettingsGitHubScreen({super.key});
  @override
  riverpod.ConsumerState<SettingsGitHubScreen> createState() =>
      _SettingsGitHubState();
}

class _SettingsGitHubState
    extends riverpod.ConsumerState<SettingsGitHubScreen> {
  final _input = TextEditingController();
  String? _initial;
  PortfolioDraftRepository? _repository;
  (Object?, String?, bool, bool)? _initialOwner;
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  (Object?, String?, bool, bool) _owner({bool watch = false}) {
    final account = watch
        ? ref.watch(accountAuthRepositoryProvider)
        : ref.read(accountAuthRepositoryProvider);
    if (account == null) return (null, null, true, true);
    final session = watch
        ? ref.watch(accountSessionProvider)
        : ref.read(accountSessionProvider);
    final guest = watch
        ? ref.watch(guestAccessProvider)
        : ref.read(guestAccessProvider);
    final ready = session.hasValue && !session.isLoading && !session.hasError;
    return (account, ready ? session.value?.uid : null, ready && guest, ready);
  }

  Future<void> _save() async {
    final repository = _repository;
    final current =
        ref
            .read(portfolioDraftControllerProvider)
            .draft
            ?.content
            ?.githubUsername ??
        '';
    if (repository == null ||
        !identical(repository, ref.read(portfolioDraftRepositoryProvider)) ||
        _initialOwner != _owner() ||
        current != _initial) {
      setState(
        () => _error = 'Профиль изменился. Откройте настройки GitHub заново.',
      );
      return;
    }
    final capturedInput = _input.text;
    final normalized = normalizePortfolioGitHubUsername(capturedInput);
    if (normalized == null) {
      setState(
        () => _error =
            'Укажите имя пользователя или ссылку https://github.com/имя.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final success = await ref
        .read(portfolioDraftControllerProvider.notifier)
        .saveGitHubIdentity(capturedInput, expectedRepository: repository);
    if (!mounted ||
        !identical(repository, ref.read(portfolioDraftRepositoryProvider)) ||
        _initialOwner != _owner()) {
      return;
    }
    setState(() {
      _saving = false;
      if (success) {
        _initial = normalized;
        if (_input.text == capturedInput) _input.text = normalized;
      } else {
        _error =
            'Не удалось сохранить GitHub. Введённые данные остались в форме.';
      }
    });
    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('GitHub сохранён.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = _owner(watch: true);
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    final draft = ref.watch(portfolioDraftControllerProvider);
    if (_repository != null &&
        (!identical(_repository, repository) || _initialOwner != owner)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _input.clear();
          _initial = null;
          _repository = null;
          _initialOwner = null;
          _saving = false;
          _error = null;
        });
      });
      return const _SettingsPage(
        titleKey: 'settings.github',
        children: [
          Text('Аккаунт изменился. Данные предыдущего профиля скрыты.'),
        ],
      );
    }
    if (!draft.loaded) {
      return _SettingsPage(
        titleKey: 'settings.github',
        children: [
          StackCardStateView(
            kind: draft.failure == null
                ? StackCardViewState.loading
                : StackCardViewState.error,
            title: context.strings.tr(
              draft.failure == null ? 'draft.loading' : 'draft.readFailure',
            ),
            onRetry: draft.failure == null
                ? null
                : ref.read(portfolioDraftControllerProvider.notifier).load,
          ),
        ],
      );
    }
    if (draft.loaded && _initial == null) {
      _initial = draft.draft?.content?.githubUsername ?? '';
      _input.text = _initial!;
      _repository = repository;
      _initialOwner = owner;
    }
    return _SettingsPage(
      titleKey: 'settings.github',
      children: [
        const Text(
          'Один профиль GitHub используется для импорта проектов. Он не меняет адрес портфолио и не импортирует репозитории автоматически.',
        ),
        const SizedBox(height: StackCardSpacing.xl),
        StackCardInput(
          key: const Key('settings.github.username'),
          label: 'Профиль GitHub',
          hint: 'username или https://github.com/username',
          controller: _input,
          enabled: draft.loaded && !_saving,
          errorText: _error,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: StackCardSpacing.lg),
        StackCardButton(
          key: const Key('settings.github.save'),
          label: 'Сохранить',
          loading: _saving,
          onPressed: draft.canEdit ? _save : null,
        ),
      ],
    );
  }
}

class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});
  @override
  Widget build(BuildContext context) => _SettingsPage(
    titleKey: 'settings.about',
    children: [
      Text('StackCard', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: StackCardSpacing.lg),
      const Text(
        'Соберите профиль, выберите проекты из библиотеки и сохраните портфолио в Редакторе. Главная показывает последнюю сохранённую версию.',
      ),
      const SizedBox(height: StackCardSpacing.lg),
      const Text(
        'Кнопка «Скачать портфолио» создаёт PDF. «Поделиться» отправляет публичную ссылку. Сохранение в редакторе не публикует изменения: новую версию нужно подтвердить отдельно.',
      ),
      const SizedBox(height: StackCardSpacing.lg),
      const Text(
        'При ошибке соединения введённые данные остаются в форме. Дождитесь синхронизации перед обновлением публикации.',
      ),
      const SizedBox(height: StackCardSpacing.xl),
      StackCardButton(
        label: 'Лицензии',
        onPressed: () =>
            showLicensePage(context: context, applicationName: 'StackCard'),
      ),
    ],
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.titleKey,
    required this.children,
    this.fallbackPath = '/settings',
  });

  final String titleKey;
  final List<Widget> children;
  final String fallbackPath;

  @override
  Widget build(BuildContext context) => SettingsEditorScaffold(
    title: context.strings.tr(titleKey),
    onBack: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(fallbackPath);
      }
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.onPressed,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onPressed;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.border))
            : null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.md),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 24, color: colors.textSecondary),
              ),
              const SizedBox(width: StackCardSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onPressed != null) ...[
                const SizedBox(width: StackCardSpacing.sm),
                const ExcludeSemantics(
                  child: Icon(Icons.chevron_right_rounded, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (onPressed == null) return content;
    return TextButton(
      onPressed: onPressed,
      style:
          TextButton.styleFrom(
            minimumSize: const Size.fromHeight(StackCardSize.touchTarget),
            padding: EdgeInsets.zero,
            foregroundColor: colors.textPrimary,
            alignment: Alignment.centerLeft,
            shape: const RoundedRectangleBorder(),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? colors.focus
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
      child: content,
    );
  }
}
