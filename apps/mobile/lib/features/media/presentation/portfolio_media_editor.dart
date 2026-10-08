import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../auth/auth.dart';
import '../domain/portfolio_media.dart';
import '../media_providers.dart';
import 'portfolio_media_image.dart';

/// Upload меняет только состояние открытой формы. Apply и Save остаются явными.
class PortfolioMediaEditor extends ConsumerStatefulWidget {
  const PortfolioMediaEditor({
    super.key,
    required this.paths,
    required this.onChanged,
    required this.onBusyChanged,
    this.maxImages = 6,
    this.titleKey = 'media.projectImages',
    this.enabled = true,
    this.formNoteKey = 'media.formNote',
    this.emptyState,
  });

  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<bool> onBusyChanged;
  final int maxImages;
  final String titleKey;
  final bool enabled;
  final String formNoteKey;
  final Widget? emptyState;

  @override
  ConsumerState<PortfolioMediaEditor> createState() =>
      PortfolioMediaEditorState();
}

class PortfolioMediaEditorState extends ConsumerState<PortfolioMediaEditor> {
  final _created = <String, PortfolioMediaRepository>{};
  PreparedPortfolioImage? _prepared;
  PortfolioMediaFailureKind? _failure;
  PortfolioMediaRepository? _operationRepository;
  bool _busy = false;
  bool _picking = false;
  double _progress = 0;
  int _generation = 0;

  /// Родитель вызывает только после успешного применения paths к working draft.
  void retainUploads({Iterable<String>? paths}) {
    if (paths == null) {
      _created.clear();
    } else {
      for (final path in paths) {
        _created.remove(path);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    for (final entry in _created.entries) {
      entry.value.delete(entry.key).ignore();
    }
    super.dispose();
  }

  bool _current(PortfolioMediaRepository repository, int generation) =>
      mounted &&
      generation == _generation &&
      identical(repository, ref.read(portfolioMediaRepositoryProvider));

  void _setBusy(bool value, {bool picking = false}) {
    setState(() {
      _busy = value;
      _picking = picking;
    });
    widget.onBusyChanged(value);
  }

  Future<void> _pick(PortfolioImageSource source) async {
    final repository = ref.read(portfolioMediaRepositoryProvider);
    if (repository == null || _busy || !widget.enabled) return;
    final generation = ++_generation;
    _operationRepository = repository;
    _setBusy(true, picking: true);
    setState(() {
      _failure = null;
      _prepared = null;
      _progress = 0;
    });
    try {
      final picked = await ref.read(portfolioImagePickerProvider).pick(source);
      if (!_current(repository, generation)) return;
      if (picked == null) {
        _setBusy(false);
        return;
      }
      setState(() => _prepared = picked);
      await _upload(repository, generation);
    } on PortfolioMediaFailure catch (failure) {
      if (!_current(repository, generation)) return;
      setState(() => _failure = failure.kind);
      _setBusy(false);
    } catch (_) {
      if (!_current(repository, generation)) return;
      setState(() => _failure = PortfolioMediaFailureKind.unavailable);
      _setBusy(false);
    }
  }

  Future<void> _retry() async {
    final repository = _operationRepository;
    if (!widget.enabled ||
        repository == null ||
        _prepared == null ||
        _busy ||
        !identical(repository, ref.read(portfolioMediaRepositoryProvider))) {
      return;
    }
    final generation = ++_generation;
    _setBusy(true);
    await _upload(repository, generation);
  }

  Future<void> _upload(
    PortfolioMediaRepository repository,
    int generation,
  ) async {
    final prepared = _prepared;
    if (prepared == null) return;
    setState(() {
      _picking = false;
      _progress = 0;
      _failure = null;
    });
    try {
      final path = await repository.upload(
        prepared,
        onProgress: (value) {
          if (_current(repository, generation)) {
            setState(() => _progress = value.clamp(0.0, 1.0));
          }
        },
      );
      if (!_current(repository, generation)) {
        repository.delete(path).ignore();
        return;
      }
      if (!isPortfolioMediaPathForOwner(path, repository.ownerUid)) {
        throw const PortfolioMediaFailure(
          PortfolioMediaFailureKind.invalidImage,
        );
      }
      final replaced = widget.maxImages == 1 ? widget.paths : const <String>[];
      _created[path] = repository;
      widget.onChanged(
        List.unmodifiable([if (widget.maxImages != 1) ...widget.paths, path]),
      );
      for (final previous in replaced) {
        final createdRepository = _created.remove(previous);
        if (createdRepository != null) {
          createdRepository.delete(previous).ignore();
        }
      }
      setState(() => _prepared = null);
      _setBusy(false);
    } on PortfolioMediaFailure catch (failure) {
      if (!_current(repository, generation)) return;
      setState(() => _failure = failure.kind);
      _setBusy(false);
    } catch (_) {
      if (!_current(repository, generation)) return;
      setState(() => _failure = PortfolioMediaFailureKind.unavailable);
      _setBusy(false);
    }
  }

  void _remove(String path) {
    if (_busy || !widget.enabled) return;
    widget.onChanged(
      List.unmodifiable(widget.paths.where((item) => item != path)),
    );
    final repository = _created.remove(path);
    if (repository != null) repository.delete(path).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(portfolioMediaRepositoryProvider);
    ref.listen(portfolioMediaRepositoryProvider, (previous, next) {
      if (identical(previous, next)) return;
      _generation++;
      setState(() {
        _prepared = null;
        _operationRepository = null;
        _failure = null;
        _busy = false;
      });
      widget.onBusyChanged(false);
    });
    final canAdd =
        widget.enabled &&
        repository != null &&
        !_busy &&
        (widget.maxImages == 1 || widget.paths.length < widget.maxImages);
    final paths = repository == null
        ? const <String>[]
        : widget.paths
              .where(
                (path) =>
                    isPortfolioMediaPathForOwner(path, repository.ownerUid),
              )
              .toList();
    final isGuest = ref.watch(accountSessionProvider).value == null;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.strings.tr(widget.titleKey), style: text.titleMedium),
        const SizedBox(height: StackCardSpacing.sm),
        if (paths.isEmpty &&
            _prepared == null &&
            widget.emptyState != null) ...[
          widget.emptyState!,
          const SizedBox(height: StackCardSpacing.sm),
        ],
        if (paths.isNotEmpty || _prepared != null) ...[
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              for (final path in paths)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PortfolioMediaImage(path: path),
                    IconButton(
                      key: ValueKey('media_remove_$path'),
                      tooltip: context.strings.tr('media.remove'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _busy || !widget.enabled
                          ? null
                          : () => _remove(path),
                    ),
                  ],
                ),
              if (_prepared != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(StackCardRadius.small),
                  child: Image.memory(
                    _prepared!.bytes,
                    key: const ValueKey('media_prepared_preview'),
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 120,
                      height: 90,
                      child: Icon(Icons.image_outlined),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: StackCardSpacing.sm),
        ],
        Wrap(
          spacing: StackCardSpacing.sm,
          runSpacing: StackCardSpacing.sm,
          children: [
            StackCardButton(
              key: const ValueKey('media_gallery'),
              label: context.strings.tr('media.gallery'),
              iconWidget: const StackCardIcon(name: 'image', size: 18),
              onPressed: canAdd
                  ? () => _pick(PortfolioImageSource.gallery)
                  : null,
            ),
            StackCardButton(
              key: const ValueKey('media_camera'),
              label: context.strings.tr('media.camera'),
              iconWidget: const StackCardIcon(name: 'camera', size: 18),
              onPressed: canAdd
                  ? () => _pick(PortfolioImageSource.camera)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: StackCardSpacing.sm),
        Text(
          context.strings.tr(
            repository == null
                ? isGuest
                      ? 'media.guest'
                      : 'media.unconfigured'
                : widget.formNoteKey,
          ),
          style: text.bodySmall?.copyWith(color: context.colors.textMeta),
        ),
        if (widget.maxImages > 1)
          Text(
            context.strings.tr('media.limit', {'limit': widget.maxImages}),
            style: text.bodySmall?.copyWith(color: context.colors.textMeta),
          ),
        if (_busy) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              context.strings.tr(
                _picking ? 'media.preparing' : 'media.uploading',
                {'percent': (_progress * 100).round()},
              ),
            ),
          ),
          const SizedBox(height: StackCardSpacing.sm),
          LinearProgressIndicator(
            key: const ValueKey('media_upload_progress'),
            value: _picking ? null : _progress,
          ),
        ],
        if (_failure != null) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              context.strings.tr('media.${_failure!.name}'),
              key: const ValueKey('media_upload_error'),
              style: text.bodyMedium?.copyWith(color: context.colors.error),
            ),
          ),
          if (_prepared != null)
            Align(
              alignment: Alignment.centerLeft,
              child: StackCardButton(
                key: const ValueKey('media_retry'),
                label: context.strings.tr('common.retry'),
                onPressed: _busy || !widget.enabled ? null : _retry,
              ),
            ),
        ],
      ],
    );
  }
}
