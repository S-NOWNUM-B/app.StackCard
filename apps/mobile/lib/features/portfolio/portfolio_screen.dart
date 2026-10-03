import 'package:flutter/material.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/mock_portfolio.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pageTextColor = Theme.of(context).brightness == Brightness.light
        ? context.colors.textPrimary
        : context.colors.textSecondary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 760 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.7;
        return SingleChildScrollView(
          padding: EdgeInsets.all(
            constraints.maxWidth >= 700
                ? StackCardSpacing.xl
                : StackCardSpacing.lg,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Моё портфолио',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    'Профиль, проекты и детали, которые расскажут о тебе.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: pageTextColor),
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(flex: 7, child: _ProfileCard()),
                        const SizedBox(width: StackCardSpacing.lg),
                        Expanded(flex: 4, child: _DraftCard()),
                      ],
                    )
                  else ...[
                    const _ProfileCard(),
                    const SizedBox(height: StackCardSpacing.lg),
                    _DraftCard(),
                  ],
                  const SizedBox(height: StackCardSpacing.xl),
                  Text(
                    'Блоки портфолио',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  if (wide)
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: [
                              _AboutCard(),
                              SizedBox(height: StackCardSpacing.lg),
                              _FeaturedCard(),
                            ],
                          ),
                        ),
                        SizedBox(width: StackCardSpacing.lg),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _SkillsCard(),
                              SizedBox(height: StackCardSpacing.lg),
                              _StoryCard(),
                              SizedBox(height: StackCardSpacing.lg),
                              _LinksCard(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    const _AboutCard(),
                    const SizedBox(height: StackCardSpacing.lg),
                    const _SkillsCard(),
                    const SizedBox(height: StackCardSpacing.lg),
                    const _FeaturedCard(),
                    const SizedBox(height: StackCardSpacing.lg),
                    const _StoryCard(),
                    const SizedBox(height: StackCardSpacing.lg),
                    const _LinksCard(),
                  ],
                  const SizedBox(height: StackCardSpacing.xl),
                  Text(
                    'Это макет на демонстрационных данных. Редактирование '
                    'профиля, порядок блоков, резюме и публикация будут '
                    'подключаться по плану разработки.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: pageTextColor),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(StackCardRadius.large),
                  border: Border.all(color: context.colors.border),
                ),
                child: Text(
                  DemoPortfolio.initials,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: StackCardSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DemoPortfolio.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: StackCardSpacing.xs),
                    Text(
                      '@${DemoPortfolio.handle}',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Text(
            DemoPortfolio.role,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: StackCardSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 20,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: StackCardSpacing.sm),
              Expanded(
                child: Text(
                  DemoPortfolio.location,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Text(
            'Открыт к интересным задачам',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: StackCardSpacing.xs),
          Text(
            'Демонстрационный профиль',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: StackCardSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.visibility_off_outlined,
                size: 20,
                color: context.colors.textSecondary,
              ),
              Text('Черновик', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            'Только для тебя',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            'Предпросмотр показывает пример будущей страницы. '
            'Этот профиль не опубликован.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          StackCardButton(
            label: 'Предпросмотр',
            icon: Icons.visibility_outlined,
            primary: true,
            onPressed: () => _showPreview(context),
          ),
          const SizedBox(height: StackCardSpacing.md),
          Text(
            'Публикация станет доступна после подключения аккаунта и облака.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('01 / Обо мне', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            DemoPortfolio.about,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard();

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('02 / Навыки', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StackCardSpacing.lg),
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              for (final skill in DemoPortfolio.skills)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StackCardSpacing.md,
                    vertical: StackCardSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(StackCardRadius.small),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Text(
                    skill,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard();

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '03 / Избранные проекты',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.lg),
          for (final project in DemoPortfolio.projects.where(
            (project) => project.featured,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: StackCardSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(
                        StackCardRadius.medium,
                      ),
                    ),
                    child: Text(
                      project.symbol,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: StackCardSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: StackCardSpacing.xs),
                        Text(
                          project.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard();

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '04 / Опыт и обучение',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            'Frontend Developer',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.xs),
          Text(
            'Studio Example · 2024–2026',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Divider(color: context.colors.borderSubtle),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            'Software Engineering',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.xs),
          Text(
            'Пример учебного профиля · 2023–2027',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            'Все записи в этом блоке демонстрационные.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LinksCard extends StatelessWidget {
  const _LinksCard();

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '05 / Ссылки и резюме',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            'Профиль GitHub',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.xs),
          Text(
            'В демо ссылка не подключена',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text('Резюме', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StackCardSpacing.xs),
          Text(
            'Файл пока не добавлен',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

void _showPreview(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          StackCardSpacing.xl,
          StackCardSpacing.sm,
          StackCardSpacing.xl,
          StackCardSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Предпросмотр портфолио',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: StackCardSpacing.sm),
            Text(
              'Демо · черновик не опубликован',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: StackCardSpacing.xl),
            const _ProfileCard(),
            const SizedBox(height: StackCardSpacing.lg),
            const _AboutCard(),
            const SizedBox(height: StackCardSpacing.lg),
            const _SkillsCard(),
            const SizedBox(height: StackCardSpacing.lg),
            const _FeaturedCard(),
            const SizedBox(height: StackCardSpacing.lg),
            const _StoryCard(),
            const SizedBox(height: StackCardSpacing.lg),
            const _LinksCard(),
            const SizedBox(height: StackCardSpacing.xl),
            StackCardButton(
              label: 'Закрыть предпросмотр',
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
