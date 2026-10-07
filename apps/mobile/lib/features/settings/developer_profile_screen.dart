import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../portfolio_draft/portfolio_draft.dart';

class DeveloperProfileScreen extends ConsumerStatefulWidget {
  const DeveloperProfileScreen({super.key, this.contactsOnly = false});
  final bool contactsOnly;
  @override
  ConsumerState<DeveloperProfileScreen> createState() =>
      _DeveloperProfileScreenState();
}

class _DeveloperProfileScreenState
    extends ConsumerState<DeveloperProfileScreen> {
  bool _leaving = false;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final controller = ref.read(portfolioDraftControllerProvider.notifier);
      try {
        await controller.ensureLoaded();
        if (mounted) controller.startBuilder();
      } on PortfolioDraftFailure {
        /* Ошибку показывает WorkspaceReadGate. */
      }
    });
  }

  bool get _dirty {
    final state = ref.read(portfolioDraftControllerProvider);
    return state.content != null &&
        developerProfileData(state.content!) !=
            developerProfileData(state.draft?.content ?? PortfolioContent());
  }

  Future<void> _leave() async {
    if (!_dirty) {
      _pop();
      return;
    }
    final capturedRepository = ref.read(portfolioDraftRepositoryProvider);
    final answer = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.tr('builder.unsaved')),
        content: Text(context.strings.tr('workspace.profileHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: Text(context.strings.tr('builder.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(context.strings.tr('builderForm.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(context.strings.tr('workspace.saveProfile')),
          ),
        ],
      ),
    );
    if (!mounted ||
        !identical(
          capturedRepository,
          ref.read(portfolioDraftRepositoryProvider),
        )) {
      return;
    }
    if (answer == 'save') {
      final saved = await ref
          .read(portfolioDraftControllerProvider.notifier)
          .saveDeveloperProfile(expectedRepository: capturedRepository);
      if (saved && mounted) {
        _pop();
      }
    } else if (answer == 'discard') {
      final state = ref.read(portfolioDraftControllerProvider);
      final base = state.draft?.content ?? PortfolioContent();
      final content = state.content;
      if (content != null) {
        ref
            .read(portfolioDraftControllerProvider.notifier)
            .updateContent(
              content.copyWith(
                profile: base.profile,
                skills: base.skills,
                experience: base.experience,
                education: base.education,
                links: base.links,
              ),
            );
      }
      _pop();
    }
  }

  void _pop() {
    setState(() => _leaving = true);
    // PopScope получает новую canPop перед выполнением programmatic pop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/settings');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioDraftControllerProvider);
    return PopScope(
      canPop: _leaving || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.strings.tr(
              widget.contactsOnly ? 'settings.contacts' : 'workspace.profile',
            ),
          ),
          leading: IconButton(
            tooltip: context.strings.tr('common.back'),
            onPressed: _leave,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: StackCardSize.contentMaxWidth,
              ),
              child: WorkspaceReadGate(
                data: (content) => ListView(
                  padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
                  children: [
                    Text(
                      context.strings.tr(
                        widget.contactsOnly
                            ? 'workspace.contactsHint'
                            : 'workspace.profileHint',
                      ),
                    ),
                    const SizedBox(height: StackCardSpacing.lg),
                    if (!widget.contactsOnly)
                      for (final item in [
                        (
                          'identity',
                          'builderForm.profileTitle',
                          content.profile.name,
                        ),
                        (
                          'skills',
                          'builderForm.skillsTitle',
                          '${content.skills.length}',
                        ),
                        (
                          'experience',
                          'builderForm.experienceTitle',
                          '${content.experience.length}',
                        ),
                        (
                          'education',
                          'builderForm.educationTitle',
                          '${content.education.length}',
                        ),
                      ])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.strings.tr(item.$2)),
                          subtitle: Text(item.$3),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: state.canEdit
                              ? () =>
                                    context.push('/settings/profile/${item.$1}')
                              : null,
                        ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.strings.tr('settings.contacts')),
                      subtitle: Text('${content.links.length}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: state.canEdit
                          ? () => context.push(
                              widget.contactsOnly
                                  ? '/settings/contacts/links'
                                  : '/settings/profile/links',
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(StackCardSpacing.lg),
            child: StackCardButton(
              key: const Key('workspace.saveProfile'),
              label: context.strings.tr('workspace.saveProfile'),
              primary: true,
              loading: state.saving,
              onPressed: state.canEdit && !state.saving && _dirty
                  ? () async {
                      final saved = await ref
                          .read(portfolioDraftControllerProvider.notifier)
                          .saveDeveloperProfile(
                            expectedRepository: ref.read(
                              portfolioDraftRepositoryProvider,
                            ),
                          );
                      if (saved && mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              this.context.strings.tr('workspace.saved'),
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
