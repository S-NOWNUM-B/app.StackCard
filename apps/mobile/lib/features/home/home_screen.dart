import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/mock_portfolio.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                    'Привет, Alex',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    'Твои проекты. Твоя история. Один StackCard.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: pageTextColor),
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(flex: 7, child: _ProfileHero()),
                        const SizedBox(width: StackCardSpacing.lg),
                        const Expanded(flex: 4, child: _ReadinessCard()),
                      ],
                    )
                  else ...[
                    const _ProfileHero(),
                    const SizedBox(height: StackCardSpacing.lg),
                    const _ReadinessCard(),
                  ],
                  const SizedBox(height: StackCardSpacing.xl),
                  const _SectionHeading(
                    title: 'На первом плане',
                    subtitle: 'Избранный проект демонстрационного портфолио',
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(flex: 7, child: _FeaturedProject()),
                        const SizedBox(width: StackCardSpacing.lg),
                        const Expanded(flex: 4, child: _WorkspaceCard()),
                      ],
                    )
                  else ...[
                    const _FeaturedProject(),
                    const SizedBox(height: StackCardSpacing.lg),
                    const _WorkspaceCard(),
                  ],
                  const SizedBox(height: StackCardSpacing.xl),
                  StackCardCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: StackCardSpacing.md),
                        Expanded(
                          child: Text(
                            'Сейчас это демо интерфейса. Все проекты, навыки '
                            'и показатели — примеры. Аккаунт, GitHub sync '
                            'и публикация появятся на следующих этапах.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero();

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEVELOPER PORTFOLIO',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: StackCardSpacing.xl),
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
                      DemoPortfolio.role,
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
            'Идеи становятся\nработающими продуктами.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: StackCardSpacing.md),
          Text(
            'Собери лучшее из того, что создаёшь, и покажи свой подход к работе.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Wrap(
            spacing: StackCardSpacing.md,
            runSpacing: StackCardSpacing.md,
            children: [
              StackCardButton(
                label: 'Моё портфолио',
                icon: Icons.arrow_forward_rounded,
                primary: true,
                onPressed: () => context.push('/portfolio'),
              ),
              StackCardButton(
                label: 'Проекты',
                icon: Icons.grid_view_rounded,
                onPressed: () => context.push('/projects'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard();

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.donut_large_rounded,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: StackCardSpacing.sm),
              Expanded(
                child: Text(
                  'Готовность профиля',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Text('80%', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            'Пример заполнения · 4 из 5 блоков',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Semantics(
            label: 'Демонстрационное заполнение профиля: 80 процентов',
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(StackCardRadius.small),
                child: LinearProgressIndicator(
                  value: DemoPortfolio.completion,
                  minHeight: 6,
                  color: context.colors.accent,
                  backgroundColor: context.colors.surfaceHover,
                ),
              ),
            ),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Divider(color: context.colors.borderSubtle),
          const SizedBox(height: StackCardSpacing.md),
          const _CompactInfo(
            icon: Icons.visibility_off_outlined,
            title: 'Черновик',
            description: 'Не опубликован',
          ),
          const SizedBox(height: StackCardSpacing.lg),
          const _CompactInfo(
            icon: Icons.add_link_rounded,
            title: 'Публичная ссылка',
            description: 'Появится после публикации',
          ),
        ],
      ),
    );
  }
}

class _FeaturedProject extends StatelessWidget {
  const _FeaturedProject();

  @override
  Widget build(BuildContext context) {
    final project = DemoPortfolio.projects.first;
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(StackCardSpacing.xl),
            decoration: BoxDecoration(
              color: context.colors.surfaceElevated,
              borderRadius: BorderRadius.circular(StackCardRadius.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: StackCardSpacing.sm,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.colors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: StackCardSpacing.xl),
                Text(
                  'A / ATLAS',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: StackCardSpacing.sm),
                Text(
                  'Less noise. More craft.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: StackCardSpacing.xl),
                Wrap(
                  spacing: StackCardSpacing.sm,
                  runSpacing: StackCardSpacing.sm,
                  children: [
                    for (final label in ['Components', 'Typography', 'Themes'])
                      _Tag(label: label),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(project.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            project.description,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          StackCardButton(
            label: 'Смотреть проекты',
            icon: Icons.arrow_outward_rounded,
            onPressed: () => context.push('/projects'),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard();

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'В твоём workspace',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: StackCardSpacing.xl),
          const _CompactInfo(
            icon: Icons.layers_outlined,
            title: '4 проекта',
            description: '2 featured · демонстрационные данные',
          ),
          const SizedBox(height: StackCardSpacing.xl),
          const _CompactInfo(
            icon: Icons.code_rounded,
            title: '8 навыков',
            description: 'Мобильная и веб-разработка',
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Divider(color: context.colors.borderSubtle),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            'GitHub пока не подключён',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            'После подключения ты сможешь выбирать репозитории для портфолио. '
            'Сейчас здесь показаны примеры импортированных карточек.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  const _CompactInfo({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: context.colors.textSecondary),
        const SizedBox(width: StackCardSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: StackCardSpacing.xs),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: StackCardSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).brightness == Brightness.light
                ? context.colors.textPrimary
                : context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StackCardSpacing.md,
        vertical: StackCardSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(StackCardRadius.small),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
