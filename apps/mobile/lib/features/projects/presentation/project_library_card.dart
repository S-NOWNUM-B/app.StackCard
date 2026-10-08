import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_technology_badge.dart';
import '../../media/media.dart';
import '../../portfolio_draft/portfolio_draft.dart';

/// Общая композиция ProjectListItem 185:2771 для Home и Projects.
/// Открытие, полный список технологий и Copy имеют отдельные hit areas.
class ProjectLibraryCard extends StatefulWidget {
  const ProjectLibraryCard({
    super.key,
    required this.title,
    required this.description,
    required this.technologies,
    required this.sourceLabel,
    this.imagePaths = const [],
    this.updatedAt,
    this.liveUrl = '',
    this.onOpen,
    this.openKey,
    this.onShowTechnologies,
    this.showActions = true,
  });

  final String title;
  final String description;
  final List<String> technologies;
  final String sourceLabel;
  final List<String> imagePaths;
  final DateTime? updatedAt;
  final String liveUrl;
  final VoidCallback? onOpen;
  final Key? openKey;
  final VoidCallback? onShowTechnologies;
  final bool showActions;

  @override
  State<ProjectLibraryCard> createState() => _ProjectLibraryCardState();
}

class _ProjectLibraryCardState extends State<ProjectLibraryCard> {
  bool _copied = false;
  bool _copying = false;
  int _copyGeneration = 0;

  @override
  void didUpdateWidget(ProjectLibraryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liveUrl != widget.liveUrl) {
      _copyGeneration++;
      _copied = false;
      _copying = false;
    }
  }

  Future<void> _copy() async {
    if (_copying ||
        widget.liveUrl.isEmpty ||
        validatePortfolioUrl(widget.liveUrl) != null) {
      return;
    }
    final generation = ++_copyGeneration;
    final url = widget.liveUrl.trim();
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted || generation != _copyGeneration) return;
      setState(() {
        _copied = true;
        _copying = false;
      });
    } catch (_) {
      if (!mounted || generation != _copyGeneration) return;
      setState(() => _copying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.tr('mobileParity.copyFailed'))),
      );
    }
  }

  void _showTechnologies() {
    if (widget.onShowTechnologies != null) {
      widget.onShowTechnologies!();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(
        maxWidth: StackCardSize.contentMaxWidth,
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.strings.tr('mobileParity.allTechnologies'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: StackCardSpacing.lg),
            Wrap(
              spacing: StackCardSpacing.sm,
              runSpacing: StackCardSpacing.sm,
              children: [
                for (final technology in widget.technologies)
                  StackCardTechnologyBadge(label: technology),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final validUrl =
        widget.liveUrl.isNotEmpty &&
        validatePortfolioUrl(widget.liveUrl) == null;
    return StackCardCard(
      outlined: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: widget.openKey,
            borderRadius: BorderRadius.circular(StackCardRadius.large),
            onTap: widget.onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProjectLibraryCover(imagePaths: widget.imagePaths),
                Padding(
                  padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.title, style: text.titleLarge),
                      if (widget.description.isNotEmpty) ...[
                        const SizedBox(height: StackCardSpacing.md),
                        Text(
                          widget.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: StackCardSpacing.md),
                      Text(
                        widget.sourceLabel,
                        style: text.bodySmall?.copyWith(
                          color: colors.sourceText,
                        ),
                      ),
                      if (widget.updatedAt != null) ...[
                        const SizedBox(height: StackCardSpacing.md),
                        Text(
                          workspaceDate(context, widget.updatedAt),
                          style: text.bodySmall?.copyWith(
                            color: colors.textMeta,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.technologies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StackCardSpacing.cardPadding,
              ),
              child: Wrap(
                spacing: StackCardSpacing.sm,
                runSpacing: StackCardSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final technology in widget.technologies.take(4))
                    StackCardTechnologyBadge(label: technology),
                  if (widget.technologies.length > 4)
                    StackCardMoreTechnologies(
                      count: widget.technologies.length - 4,
                      label: context.strings.tr('project.moreTechnologies', {
                        'count': widget.technologies.length - 4,
                      }),
                      onPressed: _showTechnologies,
                    ),
                ],
              ),
            ),
          if (widget.showActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                StackCardSpacing.cardPadding,
                StackCardSpacing.sm,
                StackCardSpacing.cardPadding,
                StackCardSpacing.cardPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      context.strings.tr(
                        validUrl
                            ? 'mobileParity.demoLink'
                            : 'mobileParity.noLinkHint',
                      ),
                      style: text.bodySmall?.copyWith(color: colors.textMeta),
                    ),
                  ),
                  const SizedBox(width: StackCardSpacing.sm),
                  Flexible(
                    child: StackCardButton(
                      label: context.strings.tr(
                        !validUrl
                            ? 'mobileParity.noLink'
                            : _copied
                            ? 'mobileParity.copied'
                            : 'mobileParity.copy',
                      ),
                      iconWidget: validUrl
                          ? StackCardIcon(
                              name: _copied ? 'check' : 'copy',
                              size: 20,
                            )
                          : null,
                      iconSize: 20,
                      onPressed: validUrl ? _copy : null,
                      loading: _copying,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: StackCardSpacing.cardPadding),
        ],
      ),
    );
  }
}

class ProjectLibraryCover extends StatelessWidget {
  const ProjectLibraryCover({super.key, required this.imagePaths});
  final List<String> imagePaths;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: context.colors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(StackCardSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StackCardIcon(
              name: 'image',
              size: 24,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: StackCardSpacing.sm),
            Flexible(
              child: Text(
                context.strings.tr('project.noImage'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(StackCardRadius.large),
      ),
      child: SizedBox(
        height: 104,
        width: double.infinity,
        child: imagePaths.isEmpty
            ? placeholder
            : PortfolioMediaImage(
                path: imagePaths.first,
                width: double.infinity,
                height: 104,
                fallback: placeholder,
              ),
      ),
    );
  }
}
