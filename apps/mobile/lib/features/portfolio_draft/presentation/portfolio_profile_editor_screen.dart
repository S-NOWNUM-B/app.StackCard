import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../media/media.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft_repository.dart';
import '../portfolio_draft_providers.dart';
import 'builder_editor_widgets.dart';
import 'portfolio_draft_controller.dart';

class PortfolioProfileEditorScreen extends ConsumerStatefulWidget {
  const PortfolioProfileEditorScreen({super.key});

  @override
  ConsumerState<PortfolioProfileEditorScreen> createState() =>
      _PortfolioProfileEditorScreenState();
}

class _PortfolioProfileEditorScreenState
    extends ConsumerState<PortfolioProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  List<BuilderFieldSpec>? _fields;
  Map<String, TextEditingController>? _controllers;
  final _mediaKey = GlobalKey<PortfolioMediaEditorState>();
  List<String> _avatarPaths = const [];
  bool _mediaBusy = false;
  PortfolioDraftRepository? _initialRepository;

  @override
  void dispose() {
    disposeBuilderFieldControllers(_controllers);
    super.dispose();
  }

  void _initialize(PortfolioProfile profile) {
    if (_fields != null) return;
    _initialRepository = ref.read(portfolioDraftRepositoryProvider);
    _avatarPaths = profile.avatarPath.isEmpty ? const [] : [profile.avatarPath];
    _fields ??= [
      BuilderFieldSpec(
        name: 'name',
        labelKey: 'builderForm.name',
        value: profile.name,
        maxLength: 100,
      ),
      BuilderFieldSpec(
        name: 'username',
        labelKey: 'builderForm.username',
        hintKey: 'builderForm.usernameHint',
        value: profile.username,
        maxLength: 30,
        kind: BuilderFieldKind.username,
      ),
      BuilderFieldSpec(
        name: 'headline',
        labelKey: 'builderForm.headline',
        value: profile.headline,
        maxLength: 160,
      ),
      BuilderFieldSpec(
        name: 'bio',
        labelKey: 'builderForm.bio',
        value: profile.bio,
        maxLength: 4000,
        kind: BuilderFieldKind.multiline,
      ),
      BuilderFieldSpec(
        name: 'locationText',
        labelKey: 'builderForm.location',
        value: profile.locationText,
        maxLength: 200,
      ),
      BuilderFieldSpec(
        name: 'avatarUrl',
        labelKey: 'builderForm.avatarUrl',
        value: profile.avatarUrl,
        maxLength: 2048,
        kind: BuilderFieldKind.url,
      ),
    ];
    _controllers ??= builderFieldControllers(_fields!);
  }

  void _apply() {
    if (_mediaBusy ||
        !identical(
          _initialRepository,
          ref.read(portfolioDraftRepositoryProvider),
        )) {
      return;
    }
    if (_formKey.currentState?.validate() != true) return;
    final state = ref.read(portfolioDraftControllerProvider);
    final current = state.content;
    if (!state.canEdit || current == null) return;
    final values = builderFieldValues(_controllers!);
    ref
        .read(portfolioDraftControllerProvider.notifier)
        .updateContent(
          current.copyWith(
            profile: current.profile.copyWith(
              name: values['name'],
              username: values['username'],
              headline: values['headline'],
              bio: values['bio'],
              locationText: values['locationText'],
              avatarUrl: values['avatarUrl'],
              avatarPath: _avatarPaths.firstOrNull ?? '',
            ),
          ),
        );
    _mediaKey.currentState?.retainUploads();
    closeBuilderEditor(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    final ownerChanged =
        _initialRepository != null &&
        !identical(_initialRepository, repository);
    return BuilderEditorScaffold(
      titleKey: 'builderForm.profileTitle',
      onApply:
          state.canEdit && state.content != null && !_mediaBusy && !ownerChanged
          ? _apply
          : null,
      child: BuilderContentGate(
        data: (content) {
          if (ownerChanged) {
            return Text(context.strings.tr('media.ownerChanged'));
          }
          _initialize(content.profile);
          return Padding(
            padding: EdgeInsets.zero,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PortfolioMediaEditor(
                    key: _mediaKey,
                    titleKey: 'media.avatar',
                    maxImages: 1,
                    paths: _avatarPaths,
                    onChanged: (paths) => setState(() => _avatarPaths = paths),
                    onBusyChanged: (busy) => setState(() => _mediaBusy = busy),
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
                  BuilderFields(
                    fields: _fields!,
                    controllers: _controllers!,
                    onSubmit: _apply,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
