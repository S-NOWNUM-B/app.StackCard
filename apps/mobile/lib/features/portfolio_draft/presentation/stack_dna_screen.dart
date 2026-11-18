import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_screen_header.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/stack_dna.dart';
import '../stack_dna_providers.dart';
import 'portfolio_draft_controller.dart';

const _alphas = [1.0, .78, .58, .42, .3, .2];

/// Цвет сегмента по месту в рейтинге; «Другие» — нейтральный.
Color _segmentColor(BuildContext context, int rank, {bool other = false}) {
  final colors = context.colors;
  if (other) return colors.surfaceHover;
  return colors.primary.withValues(alpha: _alphas[rank.clamp(0, 5)]);
}

String stackDnaPercent(double share) =>
    share > 0 && share < .005 ? '<1%' : '${(share * 100).round()}%';

String _years(StackDnaShare item) {
  if (item.firstYear == null) return '';
  return item.firstYear == item.lastYear
      ? ' · активность ${item.firstYear}'
      : ' · активность ${item.firstYear}–${item.lastYear}';
}

String _projectsWord(int count) {
  final mod10 = count % 10, mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return 'проект';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'проекта';
  }
  return 'проектов';
}

/// Текстовое описание диаграммы для скринридера.
String stackDnaDescription(StackDna dna) {
  final top = dna.shares
      .map((item) => '${item.label} ${stackDnaPercent(item.share)}')
      .join(', ');
  final years = dna.years.where((year) => year.hasData).length;
  return 'Доли технологий: $top. Лет с данными: $years';
}

/// «ДНК стека»: карта технологий по проектам портфолио. Только чтение.
class StackDnaScreen extends ConsumerWidget {
  const StackDnaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final dna = ref.watch(stackDnaProvider);
    Widget body;
    if (dna == null) {
      body = state.failure != null && !state.loading
          ? StackCardStateView(
              kind: StackCardViewState.error,
              title: 'Не удалось прочитать портфолио',
              onRetry: ref.read(portfolioDraftControllerProvider.notifier).load,
            )
          : const StackCardStateView(
              kind: StackCardViewState.loading,
              title: 'Загрузка',
            );
      body = SingleChildScrollView(child: body);
    } else if (dna.isEmpty) {
      body = SingleChildScrollView(
        child: Column(
          children: [
            const StackCardStateView(
              key: Key('dna.empty'),
              kind: StackCardViewState.empty,
              title: 'Пока нечего показывать',
              message: 'Подключите GitHub или добавьте технологии в проекты',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StackCardSpacing.lg,
              ),
              child: StackCardButton(
                key: const Key('dna.import'),
                label: 'Импорт из GitHub',
                onPressed: () => context.push('/github-import'),
              ),
            ),
          ],
        ),
      );
    } else {
      body = _Content(dna: dna);
    }
    return StackCardPageScaffold(
      title: 'ДНК стека',
      fallbackPath: '/projects',
      body: body,
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.dna});
  final StackDna dna;

  int _rank(String id) => dna.all.indexWhere((item) => item.id == id);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const Key('dna.list'),
      padding: const EdgeInsets.all(StackCardSpacing.lg),
      children: [
        Semantics(
          label: stackDnaDescription(dna),
          child: ExcludeSemantics(
            child: _Bar(
              key: const Key('dna.bar'),
              segments: [
                for (final (index, item) in dna.shares.indexed)
                  (
                    flex: (item.share * 1000).round().clamp(1, 1000),
                    color: _segmentColor(context, index, other: item.isOther),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: StackCardSpacing.md),
        if (dna.isLowData)
          Padding(
            padding: const EdgeInsets.only(bottom: StackCardSpacing.md),
            child: Text(
              'Данных мало: ${dna.projectCount} ${_projectsWord(dna.projectCount)} с технологиями. Выводы появятся от $stackDnaEnoughProjects проектов',
              key: const Key('dna.lowData'),
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
        if (!dna.isLowData) ...[
          Semantics(
            header: true,
            child: Text('Главный стек', style: text.titleMedium),
          ),
          const SizedBox(height: StackCardSpacing.xs),
          Text(
            dna.mainStack.map(dna.labelOf).join(', '),
            key: const Key('dna.main'),
            style: text.bodyLarge,
          ),
          if (dna.rising.isNotEmpty) ...[
            const SizedBox(height: StackCardSpacing.md),
            Semantics(
              header: true,
              child: Text('Растёт доля', style: text.titleMedium),
            ),
            const SizedBox(height: StackCardSpacing.xs),
            Text(
              dna.rising.map(dna.labelOf).join(', '),
              key: const Key('dna.rising'),
              style: text.bodyLarge,
            ),
          ],
          const SizedBox(height: StackCardSpacing.lg),
        ],
        Semantics(
          header: true,
          child: Text('Технологии', style: text.titleMedium),
        ),
        const SizedBox(height: StackCardSpacing.sm),
        for (final (index, item) in dna.all.indexed)
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(bottom: StackCardSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 10),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _segmentColor(
                          context,
                          index,
                          other: index >= stackDnaTopCount,
                        ),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: colors.controlOutline),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          key: Key('dna.item.${item.id}'),
                          style: text.bodyLarge,
                        ),
                        Text(
                          '${item.count} ${_projectsWord(item.count)}${_years(item)}',
                          style: text.bodySmall?.copyWith(
                            color: colors.textMeta,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: StackCardSpacing.sm),
                  Text(stackDnaPercent(item.share), style: text.titleSmall),
                ],
              ),
            ),
          ),
        if (dna.years.isNotEmpty) ...[
          const SizedBox(height: StackCardSpacing.xl),
          Semantics(
            header: true,
            child: Text(
              'По годам последней активности',
              style: text.titleMedium,
            ),
          ),
          const SizedBox(height: StackCardSpacing.sm),
          for (final year in dna.years)
            Padding(
              padding: const EdgeInsets.only(bottom: StackCardSpacing.sm),
              child: Semantics(
                label: year.hasData
                    ? '${year.year}: ${year.counts.entries.map((e) => '${dna.labelOf(e.key)} — ${e.value} ${_projectsWord(e.value)}').join(', ')}'
                    : '${year.year}: нет данных',
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      SizedBox(
                        width:
                            48 *
                            MediaQuery.textScalerOf(context)
                                .scale(1)
                                .clamp(1, 2),
                        child: Text(
                          '${year.year}',
                          softWrap: false,
                          style: text.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: year.hasData
                            ? _Bar(
                                key: Key('dna.year.${year.year}'),
                                height: 14,
                                segments: [
                                  for (final entry
                                      in (year.counts.entries.toList()..sort(
                                        (a, b) =>
                                            _rank(a.key)
                                                .compareTo(_rank(b.key)),
                                      )))
                                    (
                                      flex: entry.value,
                                      color: _segmentColor(
                                        context,
                                        _rank(entry.key),
                                        other:
                                            _rank(entry.key) >=
                                            stackDnaTopCount,
                                      ),
                                    ),
                                ],
                              )
                            : Text(
                                'нет данных',
                                key: Key('dna.year.${year.year}.empty'),
                                style: text.bodySmall?.copyWith(
                                  color: colors.textMeta,
                                ),
                              ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          year.hasData ? '${year.total}' : '',
                          textAlign: TextAlign.end,
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        if (dna.undatedCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: StackCardSpacing.sm),
            child: Text(
              'Проектов без даты: ${dna.undatedCount}, в годах они не показаны',
              style: text.bodySmall?.copyWith(color: colors.textMeta),
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.segments, this.height = 24});
  final List<({int flex, Color color})> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          // stretch: без него ColoredBox без child схлопывается до высоты 0.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, segment) in segments.indexed) ...[
                // Зазор между сегментами: различимость не только по оттенку.
                if (index > 0)
                  ColoredBox(
                    color: colors.background,
                    child: const SizedBox(width: 2),
                  ),
                Expanded(
                  flex: segment.flex,
                  child: ColoredBox(color: segment.color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
