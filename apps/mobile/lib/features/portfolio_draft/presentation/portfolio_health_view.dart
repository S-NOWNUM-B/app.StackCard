import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_screen_header.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_health.dart';
import '../portfolio_health_providers.dart';
import 'portfolio_draft_controller.dart';

const _sectionTitles = {
  PortfolioHealthSection.profile: 'Профиль',
  PortfolioHealthSection.avatar: 'Фото',
  PortfolioHealthSection.projects: 'Проекты',
  PortfolioHealthSection.experience: 'Опыт',
  PortfolioHealthSection.education: 'Образование',
  PortfolioHealthSection.skills: 'Навыки',
  PortfolioHealthSection.contacts: 'Контакты',
  PortfolioHealthSection.publication: 'Публикация',
};

String portfolioHealthSectionTitle(PortfolioHealthSection section) =>
    _sectionTitles[section]!;

/// Текст совета; название проекта или навыка подставляется в кавычках.
String portfolioHealthTip(PortfolioHealthCheck check) {
  final target = '«${check.targetTitle ?? ''}»';
  return switch (check.kind) {
    PortfolioHealthCheckKind.profileName => 'Укажите имя',
    PortfolioHealthCheckKind.profileHeadline => 'Добавьте должность',
    PortfolioHealthCheckKind.profileBio => 'Расскажите о себе',
    PortfolioHealthCheckKind.avatar => 'Добавьте фото профиля',
    PortfolioHealthCheckKind.projectsAny => 'Добавьте хотя бы один проект',
    PortfolioHealthCheckKind.projectDescription =>
      'У проекта $target нет описания',
    PortfolioHealthCheckKind.projectTechnologies =>
      'У проекта $target не указаны технологии',
    PortfolioHealthCheckKind.projectLink => 'У проекта $target нет ссылки',
    PortfolioHealthCheckKind.projectInactive =>
      'Проект $target давно не обновлялся',
    PortfolioHealthCheckKind.experienceAny => 'Добавьте опыт работы',
    PortfolioHealthCheckKind.educationAny => 'Добавьте образование',
    PortfolioHealthCheckKind.skillsAny => 'Добавьте навыки',
    PortfolioHealthCheckKind.skillUnused =>
      'Навык $target не использован ни в одном проекте',
    PortfolioHealthCheckKind.contactsAny => 'Добавьте контакт для связи',
    PortfolioHealthCheckKind.published => 'Портфолио ещё не опубликовано',
  };
}

String _actionLabel(PortfolioHealthSection section) =>
    section == PortfolioHealthSection.publication
    ? 'Открыть Главную'
    : 'Открыть в Редакторе';

/// Каждый совет ведёт в нужный раздел Editor; публикация — на Главную.
void openPortfolioHealthSection(
  BuildContext context,
  WidgetRef ref,
  PortfolioHealthSection section,
) {
  if (section == PortfolioHealthSection.publication) {
    context.go('/home');
    return;
  }
  ref.read(mainPortfolioEditorFocusProvider.notifier).request(section);
  context.go('/editor');
}

/// Компактная карточка Home: счёт и переход к деталям. Только чтение.
class PortfolioHealthCard extends ConsumerWidget {
  const PortfolioHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(portfolioHealthProvider);
    if (health == null) return const SizedBox.shrink();
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final count = health.improvements.length;
    return Semantics(
      button: true,
      container: true,
      onTap: () => context.push('/health'),
      label:
          'Здоровье портфолио: ${health.score} из 100. ${health.isPerfect ? 'Всё в порядке' : 'Советов: $count'}',
      child: ExcludeSemantics(
        child: InkWell(
          key: const Key('home.health'),
          borderRadius: BorderRadius.circular(StackCardRadius.large),
          onTap: () => context.push('/health'),
          child: Ink(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(StackCardRadius.large),
            ),
            padding: const EdgeInsets.all(StackCardSpacing.lg),
            child: Row(
              children: [
                _ScoreRing(score: health.score, size: 56),
                const SizedBox(width: StackCardSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Здоровье портфолио', style: text.titleMedium),
                      const SizedBox(height: StackCardSpacing.xs),
                      Text(
                        health.isPerfect ? 'Всё в порядке' : 'Советов: $count',
                        style: text.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.size});
  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            key: const Key('health.ring'),
            child: CustomPaint(
              painter: _RingPainter(
                fraction: score / 100,
                track: colors.surfaceHover,
                color: score >= 80 ? colors.successText : colors.accentText,
              ),
            ),
          ),
          Text(
            '$score',
            key: const Key('health.score'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

/// Детали: общий балл, разделы и советы с переходом в Editor.
class PortfolioHealthScreen extends ConsumerWidget {
  const PortfolioHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(portfolioHealthProvider);
    final draft = ref.watch(portfolioDraftControllerProvider);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StackCardPageScaffold(
      title: 'Здоровье портфолио',
      body: health == null && (draft.loading || !draft.loaded)
          ? SingleChildScrollView(
              child: draft.failure != null && !draft.loading
                  ? StackCardStateView(
                      kind: StackCardViewState.error,
                      title: 'Не удалось прочитать портфолио',
                      onRetry: ref
                          .read(portfolioDraftControllerProvider.notifier)
                          .load,
                    )
                  : const StackCardStateView(
                      kind: StackCardViewState.loading,
                      title: 'Загрузка',
                    ),
            )
          : health == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(StackCardSpacing.xl),
                child: Text(
                  'Заполните и сохраните портфолио в Редакторе, чтобы увидеть оценку',
                  key: const Key('health.empty'),
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(StackCardSpacing.lg),
              children: [
                Row(
                  children: [
                    _ScoreRing(score: health.score, size: 72),
                    const SizedBox(width: StackCardSpacing.lg),
                    Expanded(
                      child: Text(
                        health.isPerfect
                            ? 'Отлично, советов нет'
                            : 'Советов: ${health.improvements.length}',
                        key: const Key('health.summary'),
                        style: text.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StackCardSpacing.xl),
                for (final section in PortfolioHealthSection.values)
                  if (health.sectionFraction(section) != null) ...[
                    _SectionRow(health: health, section: section),
                    const SizedBox(height: StackCardSpacing.md),
                  ],
                if (!health.isPerfect) ...[
                  const SizedBox(height: StackCardSpacing.md),
                  Text('Что улучшить', style: text.titleLarge),
                  const SizedBox(height: StackCardSpacing.md),
                  for (final check in health.improvements) ...[
                    StackCardCard(
                      outlined: true,
                      key: Key('health.tip.${check.section.name}.${check.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            portfolioHealthSectionTitle(check.section),
                            style: text.bodySmall?.copyWith(
                              color: colors.textMeta,
                            ),
                          ),
                          const SizedBox(height: StackCardSpacing.xs),
                          Text(
                            portfolioHealthTip(check),
                            style: text.titleSmall,
                          ),
                          const SizedBox(height: StackCardSpacing.md),
                          StackCardButton(
                            label: _actionLabel(check.section),
                            role: StackCardButtonRole.secondary,
                            onPressed: () => openPortfolioHealthSection(
                              context,
                              ref,
                              check.section,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: StackCardSpacing.md),
                  ],
                ],
              ],
            ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.health, required this.section});
  final PortfolioHealth health;
  final PortfolioHealthSection section;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fraction = health.sectionFraction(section)!;
    final ok = fraction == 1;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
          size: 20,
          color: ok ? colors.successText : colors.textSecondary,
        ),
        const SizedBox(width: StackCardSpacing.md),
        Expanded(child: Text(portfolioHealthSectionTitle(section))),
        Text(
          '${(fraction * 100).round()}%',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Кольцо счёта; не индикатор загрузки, поэтому рисуется отдельно.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.color,
  });
  final double fraction;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, 6.2832, false, paint..color = track);
    canvas.drawArc(
      arc,
      -1.5708,
      6.2832 * fraction,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.color != color;
}
