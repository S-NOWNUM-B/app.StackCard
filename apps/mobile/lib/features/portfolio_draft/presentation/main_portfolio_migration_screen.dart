import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../auth/auth.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft_repository.dart';
import '../portfolio_draft_providers.dart';
import 'main_portfolio_content_view.dart';
import 'portfolio_draft_controller.dart';

/// Выбор владельца вместо автоматического слияния прежних snapshots.
class MainPortfolioMigrationScreen extends ConsumerStatefulWidget {
  const MainPortfolioMigrationScreen({super.key});

  @override
  ConsumerState<MainPortfolioMigrationScreen> createState() =>
      _MainPortfolioMigrationScreenState();
}

class _MainPortfolioMigrationScreenState
    extends ConsumerState<MainPortfolioMigrationScreen> {
  PortfolioDraftRepository? _repository;
  PortfolioContent? _basis;
  (Object?, String?, bool, bool)? _initialOwner;
  String? _selected;
  var _saving = false;
  var _error = false;
  var _ownerInvalid = false;

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

  bool get _sameOwner =>
      mounted &&
      !_ownerInvalid &&
      _owner() == _initialOwner &&
      identical(_repository, ref.read(portfolioDraftRepositoryProvider));

  void _invalidate() {
    _ownerInvalid = true;
    _basis = null;
    _selected = null;
  }

  PortfolioContent _preview(String id) {
    final workspace = _basis!;
    final document = id == 'base'
        ? null
        : workspace.documents.where((item) => item.id == id).firstOrNull;
    final source = document == null
        ? workspace
        : resolveDocumentContent(workspace, document);
    final sanitized = mainPortfolioMigrationContent(workspace, source);
    final projectsVisible = source.blocks.any(
      (block) =>
          block.kind == PortfolioBlockKind.featuredProjects && block.visible,
    );
    return sanitized.copyWith(
      projects: projectsVisible
          ? source.projects
                .where((project) => project.visible)
                .map((project) => project.copyWith(imagePaths: const []))
                .toList()
          : const [],
    );
  }

  Future<void> _previewSource(String id, String title) async {
    if (!_sameOwner || _saving) return;
    final content = _preview(id);
    await showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          ref.watch(portfolioDraftRepositoryProvider);
          ref.watch(accountSessionProvider);
          if (!_sameOwner) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted &&
                  ModalRoute.of(context)?.isCurrent == true) {
                Navigator.pop(context);
              }
            });
            return const SizedBox.shrink();
          }
          return Dialog(
            insetPadding: const EdgeInsets.all(StackCardSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: StackCardSize.contentMaxWidth,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(StackCardSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: StackCardSpacing.lg),
                    MainPortfolioContentView(content: content),
                    const SizedBox(height: StackCardSpacing.lg),
                    StackCardButton(
                      label: 'Закрыть',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_sameOwner || _saving || _selected == null) return;
    final state = ref.read(portfolioDraftControllerProvider);
    if (state.remoteUpdateAvailable ||
        (state.draft?.content ?? PortfolioContent()) != _basis) {
      setState(() => _error = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = false;
    });
    final selected = _selected!;
    final success = await ref
        .read(portfolioDraftControllerProvider.notifier)
        .initializeMainPortfolio(
          sourceDocumentId: selected == 'base' ? null : selected,
          includeBaseProjects: selected == 'base',
          expectedWorkspace: _basis,
          expectedRepository: _repository!,
        );
    if (!mounted || !_sameOwner) return;
    setState(() {
      _saving = false;
      _error = !success;
    });
    if (success) context.go('/editor');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final owner = _owner(watch: true);
    if (_initialOwner != null && owner != _initialOwner && !_ownerInvalid) {
      _invalidate();
    }
    ref.listen(portfolioDraftRepositoryProvider, (_, next) {
      if (_repository != null &&
          !identical(_repository, next) &&
          !_ownerInvalid) {
        setState(_invalidate);
      }
    });
    if (_basis == null && state.loaded && !_ownerInvalid) {
      _repository = ref.read(portfolioDraftRepositoryProvider);
      _initialOwner = owner;
      _basis = state.draft?.content ?? PortfolioContent();
    }
    final workspace = _basis;
    Widget body;
    if (state.loading || workspace == null || _ownerInvalid) {
      body = const StackCardStateView(
        kind: StackCardViewState.loading,
        title: 'Загрузка',
      );
    } else if (!state.canEdit) {
      body = StackCardStateView(
        kind: StackCardViewState.error,
        title: 'Не удалось открыть сохранённые данные',
        onRetry: ref.read(portfolioDraftControllerProvider.notifier).load,
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(StackCardSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Выберите основу портфолио',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: StackCardSpacing.sm),
            const Text(
              'Прежние данные сохранятся. Тексты из разных документов не объединяются.',
            ),
            const SizedBox(height: StackCardSpacing.xl),
            _sourceRow('base', 'Прежний профиль'),
            for (final document in workspace.documents)
              _sourceRow(
                document.id,
                document.title.isEmpty
                    ? 'Документ без названия'
                    : document.title,
              ),
            if (_error) ...[
              const SizedBox(height: StackCardSpacing.lg),
              Text(
                'Не удалось перенести данные. Если сохранённая версия изменилась, откройте её заново.',
                key: const Key('main.migration.error'),
                style: TextStyle(color: context.colors.error),
              ),
              StackCardButton(
                label: 'Обновить список',
                onPressed: _saving
                    ? null
                    : () async {
                        await ref
                            .read(portfolioDraftControllerProvider.notifier)
                            .reload();
                        if (!mounted || !_sameOwner) return;
                        setState(() {
                          _basis = null;
                          _selected = null;
                          _error = false;
                        });
                      },
              ),
            ],
          ],
        ),
      );
    }
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Основное портфолио')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: StackCardSize.contentMaxWidth,
              ),
              child: body,
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StackCardSpacing.lg,
              vertical: StackCardSpacing.sm,
            ),
            child: StackCardButton(
              key: const Key('main.migration.apply'),
              label: _saving ? 'Перенос…' : 'Использовать выбранное',
              primary: true,
              onPressed: _selected == null || _saving || _ownerInvalid
                  ? null
                  : _save,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceRow(String id, String title) => Padding(
    padding: const EdgeInsets.only(bottom: StackCardSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          selected: _selected == id,
          button: true,
          child: ListTile(
            key: ValueKey('main.migration.source.$id'),
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            trailing: Icon(
              _selected == id
                  ? Icons.check_circle_outline_rounded
                  : Icons.radio_button_unchecked_rounded,
            ),
            onTap: _saving
                ? null
                : () => setState(() {
                    _selected = id;
                    _error = false;
                  }),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: ValueKey('main.migration.preview.$id'),
            onPressed: _saving ? null : () => _previewSource(id, title),
            child: const Text('Просмотреть'),
          ),
        ),
        Divider(color: context.colors.border),
      ],
    ),
  );
}
