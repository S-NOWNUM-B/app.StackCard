import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    this.titleKey = 'media.avatar',
    this.enabled = true,
    this.emptyState,
    this.hasExternalAvatar = false,
  });

  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<bool> onBusyChanged;
  final String titleKey;
  final bool enabled;
  final Widget? emptyState;
  final bool hasExternalAvatar;

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
  List<String> _operationPaths = const [];
  bool _operationExternalAvatar = false;

  @override
  void didUpdateWidget(covariant PortfolioMediaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.paths, widget.paths) ||
        oldWidget.hasExternalAvatar != widget.hasExternalAvatar) {
      final wasBusy = _busy;
      _generation++;
      _busy = false;
      _prepared = null;
      _failure = null;
      _operationRepository = null;
      if (wasBusy) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onBusyChanged(false);
        });
      }
    }
  }

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
      listEquals(_operationPaths, widget.paths) &&
      _operationExternalAvatar == widget.hasExternalAvatar &&
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
    _operationPaths = List.of(widget.paths);
    _operationExternalAvatar = widget.hasExternalAvatar;
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
      final replaced = widget.paths;
      _created[path] = repository;
      setState(() => _prepared = null);
      _setBusy(false);
      widget.onChanged(List.unmodifiable([path]));
      for (final previous in replaced) {
        final createdRepository = _created.remove(previous);
        if (createdRepository != null) {
          createdRepository.delete(previous).ignore();
        }
      }
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

  Future<void> _menu(List<String> paths) async {
    final repository = ref.read(portfolioMediaRepositoryProvider);
    if (_busy || !widget.enabled || repository == null) return;
    final generation = _generation;
    final initialPaths = List.of(widget.paths);
    final initialExternalAvatar = widget.hasExternalAvatar;
    final selection = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('media_gallery'),
                leading: const StackCardIcon(name: 'image'),
                title: Text(context.strings.tr('media.gallery')),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                key: const ValueKey('media_camera'),
                leading: const StackCardIcon(name: 'camera'),
                title: Text(context.strings.tr('media.camera')),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              if (paths.isNotEmpty || widget.hasExternalAvatar)
                ListTile(
                  key: ValueKey(
                    'media_remove_${paths.isEmpty ? 'external' : paths.first}',
                  ),
                  leading: Icon(
                    Icons.delete_outline,
                    color: context.colors.error,
                  ),
                  title: Text(
                    context.strings.tr('media.remove'),
                    style: TextStyle(color: context.colors.error),
                  ),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    // Меню принадлежит тому owner и аватару, для которых оно было открыто.
    if (!mounted ||
        !widget.enabled ||
        generation != _generation ||
        !identical(repository, ref.read(portfolioMediaRepositoryProvider)) ||
        !listEquals(initialPaths, widget.paths) ||
        initialExternalAvatar != widget.hasExternalAvatar) {
      return;
    }
    if (selection == 'gallery') await _pick(PortfolioImageSource.gallery);
    if (selection == 'camera') await _pick(PortfolioImageSource.camera);
    if (selection == 'remove' && listEquals(paths, widget.paths)) {
      if (paths.isEmpty && widget.hasExternalAvatar) {
        widget.onChanged(const []);
      } else if (paths.isNotEmpty) {
        _remove(paths.first);
      }
    }
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
    final canAdd = widget.enabled && repository != null && !_busy;
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
        Text(
          context.strings.tr(widget.titleKey),
          style: text.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: StackCardSpacing.md),
        Center(
          child: Semantics(
            button: true,
            label: context.strings.tr('media.avatar'),
            child: SizedBox.square(
              dimension: 128,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Material(
                      color: context.colors.surfaceElevated,
                      shape: CircleBorder(
                        side: BorderSide(color: context.colors.borderStrong),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const ValueKey('media_avatar_edit'),
                        onTap: canAdd ? () => _menu(paths) : null,
                        child: IgnorePointer(
                          child: paths.isNotEmpty
                              ? PortfolioMediaImage(
                                  path: paths.first,
                                  width: 128,
                                  height: 128,
                                )
                              : _prepared != null
                              ? Image.memory(
                                  _prepared!.bytes,
                                  key: const ValueKey('media_prepared_preview'),
                                  width: 128,
                                  height: 128,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: StackCardIcon(
                                      name: 'user-round',
                                      size: 40,
                                    ),
                                  ),
                                )
                              : widget.emptyState ??
                                    const Center(
                                      child: StackCardIcon(
                                        name: 'user-round',
                                        size: 40,
                                      ),
                                    ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: context.colors.primary,
                      shape: CircleBorder(
                        side: BorderSide(
                          color: context.colors.surface,
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        key: const ValueKey('media_avatar_menu'),
                        tooltip: context.strings.tr('builderForm.edit'),
                        onPressed: canAdd ? () => _menu(paths) : null,
                        icon: StackCardIcon(
                          name: 'pencil',
                          size: 22,
                          color: context.colors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (repository == null) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            context.strings.tr(isGuest ? 'media.guest' : 'media.unconfigured'),
            style: text.bodySmall?.copyWith(color: context.colors.textMeta),
            textAlign: TextAlign.center,
          ),
        ],
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
              alignment: Alignment.center,
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
