import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/state/appearance_controller.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../../shared/widgets/stackcard_async_view.dart';
import '../profile/profile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StackCardViewState _previewState = StackCardViewState.empty;
  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppearanceController, ThemeMode>(
      (controller) => controller.themeMode,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width >= 700 ? 24 : 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StackCardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Внешний вид',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Выберите комфортную тему. Она действует до закрытия приложения.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in [
                          (
                            mode: ThemeMode.dark,
                            title: 'Тёмная',
                            icon: Icons.dark_mode_outlined,
                          ),
                          (
                            mode: ThemeMode.light,
                            title: 'Светлая',
                            icon: Icons.light_mode_outlined,
                          ),
                          (
                            mode: ThemeMode.system,
                            title: 'Системная',
                            icon: Icons.brightness_auto_outlined,
                          ),
                        ])
                          ChoiceChip(
                            avatar: Icon(item.icon, size: 18),
                            label: Text(item.title),
                            selected: themeMode == item.mode,
                            onSelected: (_) {
                              context.read<AppearanceController>().setThemeMode(
                                item.mode,
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StackCardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Демонстрационный аккаунт',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    riverpod.Consumer(
                      builder: (context, ref, _) => StackCardAsyncView(
                        state: ref.watch(profileProvider),
                        onRetry: () => ref.invalidate(profileProvider),
                        data: (profile) => Text(
                          '${profile.name} · ${profile.handle}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Профиль, проекты и показатели — примеры. GitHub, уведомления и публикация будут подключены на следующих этапах.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    StackCardButton(
                      label: 'Вернуться ко входу',
                      icon: Icons.logout_rounded,
                      onPressed: () => context.go('/sign-in'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StackCardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Состояния интерфейса',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Примеры загрузки, пустого списка и ошибки.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in [
                          (
                            state: StackCardViewState.loading,
                            label: 'Загрузка',
                          ),
                          (state: StackCardViewState.empty, label: 'Пусто'),
                          (state: StackCardViewState.error, label: 'Ошибка'),
                        ])
                          ChoiceChip(
                            label: Text(item.label),
                            selected: _previewState == item.state,
                            onSelected: (_) =>
                                setState(() => _previewState = item.state),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    StackCardStateView(
                      kind: _previewState,
                      title: switch (_previewState) {
                        StackCardViewState.loading => 'Загружаем проекты',
                        StackCardViewState.empty =>
                          'Здесь появятся ваши проекты',
                        StackCardViewState.error =>
                          'Не удалось загрузить проекты',
                      },
                      message: switch (_previewState) {
                        StackCardViewState.loading =>
                          'Пример состояния ожидания.',
                        StackCardViewState.empty => 'Добавьте первый проект, когда будет доступен редактор.',
                        StackCardViewState.error =>
                          'Пример ошибки. Повтор открывает пустое состояние.',
                      },
                      onRetry: _previewState == StackCardViewState.error
                          ? () => setState(
                              () => _previewState = StackCardViewState.empty,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
