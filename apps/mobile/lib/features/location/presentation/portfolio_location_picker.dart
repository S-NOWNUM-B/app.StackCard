import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../auth/auth.dart';
import '../domain/portfolio_location.dart';
import '../location_providers.dart';

class PortfolioLocationPicker extends ConsumerStatefulWidget {
  const PortfolioLocationPicker({
    super.key,
    this.currentLocation = '',
    this.isActive,
  });

  final String currentLocation;
  final bool Function()? isActive;

  @override
  ConsumerState<PortfolioLocationPicker> createState() =>
      _PortfolioLocationPickerState();
}

class _PortfolioLocationPickerState
    extends ConsumerState<PortfolioLocationPicker> {
  final _formKey = GlobalKey<FormState>();
  final _city = TextEditingController();
  final _country = TextEditingController();
  PortfolioLocationRepository? _initialRepository;
  (Object?, String?, bool, bool)? _initialOwner;
  PortfolioLocationFailureKind? _failure;
  int _generation = 0;
  bool _busy = false;
  bool _suggested = false;
  bool _settingsFailed = false;
  bool _ownerLost = false;

  @override
  void dispose() {
    ++_generation;
    _city.dispose();
    _country.dispose();
    super.dispose();
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

  bool get _active =>
      mounted &&
      !_ownerLost &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      (widget.isActive?.call() ?? true) &&
      _initialOwner == _owner() &&
      identical(
        _initialRepository,
        ref.read(portfolioLocationRepositoryProvider),
      );

  bool _ensureActive() {
    if (_active) return true;
    if (mounted && !_ownerLost) setState(() => _ownerLost = true);
    return false;
  }

  bool _accept(int generation) => generation == _generation && _ensureActive();

  void _edited(String _) {
    // Ручной ввод важнее любого ещё не завершённого определения города.
    ++_generation;
    setState(() {
      _busy = false;
      _suggested = false;
    });
  }

  Future<void> _detect() async {
    if (!_ensureActive() || _busy) return;
    final repository = ref.read(portfolioLocationRepositoryProvider);
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _failure = null;
      _settingsFailed = false;
      _suggested = false;
    });
    try {
      final place = await repository.currentPlace();
      if (!_accept(generation)) return;
      if (!place.isValid) {
        throw const PortfolioLocationFailure(
          PortfolioLocationFailureKind.placeUnavailable,
        );
      }
      setState(() {
        _city.text = place.city;
        _country.text = place.country;
        _suggested = true;
      });
    } on PortfolioLocationFailure catch (error) {
      if (_accept(generation)) setState(() => _failure = error.kind);
    } catch (_) {
      if (_accept(generation)) {
        setState(() => _failure = PortfolioLocationFailureKind.unavailable);
      }
    } finally {
      if (_accept(generation)) setState(() => _busy = false);
    }
  }

  Future<void> _settings({required bool app}) async {
    if (!_ensureActive() || _busy) return;
    final repository = ref.read(portfolioLocationRepositoryProvider);
    final generation = ++_generation;
    setState(() => _settingsFailed = false);
    try {
      final opened = await (app
          ? repository.openAppSettings()
          : repository.openLocationSettings());
      if (_accept(generation) && !opened) {
        setState(() => _settingsFailed = true);
      }
    } catch (_) {
      if (_accept(generation)) setState(() => _settingsFailed = true);
    }
  }

  String? _validate(String? text, int limit) {
    final value = (text ?? '').trim();
    if (value.isEmpty) return context.strings.tr('builderForm.required');
    if (value.length > limit) {
      return context.strings.tr('builderForm.tooLong', {'limit': limit});
    }
    return null;
  }

  void _confirm() {
    if (!_ensureActive() ||
        _busy ||
        _formKey.currentState?.validate() != true) {
      return;
    }
    final place = PortfolioPlace(city: _city.text, country: _country.text);
    if (!place.isValid) return;
    ++_generation;
    Navigator.of(context).pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(portfolioLocationRepositoryProvider);
    final owner = _owner(watch: true);
    _initialRepository ??= repository;
    if (owner.$4) _initialOwner ??= owner;
    if (_initialOwner != null &&
        (_initialOwner != owner ||
            !identical(_initialRepository, repository) ||
            !(widget.isActive?.call() ?? true))) {
      _ownerLost = true;
    }
    final active = _active;
    final strings = context.strings;
    final failure = _failure;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('location_back'),
          tooltip: strings.tr('builderForm.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(strings.tr('location.title')),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StackCardSize.contentMaxWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(StackCardSpacing.lg),
              child: active
                  ? Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.currentLocation.trim().isNotEmpty) ...[
                            Text(
                              strings.tr('location.current', {
                                'location': widget.currentLocation,
                              }),
                            ),
                            const SizedBox(height: StackCardSpacing.lg),
                          ],
                          Text(
                            strings.tr('location.privacy'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.colors.textSecondary),
                          ),
                          const SizedBox(height: StackCardSpacing.lg),
                          StackCardButton(
                            key: const ValueKey('location_detect'),
                            label: strings.tr(
                              _busy ? 'location.detecting' : 'location.detect',
                            ),
                            icon: Icons.my_location_rounded,
                            loading: _busy,
                            onPressed: _detect,
                          ),
                          if (failure != null) ...[
                            const SizedBox(height: StackCardSpacing.lg),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                strings.tr('location.${failure.name}'),
                                key: const ValueKey('location_error'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: context.colors.error),
                              ),
                            ),
                            if (failure ==
                                PortfolioLocationFailureKind.permanentlyDenied)
                              StackCardButton(
                                key: const ValueKey('location_app_settings'),
                                label: strings.tr('location.appSettings'),
                                onPressed: () => _settings(app: true),
                              ),
                            if (failure ==
                                PortfolioLocationFailureKind.serviceDisabled)
                              StackCardButton(
                                key: const ValueKey('location_device_settings'),
                                label: strings.tr('location.deviceSettings'),
                                onPressed: () => _settings(app: false),
                              ),
                          ],
                          if (_settingsFailed) ...[
                            const SizedBox(height: StackCardSpacing.sm),
                            Text(
                              strings.tr('location.settingsFailed'),
                              key: const ValueKey('location_settings_error'),
                            ),
                          ],
                          const SizedBox(height: StackCardSpacing.xl),
                          StackCardInput(
                            key: const ValueKey('location_city'),
                            label: strings.tr('location.city'),
                            controller: _city,
                            onChanged: _edited,
                            validator: (value) => _validate(value, 100),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: StackCardSpacing.lg),
                          StackCardInput(
                            key: const ValueKey('location_country'),
                            label: strings.tr('location.country'),
                            controller: _country,
                            onChanged: _edited,
                            validator: (value) => _validate(value, 96),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _confirm(),
                          ),
                          if (_suggested) ...[
                            const SizedBox(height: StackCardSpacing.lg),
                            Text(
                              strings.tr('location.suggestion'),
                              key: const ValueKey('location_suggestion'),
                            ),
                          ],
                          const SizedBox(height: StackCardSpacing.xl),
                          StackCardButton(
                            key: const ValueKey('location_confirm'),
                            label: strings.tr('location.confirm'),
                            primary: true,
                            onPressed: _busy ? null : _confirm,
                          ),
                        ],
                      ),
                    )
                  : Text(
                      strings.tr(
                        _initialOwner == null
                            ? 'common.loading'
                            : 'location.ownerChanged',
                      ),
                      key: const ValueKey('location_owner_changed'),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
