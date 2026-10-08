import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../auth/auth.dart';
import '../portfolio_draft/portfolio_draft.dart';
import 'account_settings_section.dart';
import 'settings_editor_scaffold.dart';
import 'settings_providers.dart';

class SettingsAccountScreen extends ConsumerStatefulWidget {
  const SettingsAccountScreen({super.key});
  @override
  ConsumerState<SettingsAccountScreen> createState() =>
      _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends ConsumerState<SettingsAccountScreen> {
  AccountSecurity? _security;
  AccountManagementRepository? _repository;
  AccountDeletionJournal? _journal;
  AccountDeletionRequest? _deletion;
  String? _uid, _message;
  bool _busy = false, _loading = false;
  int _generation = 0;
  String _tr(String key) => context.strings.tr('settingsManagement.$key');
  bool _active(String uid, AccountManagementRepository repository) {
    final session = ref.read(accountSessionProvider);
    return mounted &&
        session.hasValue &&
        !session.isLoading &&
        !session.hasError &&
        session.value?.uid == uid &&
        identical(repository, ref.read(accountManagementRepositoryProvider));
  }

  bool _visible(String uid, AccountManagementRepository repository) {
    final session = ref.read(accountSessionProvider);
    if (!mounted ||
        session.isLoading ||
        session.hasError ||
        !session.hasValue ||
        !identical(repository, ref.read(accountManagementRepositoryProvider))) {
      return false;
    }
    return session.value?.uid == uid ||
        (session.value == null &&
            ref.read(accountPendingDeletionOwnerProvider) == uid);
  }

  DocumentPublicationRepository? _publication(String uid) =>
      ref.read(accountSessionProvider).value?.uid == uid
      ? ref.read(documentPublicationRepositoryProvider)
      : ref.read(documentPublicationRepositoryFactoryProvider)(uid);

  Future<void> _load(String uid, AccountManagementRepository repository) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final journal = ref.read(accountDeletionJournalFactoryProvider)(uid);
      final request = await journal.read();
      if (!_visible(uid, repository) || generation != _generation) return;
      setState(() {
        _journal = journal;
        _deletion = request;
        if (request != null) _message = 'deleteUnknown';
      });
      if (!_active(uid, repository)) return;
      final security = await repository.readSecurity(uid);
      if (!_visible(uid, repository) || generation != _generation) return;
      setState(() => _security = security);
    } catch (error) {
      if (_visible(uid, repository) && generation == _generation) {
        setState(
          () =>
              _message = _deletion != null ? 'deleteUnknown' : _failure(error),
        );
      }
    } finally {
      if (_visible(uid, repository) && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  String _failure(Object error) {
    if (error is AccountManagementFailure) {
      return switch (error.kind) {
        AccountManagementFailureKind.ownerChanged => 'ownerChanged',
        AccountManagementFailureKind.lastProvider => 'lastProvider',
        AccountManagementFailureKind.reauthenticationRequired =>
          'reauthenticationRequired',
        AccountManagementFailureKind.providerInUse => 'providerInUse',
        _ => 'accountFailure',
      };
    }
    if (error is DocumentPublicationFailure &&
        error.kind == DocumentPublicationFailureKind.reauthenticationRequired) {
      return 'reauthenticationRequired';
    }
    return 'accountFailure';
  }

  Future<bool> _reauthenticate(
    String uid,
    AccountManagementRepository repository,
  ) async {
    final security = _security;
    if (security == null) return false;
    if (!security.hasPassword && security.hasGoogle) {
      await repository.reauthenticateGoogle(uid);
      return _active(uid, repository);
    }
    final input = await _credentials(
      title: 'reauthenticate',
      passwordLabel: 'currentPassword',
      allowGoogle: security.hasGoogle,
    );
    if (!_active(uid, repository) || input == null) return false;
    if (input.google) {
      await repository.reauthenticateGoogle(uid);
    } else {
      await repository.reauthenticatePassword(uid, input.password);
    }
    return _active(uid, repository);
  }

  Future<void> _run(
    Future<void> Function(String, AccountManagementRepository) action, {
    String? success,
    bool sensitive = false,
  }) async {
    final uid = _uid;
    final repository = _repository;
    if (_busy ||
        uid == null ||
        repository == null ||
        !_active(uid, repository)) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (sensitive && !await _reauthenticate(uid, repository)) return;
      if (!_active(uid, repository)) return;
      await action(uid, repository);
      if (!_active(uid, repository)) return;
      final security = await repository.readSecurity(uid);
      if (!_active(uid, repository)) return;
      setState(() {
        _security = security;
        if (success != null) _message = success;
      });
    } catch (error) {
      if (_active(uid, repository)) setState(() => _message = _failure(error));
    } finally {
      if (_active(uid, repository)) setState(() => _busy = false);
    }
  }

  Future<void> _changeEmail() async {
    final uid = _uid;
    final repository = _repository;
    if (uid == null || repository == null || _busy) return;
    final value = await _credentials(
      title: 'newEmail',
      email: true,
      password: false,
    );
    if (value == null || !_active(uid, repository)) return;
    await _run(
      (uid, repository) => repository.requestEmailChange(uid, value.email),
      sensitive: true,
      success: 'emailChangePending',
    );
  }

  Future<void> _password({bool link = false}) async {
    final uid = _uid;
    final repository = _repository;
    if (uid == null || repository == null || _busy) return;
    final value = await _credentials(
      title: link ? 'linkPassword' : 'newPassword',
      email: link,
      passwordLabel: 'newPassword',
      confirmPassword: true,
    );
    if (value == null || !_active(uid, repository)) return;
    await _run(
      (uid, repository) => link
          ? repository.linkPassword(uid, value.email, value.password)
          : repository.changePassword(uid, value.password),
      sensitive: true,
      success: link ? 'connected' : 'passwordChanged',
    );
  }

  Future<_AccountInput?> _credentials({
    required String title,
    bool email = false,
    bool password = true,
    bool confirmPassword = false,
    String passwordLabel = 'currentPassword',
    bool allowGoogle = false,
  }) => showDialog<_AccountInput>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AccountCredentialsDialog(
      title: title,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      passwordLabel: passwordLabel,
      allowGoogle: allowGoogle,
    ),
  );
  Future<void> _deleteAccount() async {
    final uid = _uid;
    final repository = _repository;
    final publication = ref.read(documentPublicationRepositoryProvider);
    if (_busy ||
        uid == null ||
        repository == null ||
        publication == null ||
        _journal == null ||
        !_active(uid, repository)) {
      return;
    }
    if (_deletion != null) {
      await _checkDeletion();
      return;
    }
    final draft = ref.read(portfolioDraftControllerProvider);
    if (draft.saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.tr('settings.deleteAccount')),
        content: Text(_tr('deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.tr('account.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.tr('settings.deleteAccount')),
          ),
        ],
      ),
    );
    if (!_active(uid, repository) || confirmed != true) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (!await _reauthenticate(uid, repository)) return;
      if (!_active(uid, repository)) return;
      final inventory = await publication.inventory();
      if (!_active(uid, repository) ||
          !identical(
            publication,
            ref.read(documentPublicationRepositoryProvider),
          )) {
        return;
      }
      final random = Random.secure();
      final operationId = List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final request = AccountDeletionRequest(
        operationId: operationId,
        expectedGeneration: inventory.lifecycleGeneration,
        recoveryKey: List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
      );
      await _journal!.write(request);
      if (!_active(uid, repository)) return;
      setState(() => _deletion = request);
      ref.read(accountPendingDeletionOwnerProvider.notifier).mark(uid);
      final result = await publication.deleteAccount(
        operationId: operationId,
        expectedGeneration: request.expectedGeneration,
        recoveryKey: request.recoveryKey!,
      );
      await _deletionResult(uid, repository, request, result);
    } catch (error) {
      if (_active(uid, repository)) {
        setState(
          () =>
              _message = _deletion != null ? 'deleteUnknown' : _failure(error),
        );
      }
    } finally {
      if (_active(uid, repository)) setState(() => _busy = false);
    }
  }

  Future<void> _checkDeletion({bool retry = false}) async {
    final uid = _uid;
    final repository = _repository;
    final request = _deletion;
    final publication = uid == null ? null : _publication(uid);
    if (_busy ||
        uid == null ||
        repository == null ||
        request == null ||
        publication == null ||
        !_visible(uid, repository)) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final DocumentPublicationOperation result;
      if (request.recoveryKey != null) {
        result = await publication.recoverAccountDeletion(
          ownerUid: uid,
          operationId: request.operationId,
          recoveryKey: request.recoveryKey!,
          retry: retry,
        );
      } else {
        // Старый receipt не разрешает новый delete; доступна только сверка с токеном.
        result = await publication.status(request.operationId);
      }
      await _deletionResult(uid, repository, request, result);
    } catch (_) {
      if (_visible(uid, repository)) setState(() => _message = 'deleteUnknown');
    } finally {
      if (_visible(uid, repository)) setState(() => _busy = false);
    }
  }

  Future<void> _deletionResult(
    String uid,
    AccountManagementRepository repository,
    AccountDeletionRequest request,
    DocumentPublicationOperation result,
  ) async {
    if (!_visible(uid, repository)) return;
    if (result.operationId != request.operationId ||
        result.action != 'deleteAccount' ||
        result.outcome == DocumentPublicationOutcome.unknown) {
      setState(() => _message = 'deleteUnknown');
      return;
    }
    if (result.outcome == DocumentPublicationOutcome.pending) {
      setState(() => _message = 'deletePending');
      return;
    }
    final cleanup = ref.read(accountConfirmedDeletionCleanupProvider);
    await cleanup?.call(uid);
    if (!_visible(uid, repository)) return;
    await _journal!.clear();
    if (!_visible(uid, repository)) return;
    await ref.read(accountAuthRepositoryProvider)?.signOut();
    if (mounted) {
      ref.read(accountPendingDeletionOwnerProvider.notifier).clear(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(accountSessionProvider);
    final repository = ref.watch(accountManagementRepositoryProvider);
    final pendingOwner = ref.watch(accountPendingDeletionOwnerProvider);
    final uid = session.hasValue && !session.isLoading && !session.hasError
        ? session.value?.uid ?? pendingOwner
        : null;
    if (uid != _uid || !identical(repository, _repository)) {
      _uid = uid;
      _repository = repository;
      _security = null;
      _journal = null;
      _deletion = null;
      _busy = false;
      _loading = true;
      _message = null;
      _generation++;
      if (uid != null && repository != null) {
        Future.microtask(() {
          if (_visible(uid, repository)) _load(uid, repository);
        });
      }
    }
    final security = _security;
    ref.watch(documentPublicationRepositoryProvider);
    final publication = uid == null ? null : _publication(uid);
    return SettingsEditorScaffold(
      title: context.strings.tr('settings.accountSecurity'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (uid == null || repository == null)
            Text(_tr('accountUnavailable'))
          else if (_loading)
            StackCardStateView(
              kind: StackCardViewState.loading,
              title: context.strings.tr('account.sessionRestoring'),
              message: '',
            )
          else if (security == null && _deletion != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(_tr(_message ?? 'deleteUnknown')),
            ),
            StackCardButton(
              label: _tr('deleteCheck'),
              loading: _busy,
              onPressed: _busy || publication == null
                  ? null
                  : () => _checkDeletion(),
            ),
            if (_deletion!.recoveryKey != null)
              StackCardButton(
                label: context.strings.tr('common.retry'),
                role: StackCardButtonRole.secondary,
                onPressed: _busy || publication == null
                    ? null
                    : () => _checkDeletion(retry: true),
              ),
          ] else if (security == null)
            StackCardStateView(
              kind: StackCardViewState.error,
              title: _tr('accountFailure'),
              message: '',
              onRetry: () => _load(uid, repository),
            )
          else ...[
            StackCardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.strings.tr('settings.changeLoginEmail'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: StackCardSpacing.md),
                  Text(security.email ?? ''),
                  Text(
                    _tr(
                      security.emailVerified
                          ? 'emailVerified'
                          : 'emailUnverified',
                    ),
                  ),
                  const SizedBox(height: StackCardSpacing.md),
                  StackCardButton(
                    label: context.strings.tr('settings.changeLoginEmail'),
                    onPressed: _busy || _deletion != null ? null : _changeEmail,
                    role: StackCardButtonRole.secondary,
                  ),
                  if (!security.emailVerified && security.email != null)
                    StackCardButton(
                      label: _tr('verifyEmail'),
                      onPressed: _busy || _deletion != null
                          ? null
                          : () => _run(
                              (uid, repo) => repo.sendVerification(uid),
                              success: 'verificationSent',
                            ),
                      role: StackCardButtonRole.quiet,
                    ),
                  if (security.hasPassword)
                    StackCardButton(
                      label: context.strings.tr('settings.changePassword'),
                      onPressed: _busy || _deletion != null ? null : _password,
                      role: StackCardButtonRole.secondary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: StackCardSpacing.lg),
            StackCardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _tr('providers'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.strings.tr('account.email')),
                    subtitle: Text(
                      _tr(security.hasPassword ? 'connected' : 'notConnected'),
                    ),
                  ),
                  if (!security.hasPassword)
                    StackCardButton(
                      label: _tr('linkPassword'),
                      onPressed: _busy || _deletion != null
                          ? null
                          : () => _password(link: true),
                      role: StackCardButtonRole.secondary,
                    )
                  else
                    StackCardButton(
                      label: _tr('unlinkPassword'),
                      role: StackCardButtonRole.quiet,
                      unavailableReason: security.canUnlink('password')
                          ? null
                          : _tr('lastProvider'),
                      onPressed:
                          _busy ||
                              _deletion != null ||
                              !security.canUnlink('password')
                          ? null
                          : () => _run(
                              (uid, repo) =>
                                  repo.unlinkProvider(uid, 'password'),
                              sensitive: true,
                              success: 'notConnected',
                            ),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Google'),
                    subtitle: Text(
                      _tr(security.hasGoogle ? 'connected' : 'notConnected'),
                    ),
                  ),
                  StackCardButton(
                    label: _tr(
                      security.hasGoogle ? 'unlinkGoogle' : 'linkGoogle',
                    ),
                    role: StackCardButtonRole.secondary,
                    unavailableReason:
                        security.hasGoogle && !security.canUnlink('google.com')
                        ? _tr('lastProvider')
                        : null,
                    onPressed:
                        _busy ||
                            _deletion != null ||
                            (security.hasGoogle &&
                                !security.canUnlink('google.com'))
                        ? null
                        : () => _run(
                            (uid, repo) => security.hasGoogle
                                ? repo.unlinkProvider(uid, 'google.com')
                                : repo.linkGoogle(uid),
                            sensitive: true,
                            success: security.hasGoogle
                                ? 'notConnected'
                                : 'connected',
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: StackCardSpacing.lg),
            StackCardButton(
              label: _tr('refreshAccount'),
              loading: _busy,
              role: StackCardButtonRole.quiet,
              onPressed: _busy ? null : () => _load(uid, repository),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: StackCardSpacing.md,
                ),
                child: Semantics(liveRegion: true, child: Text(_tr(_message!))),
              ),
            const AccountSettingsSection(),
            const SizedBox(height: StackCardSpacing.lg),
            StackCardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.strings.tr('settings.deleteAccount'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: StackCardSpacing.md),
                  Text(_tr('deleteConfirm')),
                  if (_deletion == null)
                    StackCardButton(
                      key: const Key('settings.account.delete'),
                      label: context.strings.tr('settings.deleteAccount'),
                      role: StackCardButtonRole.danger,
                      unavailableReason: publication == null
                          ? context.strings.tr(
                              'settings.deleteAccountUnavailable',
                            )
                          : null,
                      onPressed: _busy || publication == null
                          ? null
                          : _deleteAccount,
                    )
                  else ...[
                    StackCardButton(
                      label: _tr('deleteCheck'),
                      onPressed: _busy ? null : () => _checkDeletion(),
                    ),
                    StackCardButton(
                      label: context.strings.tr('common.retry'),
                      role: StackCardButtonRole.secondary,
                      onPressed: _busy
                          ? null
                          : () => _checkDeletion(retry: true),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _AccountInput {
  const _AccountInput({
    this.email = '',
    this.password = '',
    this.google = false,
  });
  final String email, password;
  final bool google;
}

class _AccountCredentialsDialog extends StatefulWidget {
  const _AccountCredentialsDialog({
    required this.title,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.passwordLabel,
    required this.allowGoogle,
  });
  final String title, passwordLabel;
  final bool email, password, confirmPassword, allowGoogle;
  @override
  State<_AccountCredentialsDialog> createState() =>
      _AccountCredentialsDialogState();
}

class _AccountCredentialsDialogState extends State<_AccountCredentialsDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  String _tr(String key) => context.strings.tr('settingsManagement.$key');
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_tr(widget.title)),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.email)
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: _tr('newEmail')),
                validator: (value) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(value!.trim())
                    ? null
                    : context.strings.tr('account.error.invalidEmail'),
              ),
            if (widget.password)
              TextFormField(
                controller: _password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: _tr(widget.passwordLabel),
                ),
                validator: (value) =>
                    value!.length >= (widget.confirmPassword ? 6 : 1)
                    ? null
                    : context.strings.tr('account.error.weakPassword'),
              ),
            if (widget.confirmPassword)
              TextFormField(
                controller: _confirmation,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: context.strings.tr('account.confirmPassword'),
                ),
                validator: (value) => value == _password.text
                    ? null
                    : context.strings.tr('account.passwordMismatch'),
              ),
            if (widget.allowGoogle)
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, const _AccountInput(google: true)),
                child: const Text('Google'),
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
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              _AccountInput(
                email: _email.text.trim(),
                password: _password.text,
              ),
            );
          }
        },
        child: Text(context.strings.tr('settingsManagement.confirm')),
      ),
    ],
  );
}
