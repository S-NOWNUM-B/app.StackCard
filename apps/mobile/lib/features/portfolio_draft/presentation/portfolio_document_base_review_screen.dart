import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_avatar.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../auth/auth.dart';
import '../../media/media.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_document_base_review.dart';
import '../domain/portfolio_draft_repository.dart';
import '../portfolio_draft_providers.dart';

/// Выбор captured изменений меняет только буфер вызывающего редактора.
class PortfolioDocumentBaseReviewScreen extends ConsumerStatefulWidget {
  const PortfolioDocumentBaseReviewScreen({
    super.key,
    required this.review,
    this.isActive,
  });

  final PortfolioDocumentBaseReview review;
  final bool Function()? isActive;

  @override
  ConsumerState<PortfolioDocumentBaseReviewScreen> createState() =>
      _PortfolioDocumentBaseReviewScreenState();
}

class _PortfolioDocumentBaseReviewScreenState
    extends ConsumerState<PortfolioDocumentBaseReviewScreen> {
  late final PortfolioDraftRepository _repository;
  (Object?, String?, bool, bool)? _initialOwner;
  late final Set<String> _selectedKeys;
  var _ownerLost = false;

  String _tr(String key) => context.strings.tr(
    key == 'field.publishLocation'
        ? 'documentContacts.location'
        : 'baseReview.$key',
  );

  @override
  void initState() {
    super.initState();
    _repository = ref.read(portfolioDraftRepositoryProvider);
    final owner = _owner();
    if (owner.$4) _initialOwner = owner;
    _selectedKeys = {
      for (final change in widget.review.changes)
        if (change.defaultSelected) change.key,
    };
  }

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

  bool _authorized((Object?, String?, bool, bool) owner) =>
      owner.$4 && (owner.$1 == null || owner.$2 != null || owner.$3);

  bool get _active =>
      mounted &&
      !_ownerLost &&
      (widget.isActive?.call() ?? true) &&
      _initialOwner == _owner() &&
      _authorized(_owner()) &&
      identical(_repository, ref.read(portfolioDraftRepositoryProvider));

  void _select(String key, bool selected) {
    if (!_active) return;
    setState(() {
      if (selected) {
        _selectedKeys.add(key);
      } else {
        _selectedKeys.remove(key);
      }
    });
  }

  void _apply() {
    if (!_active || widget.review.changes.isEmpty) return;
    Navigator.of(context).pop(widget.review.apply(Set.of(_selectedKeys)));
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    final owner = _owner(watch: true);
    if (_initialOwner == null && owner.$4) _initialOwner = owner;
    if ((_initialOwner != null && _initialOwner != owner) ||
        !identical(_repository, repository) ||
        !(widget.isActive?.call() ?? true)) {
      _ownerLost = true;
      _selectedKeys.clear();
    }
    final active = _active;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final media = MediaQuery.of(context);
    final visibleHeight =
        media.size.height - media.padding.vertical - media.viewInsets.bottom;
    final scrollHeader = visibleHeight < (largeText ? 450 : 300);
    return Scaffold(
      appBar: scrollHeader
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: largeText
                  ? StackCardSize.touchTarget * 2.5
                  : kToolbarHeight,
              leading: _backButton(),
              title: Text(_tr('title')),
            ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = active
                ? _content()
                : Text(
                    _initialOwner == null
                        ? context.strings.tr('common.loading')
                        : _tr('ownerChanged'),
                    key: const ValueKey('base-review-owner-changed'),
                  );
            // При клавиатуре/коротком landscape действия остаются достижимы скроллом.
            final compact =
                constraints.maxHeight < 300 ||
                (MediaQuery.textScalerOf(context).scale(1) >= 1.5 &&
                    constraints.maxHeight < 450);
            final scroll = SingleChildScrollView(
              key: const ValueKey('base-review-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (scrollHeader)
                    Padding(
                      padding: const EdgeInsets.all(StackCardSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _backButton(),
                          const SizedBox(width: StackCardSpacing.sm),
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                _tr('title'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
                    child: content,
                  ),
                  if (compact && active) _footer(),
                ],
              ),
            );
            final bounded = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: StackCardSize.contentMaxWidth,
                ),
                child: SizedBox(width: double.infinity, child: scroll),
              ),
            );
            if (compact) return bounded;
            return Column(
              children: [
                Expanded(child: bounded),
                if (active) _footer(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _backButton() => IconButton(
    key: const ValueKey('base-review-back'),
    tooltip: _tr('back'),
    onPressed: () => Navigator.of(context).pop(),
    icon: const StackCardIcon(name: 'arrow-left'),
  );

  Widget _content() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _tr('intro'),
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: context.colors.textSecondary),
      ),
      if (!widget.review.hasBaseline) ...[
        const SizedBox(height: StackCardSpacing.lg),
        Text(
          _tr('noBaseline'),
          key: const ValueKey('base-review-no-baseline'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
      const SizedBox(height: StackCardSpacing.xl),
      if (widget.review.changes.isEmpty) ...[
        Text(
          _tr('emptyTitle'),
          key: const ValueKey('base-review-empty'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        Text(_tr('emptyHint')),
      ],
      for (final change in widget.review.changes) ...[
        _comparison(change),
        const SizedBox(height: StackCardSpacing.lg),
      ],
    ],
  );

  Widget _comparison(PortfolioDocumentBaseChange change) => StackCardCard(
    key: ValueKey('base-review-card-${change.key}'),
    outlined: true,
    padding: const EdgeInsets.all(StackCardSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _tr('field.${change.field.name}'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (change.hasLocalOverride) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            _tr('localOverride'),
            key: ValueKey('base-review-local-${change.key}'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.colors.accentText),
          ),
        ],
        const SizedBox(height: StackCardSpacing.lg),
        _value(change, incoming: false),
        const SizedBox(height: StackCardSpacing.lg),
        _value(change, incoming: true),
        const SizedBox(height: StackCardSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: StackCardSize.inputHeight,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: ValueKey('base-review-${change.key}'),
              contentPadding: EdgeInsets.zero,
              title: Semantics(
                label: '${_tr('select')}: ${_selectionLabel(change)}',
                excludeSemantics: true,
                child: Text(_tr('select')),
              ),
              controlAffinity: ListTileControlAffinity.trailing,
              value: _selectedKeys.contains(change.key),
              onChanged: (value) => _select(change.key, value ?? false),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _value(PortfolioDocumentBaseChange change, {required bool incoming}) {
    final value = incoming ? change.incomingValue : change.currentValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _tr(incoming ? 'incoming' : 'current'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.colors.textMeta),
        ),
        const SizedBox(height: StackCardSpacing.xs),
        if (change.field == PortfolioDocumentBaseField.avatar &&
            value is (String, String))
          _avatar(value)
        else
          Text(
            _format(value, incoming: incoming),
            key: ValueKey(
              'base-review-${incoming ? 'incoming' : 'current'}-${change.key}',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }

  String _selectionLabel(PortfolioDocumentBaseChange change) {
    final value = change.incomingValue ?? change.currentValue;
    final item = switch (value) {
      Skill value => value.name,
      Experience value => value.role,
      Education value => value.qualification,
      SocialLink value => value.label.isEmpty ? value.url : value.label,
      _ => '',
    };
    return _join([_tr('field.${change.field.name}'), item], separator: ' · ');
  }

  Widget _avatar((String, String) value) {
    final (url, path) = value;
    if (url.isEmpty && path.isEmpty) return Text(_tr('emptyValue'));
    return Align(
      alignment: Alignment.centerLeft,
      child: StackCardAvatar(
        size: 64,
        url: url,
        image: path.isEmpty
            ? null
            : PortfolioMediaImage(path: path, width: 64, height: 64),
      ),
    );
  }

  String _format(Object? value, {required bool incoming}) {
    if (value == null) return _tr(incoming ? 'removed' : 'missing');
    final text = switch (value) {
      bool value => context.strings.tr(
        value
            ? 'documentContacts.permissionGranted'
            : 'documentContacts.permissionDenied',
      ),
      String value => value,
      Skill value => value.name,
      Experience value => _join([
        value.role,
        _join([value.organization, value.period], separator: ' · '),
        value.description,
      ]),
      Education value => _join([
        value.qualification,
        _join([value.institution, value.period], separator: ' · '),
        value.description,
      ]),
      SocialLink value => _join([value.label, value.url]),
      _ => '',
    };
    return text.trim().isEmpty ? _tr('emptyValue') : text;
  }

  String _join(List<String> values, {String separator = '\n'}) =>
      values.where((value) => value.trim().isNotEmpty).join(separator);

  Widget _footer() => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border(top: BorderSide(color: context.colors.borderSubtle)),
    ),
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: StackCardSize.contentMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _tr('saveHint'),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.colors.textMeta),
                ),
                const SizedBox(height: StackCardSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final actions = [
                      StackCardButton(
                        key: const ValueKey('base-review-cancel'),
                        label: _tr('cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      StackCardButton(
                        key: const ValueKey('base-review-apply'),
                        label: _tr('apply'),
                        primary: true,
                        onPressed: widget.review.changes.isEmpty
                            ? null
                            : _apply,
                      ),
                    ];
                    final narrow =
                        constraints.maxWidth < 280 ||
                        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          actions.first,
                          const SizedBox(height: StackCardSpacing.sm),
                          actions.last,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: actions.first),
                        const SizedBox(width: StackCardSpacing.sm),
                        Expanded(child: actions.last),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
