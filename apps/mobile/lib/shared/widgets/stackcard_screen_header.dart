import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_tokens.dart';
import 'stackcard_icon.dart';

/// Единая шапка вторичного экрана: стрелка «назад», заголовок headlineSmall.
class StackCardScreenHeader extends StatelessWidget {
  const StackCardScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.fallbackPath = '/home',
  });

  final String title;
  final VoidCallback? onBack;

  /// Куда вести, если вернуться некуда.
  final String fallbackPath;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: StackCardSpacing.lg,
      vertical: StackCardSpacing.md,
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: context.strings.tr('common.back'),
          onPressed:
              onBack ??
              () => context.canPop() ? context.pop() : context.go(fallbackPath),
          icon: const StackCardIcon(name: 'arrow-left'),
        ),
        const SizedBox(width: StackCardSpacing.md),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Страница с единой шапкой; [body] занимает остальное место.
class StackCardPageScaffold extends StatelessWidget {
  const StackCardPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.fallbackPath = '/home',
    this.onBack,
    this.footer,
  });

  final String title;
  final Widget body;
  final String fallbackPath;
  final VoidCallback? onBack;

  /// Неподвижная панель внизу (действия, сообщения).
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: StackCardSize.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StackCardScreenHeader(
                title: title,
                onBack: onBack,
                fallbackPath: fallbackPath,
              ),
              Expanded(child: body),
              ?footer,
            ],
          ),
        ),
      ),
    ),
  );
}
