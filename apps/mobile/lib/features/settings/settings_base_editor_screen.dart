import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';
import '../../shared/widgets/stackcard_icon.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../auth/auth.dart';
import '../media/media.dart';
import '../location/location.dart';
import '../portfolio_draft/portfolio_draft.dart';
import 'settings_editor_scaffold.dart';

enum SettingsBaseSection { profile, contacts, privacy }

class SettingsProfileScreen extends SettingsBaseEditorScreen {
  const SettingsProfileScreen({super.key})
    : super(section: SettingsBaseSection.profile);
}

class SettingsContactsScreen extends SettingsBaseEditorScreen {
  const SettingsContactsScreen({super.key})
    : super(section: SettingsBaseSection.contacts);
}

class SettingsPrivacyScreen extends SettingsBaseEditorScreen {
  const SettingsPrivacyScreen({super.key})
    : super(section: SettingsBaseSection.privacy);
}

/// Буфер настроек не меняет draft до scoped Save; Cancel отбрасывает только его.
class SettingsBaseEditorScreen extends ConsumerStatefulWidget {
  const SettingsBaseEditorScreen({super.key, required this.section});
  final SettingsBaseSection section;
  @override
  ConsumerState<SettingsBaseEditorScreen> createState() =>
      _SettingsBaseEditorScreenState();
}

class _SettingsBaseEditorScreenState
    extends ConsumerState<SettingsBaseEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _media = GlobalKey<PortfolioMediaEditorState>();
  Map<String, TextEditingController>? _fields;
  PortfolioContent? _data;
  PortfolioContent? _initial;
  PortfolioContent? _expected;
  PortfolioDraftRepository? _repository;
  (Object?, String?, bool, bool)? _initialOwner;
  bool _saving = false,
      _mediaBusy = false,
      _saved = false,
      _allowPop = false,
      _ownerInvalid = false;
  String? _error;
  String? _emailId, _phoneId;
  bool _emailAllowed = false, _phoneAllowed = false;
  String _tr(String key) => context.strings.tr('settingsManagement.$key');
  bool get _dirty => _data != null && _buffer() != _initial;
  (Object?, String?, bool, bool) _owner({bool watch = false}) {
    final account = watch
        ? ref.watch(accountAuthRepositoryProvider)
        : ref.read(accountAuthRepositoryProvider);
    if (account == null) return (null, null, true, true);
    final session = watch
        ? ref.watch(accountSessionProvider)
        : ref.read(accountSessionProvider);
    final guest = watch
        ? ref.watch(guestAccessProvider)
        : ref.read(guestAccessProvider);
    final ready = session.hasValue && !session.isLoading && !session.hasError;
    return (account, ready ? session.value?.uid : null, ready && guest, ready);
  }

  bool get _sameOwner =>
      !_ownerInvalid &&
      _initialOwner == _owner() &&
      identical(_repository, ref.read(portfolioDraftRepositoryProvider));
  void _initialize(PortfolioContent content) {
    _repository = ref.read(portfolioDraftRepositoryProvider);
    _initialOwner = _owner();
    _data = _initial = developerProfileData(content);
    _expected = developerProfileData(
      ref.read(portfolioDraftControllerProvider).draft?.content ??
          PortfolioContent(),
    );
    final profile = content.profile;
    final email = content.links
        .where((link) => link.kind == SocialLinkKind.email)
        .firstOrNull;
    final phone = content.links
        .where((link) => link.kind == SocialLinkKind.phone)
        .firstOrNull;
    _emailId =
        email?.id ??
        ref.read(portfolioDraftControllerProvider.notifier).createId();
    _phoneId =
        phone?.id ??
        ref.read(portfolioDraftControllerProvider.notifier).createId();
    _emailAllowed = email?.publishAllowed ?? false;
    _phoneAllowed = phone?.publishAllowed ?? false;
    _fields = {
      for (final field in {
        'name': profile.name,
        'username': profile.username,
        'headline': profile.headline,
        'bio': profile.bio,
        'locationText': profile.locationText,
        'contactEmail': email?.url.replaceFirst('mailto:', '') ?? '',
        'contactPhone': phone?.url.replaceFirst('tel:', '') ?? '',
      }.entries)
        field.key: TextEditingController(text: field.value)
          ..addListener(_changed),
    };
  }

  void _changed() {
    if (mounted) {
      setState(() {
        _saved = false;
        _error = null;
      });
    }
  }

  void _update(PortfolioContent data) {
    if (!_sameOwner || _saving) return;
    setState(() {
      _data = data;
      _saved = false;
      _error = null;
    });
  }

  PortfolioContent _buffer() => _data!.copyWith(
    links: widget.section == SettingsBaseSection.contacts
        ? _contactBuffer()
        : _data!.links,
    profile: _data!.profile.copyWith(
      name: _fields!['name']!.text.trim(),
      username: _fields!['username']!.text.trim(),
      headline: _fields!['headline']!.text.trim(),
      bio: _fields!['bio']!.text.trim(),
      locationText: _fields!['locationText']!.text.trim(),
    ),
  );
  List<SocialLink> _contactBuffer() {
    var links = [..._data!.links];
    for (final (kind, id, field, allowed, scheme) in [
      (
        SocialLinkKind.email,
        _emailId!,
        'contactEmail',
        _emailAllowed,
        'mailto:',
      ),
      (SocialLinkKind.phone, _phoneId!, 'contactPhone', _phoneAllowed, 'tel:'),
    ]) {
      final raw = _fields![field]!.text.trim();
      final existing = links.where((link) => link.id == id).firstOrNull;
      if (raw.isEmpty) {
        links.removeWhere((link) => link.id == id);
        continue;
      }
      final value = SocialLink(
        id: id,
        label: existing?.label ?? _tr('kind.${kind.name}'),
        url: '$scheme$raw',
        kind: kind,
        publishAllowed: allowed,
        visible: existing?.visible ?? true,
      );
      links = [
        for (final link in links)
          if (link.id == id) value else link,
        if (existing == null) value,
      ];
    }
    return links;
  }

  @override
  void dispose() {
    for (final field in _fields?.values ?? <TextEditingController>[]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _mediaBusy) return;
    if (_dirty && _sameOwner) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_tr('discardTitle')),
          content: Text(_tr('discardHint')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.strings.tr('account.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr('discard')),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
    }
    setState(() => _allowPop = true);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  Future<void> _save() async {
    if (!_sameOwner ||
        _saving ||
        _mediaBusy ||
        _form.currentState?.validate() != true) {
      return;
    }
    final data = _buffer();
    setState(() {
      _saving = true;
      _error = null;
    });
    final success = await ref
        .read(portfolioDraftControllerProvider.notifier)
        .saveDeveloperProfile(
          expectedRepository: _repository!,
          profileData: data,
          expectedProfileData: _expected!,
        );
    if (!mounted || !_sameOwner) return;
    setState(() {
      _saving = false;
      if (success) {
        _data = _initial = _expected = data;
        _saved = true;
      } else {
        _error =
            ref.read(portfolioDraftControllerProvider).failure?.kind ==
                PortfolioDraftFailureKind.conflict
            ? 'conflict'
            : 'saveError';
      }
    });
    if (success) _media.currentState?.retainUploads();
  }

  Future<void> _reload() async {
    if (_saving || _mediaBusy || !_sameOwner) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_tr('discardTitle')),
          content: Text(_tr('discardHint')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.strings.tr('account.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr('reload')),
            ),
          ],
        ),
      );
      if (!mounted || !_sameOwner || discard != true) return;
    }
    final state = ref.read(portfolioDraftControllerProvider);
    final content = state.draft?.content ?? PortfolioContent();
    for (final field in _fields!.values) {
      field.dispose();
    }
    setState(() {
      _fields = null;
      _initialize(content);
      _error = null;
      _saved = false;
    });
  }

  Future<void> _location() async {
    if (!_sameOwner || _saving) return;
    final result = await Navigator.of(context).push<PortfolioPlace>(
      MaterialPageRoute(
        builder: (_) => PortfolioLocationPicker(
          currentLocation: _fields!['locationText']!.text,
          isActive: () => mounted && _sameOwner && !_saving,
        ),
      ),
    );
    if (!mounted || !_sameOwner || result == null || !result.isValid) return;
    _fields!['locationText']!.text = result.displayText;
  }

  Future<void> _link([SocialLink? existing]) async {
    if (!_sameOwner || _saving) return;
    final id =
        existing?.id ??
        ref.read(portfolioDraftControllerProvider.notifier).createId();
    final link = await showDialog<SocialLink>(
      context: context,
      builder: (_) => _ContactDialog(link: existing, id: id),
    );
    if (!mounted || !_sameOwner || link == null) return;
    _update(
      _data!.copyWith(
        links: [
          for (final item in _data!.links)
            if (item.id == id) link else item,
          if (existing == null) link,
        ],
      ),
    );
  }

  Future<void> _remove(SocialLink link) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('removeLink')),
        content: Text(_tr('removeHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.tr('account.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.tr('builderForm.delete')),
          ),
        ],
      ),
    );
    if (!mounted || !_sameOwner || confirm != true) return;
    _update(
      _data!.copyWith(
        links: _data!.links.where((item) => item.id != link.id).toList(),
      ),
    );
  }

  void _move(int index, int offset) {
    final links = [..._data!.links];
    final positions = [
      for (final (position, link) in links.indexed)
        if (link.id != _emailId && link.id != _phoneId) position,
    ];
    final target = index + offset;
    if (target < 0 || target >= positions.length) return;
    final originPosition = positions[index];
    final targetPosition = positions[target];
    final original = links[originPosition];
    links[originPosition] = links[targetPosition];
    links[targetPosition] = original;
    _update(_data!.copyWith(links: links));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    final owner = _owner(watch: true);
    if (_data != null &&
        (_initialOwner != owner || !identical(_repository, repository))) {
      _ownerInvalid = true;
      _data = null;
      for (final field in _fields!.values) {
        field.removeListener(_changed);
        field.clear();
      }
    }
    if (_data == null && !_ownerInvalid && state.loaded && state.canEdit) {
      // Собственный буфер начинается с durable базы и не сохраняет соседний
      // unsaved ввод legacy Builder при Save контактов или приватности.
      _initialize(state.draft?.content ?? PortfolioContent());
    }
    final title = switch (widget.section) {
      SettingsBaseSection.profile => context.strings.tr('workspace.profile'),
      SettingsBaseSection.contacts => _tr('contacts'),
      SettingsBaseSection.privacy => context.strings.tr('settings.privacy'),
    };
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: SettingsEditorScaffold(
        title: title,
        onBack: _close,
        footer: _data == null
            ? null
            : SettingsSaveBar(
                status: _error != null
                    ? _tr(_error!)
                    : _saved
                    ? _tr('saved')
                    : _dirty
                    ? _tr('unsaved')
                    : _tr('unchanged'),
                saving: _saving,
                onCancel: _saving || _mediaBusy ? null : _close,
                onSave: _dirty && !_saving && !_mediaBusy && _sameOwner
                    ? _save
                    : null,
              ),
        child: _ownerInvalid
            ? Text(_tr('ownerChanged'))
            : _data == null
            ? StackCardStateView(
                kind: state.failure == null
                    ? StackCardViewState.loading
                    : StackCardViewState.error,
                title: context.strings.tr(
                  state.failure == null ? 'draft.loading' : 'draft.readFailure',
                ),
                message: context.strings.tr(
                  state.failure == null
                      ? 'draft.loadingMessage'
                      : 'draft.unavailable',
                ),
                onRetry: state.failure == null
                    ? null
                    : () => ref
                          .read(portfolioDraftControllerProvider.notifier)
                          .load(),
              )
            : Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error == 'conflict') ...[
                      StackCardButton(label: _tr('reload'), onPressed: _reload),
                      const SizedBox(height: StackCardSpacing.lg),
                    ],
                    AbsorbPointer(
                      absorbing: _saving,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: switch (widget.section) {
                          SettingsBaseSection.profile => _profile(),
                          SettingsBaseSection.contacts => _contacts(),
                          SettingsBaseSection.privacy => _privacy(),
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _profile() => [
    PortfolioMediaEditor(
      key: _media,
      titleKey: 'media.avatar',
      maxImages: 1,
      paths: _data!.profile.avatarPath.isEmpty
          ? const []
          : [_data!.profile.avatarPath],
      onChanged: (paths) => _update(
        _data!.copyWith(
          profile: _data!.profile.copyWith(avatarPath: paths.firstOrNull ?? ''),
        ),
      ),
      onBusyChanged: (busy) => setState(() => _mediaBusy = busy),
    ),
    const SizedBox(height: StackCardSpacing.lg),
    for (final field in [
      ('name', 'builderForm.name', 100),
      ('username', 'builderForm.username', 30),
      ('headline', 'builderForm.headline', 160),
      ('bio', 'builderForm.bio', 4000),
      ('locationText', 'builderForm.location', 200),
    ]) ...[
      TextFormField(
        key: Key('settings.profile.${field.$1}'),
        controller: _fields![field.$1],
        maxLength: field.$3,
        maxLines: field.$1 == 'bio' ? 4 : 1,
        decoration: InputDecoration(labelText: context.strings.tr(field.$2)),
        validator: (value) =>
            field.$1 == 'username' &&
                value!.isNotEmpty &&
                validatePortfolioUsername(value) != null
            ? context.strings.tr('builderForm.invalidUsername')
            : null,
      ),
      const SizedBox(height: StackCardSpacing.lg),
    ],
    StackCardButton(
      label: context.strings.tr('location.pick'),
      onPressed: _location,
    ),
    const SizedBox(height: StackCardSpacing.lg),
    Text(
      context.strings.tr('documentEditor.qualifications'),
      style: Theme.of(context).textTheme.titleLarge,
    ),
    _QualificationEditor(content: _data!, onChanged: _update),
  ];
  List<Widget> _contacts() => [
    Text(_tr('contactsHint')),
    const SizedBox(height: StackCardSpacing.lg),
    TextFormField(
      key: const Key('settings.contacts.email'),
      controller: _fields!['contactEmail'],
      keyboardType: TextInputType.emailAddress,
      maxLength: 254,
      decoration: InputDecoration(
        labelText: _tr('publicEmail'),
        helperText: _tr('publicEmailHint'),
        helperMaxLines: 8,
        counterText: '',
      ),
      validator: (value) =>
          value!.trim().isEmpty ||
              validatePortfolioContactUrl(
                    'mailto:${value.trim()}',
                    SocialLinkKind.email,
                  ) ==
                  null
          ? null
          : _tr('invalidContact'),
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_tr('emailPermission')),
      value: _emailAllowed,
      onChanged: _fields!['contactEmail']!.text.trim().isEmpty
          ? null
          : (value) => setState(() {
              _emailAllowed = value!;
              _saved = false;
            }),
    ),
    const SizedBox(height: StackCardSpacing.lg),
    TextFormField(
      key: const Key('settings.contacts.phone'),
      controller: _fields!['contactPhone'],
      keyboardType: TextInputType.phone,
      maxLength: 16,
      decoration: InputDecoration(
        labelText: _tr('kind.phone'),
        helperText: _tr('phoneHint'),
        helperMaxLines: 8,
        counterText: '',
      ),
      validator: (value) =>
          value!.trim().isEmpty ||
              validatePortfolioContactUrl(
                    'tel:${value.trim()}',
                    SocialLinkKind.phone,
                  ) ==
                  null
          ? null
          : _tr('invalidContact'),
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_tr('phonePermission')),
      value: _phoneAllowed,
      onChanged: _fields!['contactPhone']!.text.trim().isEmpty
          ? null
          : (value) => setState(() {
              _phoneAllowed = value!;
              _saved = false;
            }),
    ),
    const SizedBox(height: StackCardSpacing.lg),
    Text(_tr('links'), style: Theme.of(context).textTheme.titleLarge),
    for (final (index, link)
        in _data!.links
            .where((link) => link.id != _emailId && link.id != _phoneId)
            .indexed) ...[
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const StackCardIcon(name: 'user-round'),
        title: Text(link.label),
        subtitle: Text(link.url),
        onTap: () => _link(link),
        trailing: Transform.rotate(
          angle: -1.5708,
          child: const StackCardIcon(name: 'chevron-down'),
        ),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_tr('publishAllowed')),
        value: link.publishAllowed,
        onChanged: (value) => _update(
          _data!.copyWith(
            links: [
              for (final item in _data!.links)
                item.id == link.id
                    ? item.copyWith(publishAllowed: value!)
                    : item,
            ],
          ),
        ),
      ),
      Row(
        children: [
          IconButton(
            tooltip: _tr('up'),
            onPressed: index == 0 ? null : () => _move(index, -1),
            icon: const StackCardIcon(name: 'arrow-up'),
          ),
          IconButton(
            tooltip: _tr('down'),
            onPressed:
                index ==
                    _data!.links
                            .where(
                              (link) =>
                                  link.id != _emailId && link.id != _phoneId,
                            )
                            .length -
                        1
                ? null
                : () => _move(index, 1),
            icon: const StackCardIcon(name: 'arrow-down'),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _remove(link),
                child: Text(context.strings.tr('builderForm.delete')),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: StackCardSpacing.sm),
    ],
    if (_data!.links.isEmpty) Text(_tr('emptyContacts')),
    StackCardButton(
      key: const Key('settings.contacts.add'),
      label: _tr('addLink'),
      role: StackCardButtonRole.secondary,
      onPressed: () => _link(),
      icon: Icons.add_rounded,
    ),
  ];
  List<Widget> _privacy() => [
    Text(_tr('privacyHint')),
    const SizedBox(height: StackCardSpacing.lg),
    StackCardCard(
      child: Column(
        children: [
          if (_data!.links.isEmpty) Text(_tr('emptyContacts')),
          for (final link in _data!.links)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(link.label),
              subtitle: Text(link.url),
              value: link.publishAllowed,
              onChanged: (value) => _update(
                _data!.copyWith(
                  links: [
                    for (final item in _data!.links)
                      item.id == link.id
                          ? item.copyWith(publishAllowed: value!)
                          : item,
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    const SizedBox(height: StackCardSpacing.lg),
    StackCardCard(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(_tr('location')),
            subtitle: Text(
              _data!.profile.locationText.isEmpty
                  ? _tr('locationHint')
                  : _data!.profile.locationText,
            ),
            value: _data!.profile.publishLocation,
            onChanged: (value) => _update(
              _data!.copyWith(
                profile: _data!.profile.copyWith(publishLocation: value),
              ),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(_tr('requests')),
            subtitle: Text(_tr('requestsUnavailable')),
            value: false,
            onChanged: null,
          ),
        ],
      ),
    ),
  ];
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({required this.id, this.link});
  final String id;
  final SocialLink? link;
  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.link?.label ?? '');
  late final _value = TextEditingController(text: widget.link?.url ?? '');
  late SocialLinkKind _kind = widget.link?.kind ?? SocialLinkKind.other;
  late bool _allowed = widget.link?.publishAllowed ?? false;
  String _tr(String key) => context.strings.tr('settingsManagement.$key');
  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    super.dispose();
  }

  String _url() {
    final raw = _value.text.trim();
    return switch (_kind) {
      SocialLinkKind.email => raw.startsWith('mailto:') ? raw : 'mailto:$raw',
      SocialLinkKind.phone => raw.startsWith('tel:') ? raw : 'tel:$raw',
      SocialLinkKind.telegram =>
        raw.startsWith('@') ? 'https://t.me/${raw.substring(1)}' : raw,
      _ => raw,
    };
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_tr(widget.link == null ? 'addLink' : 'editLink')),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _label,
                maxLength: 80,
                decoration: InputDecoration(labelText: _tr('linkLabel')),
                validator: (value) => value!.trim().isEmpty || value.length > 80
                    ? _tr('invalidLabel')
                    : null,
              ),
              DropdownButtonFormField<SocialLinkKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: InputDecoration(labelText: _tr('linkKind')),
                items: [
                  for (final kind in SocialLinkKind.values.where(
                    (kind) =>
                        widget.link != null ||
                        (kind != SocialLinkKind.email &&
                            kind != SocialLinkKind.phone),
                  ))
                    DropdownMenuItem(
                      value: kind,
                      child: Text(_tr('kind.${kind.name}')),
                    ),
                ],
                onChanged: (value) => setState(() => _kind = value!),
              ),
              TextFormField(
                controller: _value,
                maxLength: 2048,
                decoration: InputDecoration(labelText: _tr('linkValue')),
                validator: (_) =>
                    validatePortfolioContactUrl(_url(), _kind) == null
                    ? null
                    : _tr('invalidContact'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_tr('publishAllowed')),
                value: _allowed,
                onChanged: (value) => setState(() => _allowed = value!),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.strings.tr('account.cancel')),
      ),
      TextButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              SocialLink(
                id: widget.id,
                label: _label.text.trim(),
                url: _url(),
                kind: _kind,
                publishAllowed: _allowed,
                visible: widget.link?.visible ?? true,
              ),
            );
          }
        },
        child: Text(context.strings.tr('settingsManagement.save')),
      ),
    ],
  );
}

class _QualificationEditor extends StatelessWidget {
  const _QualificationEditor({required this.content, required this.onChanged});
  final PortfolioContent content;
  final ValueChanged<PortfolioContent> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final kind in ['skills', 'experience', 'education']) ...[
        const SizedBox(height: StackCardSpacing.md),
        Text(
          context.strings.tr('builder.section.$kind'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final item in switch (kind) {
          'skills' => content.skills,
          'experience' => content.experience,
          _ => content.education,
        })
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(switch (item) {
              Skill s => s.name,
              Experience e => e.role,
              Education e => e.institution,
              _ => '',
            }),
            onTap: () => _edit(context, kind, item),
            trailing: IconButton(
              tooltip: context.strings.tr('builderForm.delete'),
              onPressed: () => onChanged(switch (item) {
                Skill s => content.copyWith(
                  skills: content.skills.where((i) => i.id != s.id).toList(),
                ),
                Experience e => content.copyWith(
                  experience: content.experience
                      .where((i) => i.id != e.id)
                      .toList(),
                ),
                Education e => content.copyWith(
                  education: content.education
                      .where((i) => i.id != e.id)
                      .toList(),
                ),
                _ => content,
              }),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        TextButton(
          onPressed: () => _edit(context, kind, null),
          child: Text(context.strings.tr('builderForm.add')),
        ),
      ],
    ],
  );
  Future<void> _edit(BuildContext context, String kind, Object? item) async {
    final fields = switch (item) {
      Skill s => {'name': s.name},
      Experience e => {
        'role': e.role,
        'organization': e.organization,
        'period': e.period,
        'description': e.description,
      },
      Education e => {
        'institution': e.institution,
        'qualification': e.qualification,
        'period': e.period,
        'description': e.description,
      },
      _ => switch (kind) {
        'skills' => {'name': ''},
        'experience' => {
          'role': '',
          'organization': '',
          'period': '',
          'description': '',
        },
        _ => {
          'institution': '',
          'qualification': '',
          'period': '',
          'description': '',
        },
      },
    };
    final controllers = {
      for (final field in fields.entries)
        field.key: TextEditingController(text: field.value),
    };
    final form = GlobalKey<FormState>();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.tr('builder.section.$kind')),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in controllers.entries)
                  TextFormField(
                    controller: field.value,
                    maxLength: switch (field.key) {
                      'description' => 4000,
                      'name' => 60,
                      'role' || 'period' => 120,
                      _ => 160,
                    },
                    maxLines: field.key == 'description' ? 3 : 1,
                    decoration: InputDecoration(
                      labelText: context.strings.tr('builderForm.${field.key}'),
                    ),
                    validator: (value) =>
                        !['period', 'description'].contains(field.key) &&
                            value!.trim().isEmpty
                        ? context.strings.tr('builderForm.required')
                        : null,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.strings.tr('account.cancel')),
          ),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, {
                  for (final field in controllers.entries)
                    field.key: field.value.text.trim(),
                });
              }
            },
            child: Text(context.strings.tr('settingsManagement.save')),
          ),
        ],
      ),
    );
    for (final field in controllers.values) {
      field.dispose();
    }
    if (!context.mounted || values == null) return;
    final id = switch (item) {
      Skill s => s.id,
      Experience e => e.id,
      Education e => e.id,
      _ => DateTime.now().microsecondsSinceEpoch.toString(),
    };
    onChanged(switch (kind) {
      'skills' => content.copyWith(
        skills: [
          for (final s in content.skills)
            if (s.id != id) s,
          Skill(id: id, name: values['name']!),
        ],
      ),
      'experience' => content.copyWith(
        experience: [
          for (final e in content.experience)
            if (e.id != id) e,
          Experience(
            id: id,
            role: values['role']!,
            organization: values['organization']!,
            period: values['period']!,
            description: values['description']!,
          ),
        ],
      ),
      _ => content.copyWith(
        education: [
          for (final e in content.education)
            if (e.id != id) e,
          Education(
            id: id,
            institution: values['institution']!,
            qualification: values['qualification']!,
            period: values['period']!,
            description: values['description']!,
          ),
        ],
      ),
    });
  }
}
