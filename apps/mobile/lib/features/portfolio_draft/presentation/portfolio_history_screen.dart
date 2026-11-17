import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_theme.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_dialog_actions.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_history.dart';
import '../portfolio_history_providers.dart';
import 'main_portfolio_content_view.dart';
import 'portfolio_draft_controller.dart';

String portfolioHistoryDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String portfolioHistoryChange(PortfolioSnapshotChange change) =>
    switch (change.kind) {
      PortfolioSnapshotChangeKind.profile => 'изменён профиль',
      PortfolioSnapshotChangeKind.projectsAdded =>
        'добавлено проектов: ${change.count}',
      PortfolioSnapshotChangeKind.projectsRemoved =>
        'убрано проектов: ${change.count}',
      PortfolioSnapshotChangeKind.projectsEdited =>
        'изменено проектов: ${change.count}',
      PortfolioSnapshotChangeKind.skillsAdded =>
        'добавлено навыков: ${change.count}',
      PortfolioSnapshotChangeKind.skillsRemoved =>
        'убрано навыков: ${change.count}',
      PortfolioSnapshotChangeKind.experience => 'изменён опыт',
      PortfolioSnapshotChangeKind.education => 'изменено образование',
      PortfolioSnapshotChangeKind.contacts => 'изменены контакты',
      PortfolioSnapshotChangeKind.layout => 'изменён порядок разделов',
    };

Widget _frame(BuildContext context, String title, Widget body) => Scaffold(
  appBar: AppBar(
    title: Text(title),
    leading: IconButton(
      tooltip: 'Назад',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
    ),
  ),
  body: SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: StackCardSize.contentMaxWidth,
        ),
        child: body is ListView ? body : SingleChildScrollView(child: body),
      ),
    ),
  ),
);

/// Список локальных версий: дата, числа и что изменилось. Только чтение.
class PortfolioHistoryScreen extends ConsumerWidget {
  const PortfolioHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(portfolioHistoryListProvider);
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return _frame(
      context,
      'История версий',
      history.when(
        loading: () => const StackCardStateView(
          kind: StackCardViewState.loading,
          title: 'Загрузка версий',
        ),
        error: (_, _) => StackCardStateView(
          kind: StackCardViewState.error,
          title: 'Не удалось загрузить версии',
          message: 'Попробуйте ещё раз. Сохранённое портфолио не затронуто.',
          onRetry: () => ref.invalidate(portfolioHistoryListProvider),
        ),
        data: (items) => items.isEmpty
            ? const StackCardStateView(
                kind: StackCardViewState.empty,
                title: 'Пока нет сохранённых версий',
                message: 'Версия появляется после каждого сохранения основного портфолио',
              )
            : ListView(
                key: const Key('history.list'),
                padding: const EdgeInsets.all(StackCardSpacing.lg),
                children: [
                  Text(
                    'Версии хранятся только на этом устройстве, последние $portfolioHistoryLimit',
                    style: text.bodySmall?.copyWith(color: colors.textMeta),
                  ),
                  const SizedBox(height: StackCardSpacing.md),
                  for (var index = 0; index < items.length; index++) ...[
                    _VersionTile(
                      snapshot: items[index],
                      previous: index + 1 < items.length
                          ? items[index + 1]
                          : null,
                    ),
                    const SizedBox(height: StackCardSpacing.md),
                  ],
                ],
              ),
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.snapshot, required this.previous});
  final PortfolioSnapshot snapshot;
  final PortfolioSnapshot? previous;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final summary = summarizePortfolioSnapshot(snapshot, previous: previous);
    final changes = summary.changes.isEmpty
        ? (previous == null ? 'первая версия' : 'без видимых изменений')
        : summary.changes.map(portfolioHistoryChange).join(', ');
    return InkWell(
      key: Key('history.item.${snapshot.id}'),
      borderRadius: BorderRadius.circular(StackCardRadius.large),
      onTap: () => context.push('/history/${snapshot.id}'),
      child: Ink(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(StackCardRadius.large),
        ),
        padding: const EdgeInsets.all(StackCardSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    portfolioHistoryDate(snapshot.savedAt),
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: StackCardSpacing.xs),
                  Text(
                    'Проектов: ${summary.projects} · Навыков: ${summary.skills}',
                    style: text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    changes,
                    style: text.bodySmall?.copyWith(color: colors.textMeta),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Просмотр версии в светлом виде документа и откат в буфер Editor.
class PortfolioHistoryVersionScreen extends ConsumerWidget {
  const PortfolioHistoryVersionScreen({super.key, required this.snapshotId});
  final String snapshotId;

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    PortfolioSnapshot snapshot,
  ) async {
    final unsaved = ref
        .read(portfolioDraftControllerProvider)
        .hasUnsavedChanges;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Восстановить версию'),
        content: Text(
          'Версия от ${portfolioHistoryDate(snapshot.savedAt)} откроется в Редакторе как несохранённые изменения. Нажмите «Сохранить», чтобы применить её; до этого сохранённое портфолио не меняется. Текущее фото останется.${unsaved ? ' Несохранённые правки в Редакторе будут заменены.' : ''}',
        ),
        actions: [
          StackCardDialogActions(
            cancelKey: const Key('history.restore.cancel'),
            confirmKey: const Key('history.restore.confirm'),
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
            confirmLabel: 'Восстановить',
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(mainPortfolioEditorRestoreProvider.notifier).request(snapshot);
    context.go('/editor');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(portfolioHistoryListProvider);
    final colors = context.colors;
    return _frame(
      context,
      'Версия',
      history.when(
        loading: () => const StackCardStateView(
          kind: StackCardViewState.loading,
          title: 'Загрузка версии',
        ),
        error: (_, _) => StackCardStateView(
          kind: StackCardViewState.error,
          title: 'Не удалось загрузить версию',
          onRetry: () => ref.invalidate(portfolioHistoryListProvider),
        ),
        data: (items) {
          final snapshot = items
              .where((item) => item.id == snapshotId)
              .firstOrNull;
          if (snapshot == null) {
            return const StackCardStateView(
              kind: StackCardViewState.empty,
              title: 'Версия не найдена',
              message: 'Возможно, она вытеснена более новыми',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(StackCardSpacing.lg),
            children: [
              Text(
                portfolioHistoryDate(snapshot.savedAt),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (snapshot.hasAvatar)
                Padding(
                  padding: const EdgeInsets.only(top: StackCardSpacing.xs),
                  child: Text(
                    'Фото в версии не хранится, при восстановлении останется текущее',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.textMeta),
                  ),
                ),
              const SizedBox(height: StackCardSpacing.lg),
              StackCardButton(
                key: const Key('history.restore'),
                label: 'Восстановить',
                role: StackCardButtonRole.primary,
                onPressed: () => _restore(context, ref, snapshot),
              ),
              const SizedBox(height: StackCardSpacing.lg),
              // Документ всегда светлый, как публичная страница.
              Theme(
                data: StackCardTheme.light,
                child: Builder(
                  builder: (context) => StackCardCard(
                    outlined: true,
                    child: MainPortfolioContentView(
                      content: portfolioSnapshotView(snapshot),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
