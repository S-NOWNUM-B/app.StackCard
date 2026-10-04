import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../domain/portfolio_sync.dart';
import '../portfolio_draft_providers.dart';

class PortfolioSyncStatusView extends ConsumerWidget {
  const PortfolioSyncStatusView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioSyncStateProvider);
    final repository = ref.watch(portfolioSyncRepositoryProvider);
    final strings = context.strings;
    final colors = context.colors;
    final (icon, color) = switch (state.status) {
      PortfolioSyncStatus.localOnly => (
        Icons.phone_android,
        colors.textSecondary,
      ),
      PortfolioSyncStatus.loading => (
        Icons.cloud_outlined,
        colors.textSecondary,
      ),
      PortfolioSyncStatus.pending => (
        Icons.cloud_upload_outlined,
        colors.textSecondary,
      ),
      PortfolioSyncStatus.synced => (Icons.cloud_done_outlined, colors.success),
      PortfolioSyncStatus.error => (Icons.cloud_off_outlined, colors.error),
    };
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: StackCardSpacing.sm),
              Expanded(
                child: Text(
                  strings.tr('sync.${state.status.name}'),
                  key: const ValueKey('portfolio_sync_status'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (state.status == PortfolioSyncStatus.error) ...[
            const SizedBox(height: StackCardSpacing.sm),
            Text(
              strings.tr(
                'sync.error.${state.failure?.kind.name ?? 'unavailable'}',
              ),
            ),
          ],
          if (repository != null &&
              (state.status == PortfolioSyncStatus.error ||
                  state.status == PortfolioSyncStatus.pending)) ...[
            const SizedBox(height: StackCardSpacing.sm),
            StackCardButton(
              key: const ValueKey('portfolio_sync_retry'),
              label: strings.tr('sync.retry'),
              icon: Icons.refresh_rounded,
              onPressed: () => unawaited(repository.retry()),
            ),
          ],
        ],
      ),
    );
  }
}
