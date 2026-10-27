import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_avatar.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_dialog_actions.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../media/media.dart';
import '../../portfolio_draft/portfolio_draft.dart';
import '../auth_providers.dart';
import 'auth_controller.dart';

/// Прогресс и введённые значения сохраняются в прежнем UID-bound workspace.
class PersonalizationScreen extends ConsumerWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountAuthRepositoryProvider);
    final session = ref.watch(accountSessionProvider);
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    final ready = session.hasValue && !session.isLoading && !session.hasError;
    return _PersonalizationBody(
      key: ValueKey((account, session.value?.uid, repository, ready)),
    );
  }
}

class _PersonalizationBody extends ConsumerStatefulWidget {
  const _PersonalizationBody({super.key});

  @override
  ConsumerState<_PersonalizationBody> createState() =>
      _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<_PersonalizationBody> {
  final _form = GlobalKey<FormState>();
  final _media = GlobalKey<PortfolioMediaEditorState>();
  final _github = TextEditingController();
  final _name = TextEditingController();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();
  late final String? _ownerUid;
  late final PortfolioDraftRepository _repository;
  PortfolioProfile _profile = const PortfolioProfile();
  String _avatarPath = '';
  String _savedGithub = '';
  int _step = 0;
  bool _loading = true;
  bool _ready = false;
  bool _saving = false;
  bool _mediaBusy = false;
  bool _avatarChanged = false;
  bool _confirming = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _ownerUid = ref.read(accountSessionProvider).value?.uid;
    _repository = ref.read(portfolioDraftRepositoryProvider);
    Future<void>.microtask(_load);
  }

  bool get _current =>
      mounted &&
      _ownerUid != null &&
      !ref.read(accountSessionProvider).isLoading &&
      !ref.read(accountSessionProvider).hasError &&
      ref.read(accountSessionProvider).value?.uid == _ownerUid &&
      identical(_repository, ref.read(portfolioDraftRepositoryProvider));

  @override
  void dispose() {
    _github.dispose();
    _name.dispose();
    _headline.dispose();
    _bio.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current) return;
    setState(() {
      _loading = true;
      _failure = null;
    });
    final controller = ref.read(portfolioDraftControllerProvider.notifier);
    try {
      await controller.ensureLoaded();
      if (!mounted || !_current) return;
      if (ref.read(pendingPersonalizationUidProvider) == _ownerUid) {
        final initialized = await controller.initializeMainPortfolio(
          newAccount: true,
          expectedRepository: _repository,
        );
        if (!mounted || !_current) return;
        if (!initialized) {
          throw const PortfolioDraftFailure(
            PortfolioDraftFailureKind.unavailable,
          );
        }
        ref
            .read(pendingPersonalizationUidProvider.notifier)
            .complete(_ownerUid!);
      }
      final workspace = ref
          .read(portfolioDraftControllerProvider)
          .draft
          ?.content;
      if (workspace == null) {
        throw const PortfolioDraftFailure(
          PortfolioDraftFailureKind.unavailable,
        );
      }
      if (workspace.personalization.status !=
          PortfolioPersonalizationStatus.inProgress) {
        context.go('/home');
        return;
      }
      final main = mainPortfolioDocument(workspace);
      if (main == null) {
        throw const PortfolioDraftFailure(
          PortfolioDraftFailureKind.invalidContent,
        );
      }
      _profile = main.content.profile;
      _avatarPath = _profile.avatarPath;
      _savedGithub = workspace.githubUsername;
      _github.text = _savedGithub;
      _name.text = _profile.name;
      _headline.text = _profile.headline;
      _bio.text = _profile.bio;
      _location.text = _profile.locationText;
      setState(() {
        _step = workspace.personalization.step;
        _avatarChanged = false;
        _loading = false;
        _ready = true;
      });
    } catch (_) {
      if (!_current) return;
      setState(() {
        _failure = 'Не удалось загрузить персонализацию';
        _loading = false;
      });
    }
  }

  String? _length(String? value, int limit) =>
      (value?.length ?? 0) > limit ? 'Не больше $limit символов' : null;

  PortfolioProfile _enteredProfile() {
    return switch (_step) {
      1 => _profile.copyWith(
        name: _name.text.trim(),
        headline: _headline.text.trim(),
        locationText: _location.text.trim(),
        publishLocation: _location.text.trim() == _profile.locationText
            ? _profile.publishLocation
            : _location.text.trim().isNotEmpty,
      ),
      2 => _profile.copyWith(bio: _bio.text.trim()),
      3 => _profile.copyWith(
        avatarPath: _avatarPath,
        avatarUrl: _avatarChanged ? '' : _profile.avatarUrl,
      ),
      _ => _profile,
    };
  }

  Future<void> _save({bool back = false}) async {
    if (!_current ||
        _saving ||
        _mediaBusy ||
        !(_form.currentState?.validate() ?? true)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final target = back ? _step - 1 : (_step + 1).clamp(0, 3);
    final completed = !back && _step == 3;
    final entered = _enteredProfile();
    final github = _step == 0
        ? normalizePortfolioGitHubUsername(_github.text)
        : null;
    setState(() {
      _saving = true;
      _failure = null;
    });
    // CAS может записать captured owner после закрытия экрана. Такое фото уже
    // нельзя удалять через dispose; при неудаче retry использует те же bytes.
    if (_step == 3) {
      _media.currentState?.retainUploads(paths: [entered.avatarPath]);
    }
    try {
      final success = await ref
          .read(portfolioDraftControllerProvider.notifier)
          .savePersonalizationStep(
            step: target,
            status: completed
                ? PortfolioPersonalizationStatus.completed
                : PortfolioPersonalizationStatus.inProgress,
            profile: _step == 0 ? null : entered,
            githubUsername: github,
            expectedRepository: _repository,
          );
      if (!mounted || !_current) return;
      if (!success) {
        setState(() {
          _saving = false;
          _failure =
              'Не удалось сохранить. Введённые данные сохранены на экране';
        });
        return;
      }
      _media.currentState?.retainUploads(paths: [entered.avatarPath]);
      _profile = entered;
      _avatarChanged = false;
      _name.text = _profile.name;
      _headline.text = _profile.headline;
      _bio.text = _profile.bio;
      _location.text = _profile.locationText;
      if (_step == 0) {
        _savedGithub = github!;
        _github.text = _savedGithub;
      }
      if (completed) {
        context.go('/home');
      } else {
        setState(() {
          _step = target;
          _saving = false;
        });
      }
    } catch (_) {
      if (!_current) return;
      setState(() {
        _saving = false;
        _failure = 'Не удалось сохранить. Попробуйте ещё раз';
      });
    }
  }

  bool get _hasInputChanges =>
      _github.text.trim() != _savedGithub ||
      _name.text.trim() != _profile.name ||
      _headline.text.trim() != _profile.headline ||
      _bio.text.trim() != _profile.bio ||
      _location.text.trim() != _profile.locationText ||
      _avatarChanged;

  Future<void> _leave() async {
    if (_confirming || _saving || _mediaBusy || !_current) return;
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Отменить изменения?'),
        content: const Text(
          'Вы вернётесь к последнему сохранённому состоянию этого шага',
        ),
        actions: [
          StackCardDialogActions(
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    _confirming = false;
    if (mounted && _current && discard == true) {
      await _load();
    }
  }

  Widget _fields(bool busy) => switch (_step) {
    0 => StackCardInput(
      key: const Key('personalization.github'),
      label: 'GitHub-профиль',
      hint: 'https://github.com/username',
      controller: _github,
      enabled: !busy,
      keyboardType: TextInputType.url,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) =>
          normalizePortfolioGitHubUsername(value ?? '') == null
          ? 'Введите имя пользователя или ссылку вида https://github.com/username'
          : null,
      onChanged: (_) => setState(() {}),
    ),
    1 => Column(
      children: [
        StackCardInput(
          key: const Key('personalization.name'),
          label: 'Имя',
          controller: _name,
          enabled: !busy,
          textInputAction: TextInputAction.next,
          validator: (value) => _length(value, 100),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: StackCardSpacing.lg),
        StackCardInput(
          key: const Key('personalization.headline'),
          label: 'Должность',
          controller: _headline,
          enabled: !busy,
          textInputAction: TextInputAction.next,
          validator: (value) => _length(value, 160),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: StackCardSpacing.lg),
        StackCardInput(
          key: const Key('personalization.location'),
          label: 'Город / страна',
          controller: _location,
          enabled: !busy,
          validator: (value) => _length(value, 200),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    2 => StackCardInput(
      key: const Key('personalization.bio'),
      label: 'Краткое описание',
      controller: _bio,
      enabled: !busy,
      minLines: 3,
      maxLines: 5,
      keyboardType: TextInputType.multiline,
      validator: (value) => _length(value, 4000),
      onChanged: (_) => setState(() {}),
    ),
    _ => PortfolioMediaEditor(
      key: _media,
      paths: _avatarPath.isEmpty ? const [] : [_avatarPath],
      titleKey: 'media.avatar',
      hasExternalAvatar: !_avatarChanged && _profile.avatarUrl.isNotEmpty,
      emptyState: !_avatarChanged && _profile.avatarUrl.isNotEmpty
          ? StackCardAvatar(url: _profile.avatarUrl, size: 128, initials: '')
          : null,
      enabled: !busy,
      onChanged: (paths) {
        if (!_current) {
          return;
        }
        setState(() {
          _avatarPath = paths.isEmpty ? '' : paths.single;
          _avatarChanged = true;
        });
      },
      onBusyChanged: (value) {
        if (_current) {
          setState(() => _mediaBusy = value);
        }
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    ref.watch(accountSessionProvider);
    final busy = _saving || _mediaBusy;
    return PopScope(
      canPop: !_hasInputChanges && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hasInputChanges) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Персонализация'),
          automaticallyImplyLeading: false,
        ),
        body: !_current || _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(StackCardSpacing.lg),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          (constraints.maxHeight - 2 * StackCardSpacing.lg)
                              .clamp(0, double.infinity),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: StackCardSize.contentMaxWidth,
                        ),
                        child: !_ready
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_failure!, textAlign: TextAlign.center),
                                  const SizedBox(height: StackCardSpacing.lg),
                                  StackCardButton(
                                    label: 'Повторить',
                                    onPressed: _load,
                                  ),
                                ],
                              )
                            : Form(
                                key: _form,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Шаг ${_step + 1} из 4',
                                      key: const Key('personalization.step'),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: context.colors.textMeta,
                                          ),
                                    ),
                                    const SizedBox(height: StackCardSpacing.sm),
                                    Text(
                                      const [
                                        'GitHub',
                                        'Имя и должность',
                                        'О себе',
                                        'Фотография',
                                      ][_step],
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    const SizedBox(height: StackCardSpacing.xl),
                                    _fields(busy),
                                    if (_failure != null) ...[
                                      const SizedBox(
                                        height: StackCardSpacing.lg,
                                      ),
                                      Text(
                                        _failure!,
                                        style: TextStyle(
                                          color: context.colors.error,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: StackCardSpacing.xl),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: StackCardButton(
                                            key: const Key(
                                              'personalization.back',
                                            ),
                                            label: 'Назад',
                                            onPressed: busy || _step == 0
                                                ? null
                                                : () => _save(back: true),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: StackCardSpacing.sm,
                                        ),
                                        Expanded(
                                          child: StackCardButton(
                                            key: const Key(
                                              'personalization.next',
                                            ),
                                            label: _step == 3
                                                ? context.strings.tr(
                                                    'common.finish',
                                                  )
                                                : 'Далее',
                                            loading: _saving,
                                            onPressed: busy ? null : _save,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
