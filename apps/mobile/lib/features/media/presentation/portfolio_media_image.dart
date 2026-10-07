import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../domain/portfolio_media.dart';
import '../media_providers.dart';

/// Private media читается по UID-bound path, без публичного download URL.
class PortfolioMediaImage extends ConsumerWidget {
  const PortfolioMediaImage({
    super.key,
    required this.path,
    this.width = 120,
    this.height = 90,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  final String path;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(portfolioMediaRepositoryProvider);
    final allowed =
        repository != null &&
        isPortfolioMediaPathForOwner(path, repository.ownerUid);
    final placeholder =
        fallback ??
        Icon(Icons.image_outlined, color: context.colors.textSecondary);
    return Semantics(
      label: context.strings.tr('media.imageLabel'),
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(StackCardRadius.small),
          child: ColoredBox(
            color: context.colors.surfaceElevated,
            child: !allowed
                ? Center(child: placeholder)
                : ref
                      .watch(portfolioMediaBytesProvider(path))
                      .when(
                        skipLoadingOnRefresh: false,
                        skipLoadingOnReload: false,
                        data: (bytes) => Image.memory(
                          bytes,
                          key: ValueKey((repository.ownerUid, path)),
                          width: width,
                          height: height,
                          fit: fit,
                          gaplessPlayback: false,
                          errorBuilder: (_, _, _) => _failure(context, ref),
                        ),
                        loading: () => const Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (_, _) => _failure(context, ref),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _failure(BuildContext context, WidgetRef ref) => Center(
    child: IconButton(
      tooltip:
          '${context.strings.tr('media.imageError')}. ${context.strings.tr('common.retry')}',
      icon: const Icon(Icons.refresh_rounded),
      onPressed: () => ref.invalidate(portfolioMediaBytesProvider(path)),
    ),
  );
}
