import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../auth_providers.dart';
import '../domain/auth_failure.dart';
import '../../portfolio_draft/portfolio_draft.dart';
import 'auth_controller.dart';

enum AuthFormMode { signIn, register, resetPassword }

String? accountAuthErrorKey(Object? error) {
  if (error == null) return null;
  if (error case AuthFailure(kind: final kind)) {
    return kind == AuthFailureKind.cancelled
        ? null
        : 'account.error.${kind.name}';
  }
  return 'account.error.unknown';
}

class AccountAuthForm extends ConsumerStatefulWidget {
  const AccountAuthForm({super.key, this.mode = AuthFormMode.signIn});

  final AuthFormMode mode;

  @override
  ConsumerState<AccountAuthForm> createState() => _AccountAuthFormState();
}

class _AccountAuthFormState extends ConsumerState<AccountAuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _resetSent = false;
  bool _confirming = false;

  Future<bool> _confirmAccountSwitch() async {
    if (!ref.read(portfolioDraftControllerProvider).hasUnsavedChanges) {
      return true;
    }
    setState(() => _confirming = true);
    try {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.strings.tr('account.unsavedTitle')),
              content: Text(context.strings.tr('account.unsavedHint')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.strings.tr('account.cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.strings.tr('account.discard')),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AccountAuthForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _password.clear();
      _confirmation.clear();
      _resetSent = false;
      _formKey.currentState?.reset();
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
        ? null
        : context.strings.tr('account.error.invalidEmail');
  }

  String? _validatePassword(String? value) {
    return (value?.length ?? 0) >= 6
        ? null
        : context.strings.tr('account.error.weakPassword');
  }

  String _returnPath() {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final uri = from == null ? null : Uri.tryParse(from);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !uri.path.startsWith('/') ||
        uri.path.startsWith('//') ||
        const ['/sign-in', '/register', '/reset-password'].contains(uri.path)) {
      return '/home';
    }
    return uri.toString();
  }

  void _openMode(String path) {
    ref.read(accountAuthControllerProvider.notifier).clearError();
    final from = _returnPath();
    context.go(Uri(path: path, queryParameters: {'from': from}).toString());
  }

  bool get _sessionBlocked {
    final session = ref.read(accountSessionProvider);
    return session.isLoading || session.hasError;
  }

  Future<void> _submit() async {
    final session = ref.read(accountSessionProvider);
    if (_confirming ||
        session.isLoading ||
        session.hasError ||
        ref.read(accountAuthControllerProvider).isLoading ||
        !_formKey.currentState!.validate()) {
      return;
    }
    if (widget.mode != AuthFormMode.resetPassword &&
        !await _confirmAccountSwitch()) {
      return;
    }
    if (!mounted || _sessionBlocked) return;
    FocusScope.of(context).unfocus();
    final destination = _returnPath();
    final controller = ref.read(accountAuthControllerProvider.notifier);
    final success = switch (widget.mode) {
      AuthFormMode.signIn => await controller.signInEmail(
        _email.text.trim(),
        _password.text,
      ),
      AuthFormMode.register => await controller.registerEmail(
        _email.text.trim(),
        _password.text,
      ),
      AuthFormMode.resetPassword => await controller.sendPasswordReset(
        _email.text.trim(),
      ),
    };
    if (!mounted || !success) return;
    if (widget.mode == AuthFormMode.resetPassword) {
      setState(() => _resetSent = true);
    } else {
      context.go(destination);
    }
  }

  Future<void> _google() async {
    final session = ref.read(accountSessionProvider);
    if (_confirming ||
        session.isLoading ||
        session.hasError ||
        ref.read(accountAuthControllerProvider).isLoading) {
      return;
    }
    if (!await _confirmAccountSwitch() || !mounted || _sessionBlocked) return;
    final destination = _returnPath();
    FocusScope.of(context).unfocus();
    final success = await ref
        .read(accountAuthControllerProvider.notifier)
        .signInGoogle();
    if (mounted && success) context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(accountAuthControllerProvider);
    final session = ref.watch(accountSessionProvider);
    final busy =
        auth.isLoading || _confirming || session.isLoading || session.hasError;
    final strings = context.strings;
    final errorKey = accountAuthErrorKey(auth.error);
    final titleKey = switch (widget.mode) {
      AuthFormMode.signIn => 'account.signIn',
      AuthFormMode.register => 'account.register',
      AuthFormMode.resetPassword => 'account.resetPassword',
    };
    final descriptionKey = switch (widget.mode) {
      AuthFormMode.signIn => 'account.signInDescription',
      AuthFormMode.register => 'account.registerDescription',
      AuthFormMode.resetPassword => 'account.resetDescription',
    };
    return StackCardCard(
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.tr(titleKey),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(strings.tr(descriptionKey)),
              if (session.isLoading) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(strings.tr('account.sessionRestoring')),
                      ),
                    ],
                  ),
                ),
              ] else if (session.hasError) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(strings.tr('account.sessionError')),
                ),
                const SizedBox(height: 12),
                StackCardButton(
                  key: const Key('account.retrySession'),
                  label: strings.tr('common.retry'),
                  onPressed: () => ref.invalidate(accountSessionProvider),
                ),
              ],
              const SizedBox(height: 24),
              StackCardInput(
                key: const Key('account.email'),
                label: strings.tr('account.email'),
                hint: strings.tr('account.emailHint'),
                controller: _email,
                enabled: !busy,
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: widget.mode == AuthFormMode.resetPassword
                    ? TextInputAction.done
                    : TextInputAction.next,
                onChanged: (_) {
                  if (_resetSent) setState(() => _resetSent = false);
                },
                onFieldSubmitted: widget.mode == AuthFormMode.resetPassword
                    ? (_) => _submit()
                    : null,
                validator: _validateEmail,
              ),
              if (widget.mode != AuthFormMode.resetPassword) ...[
                const SizedBox(height: 16),
                StackCardInput(
                  key: const Key('account.password'),
                  label: strings.tr('account.password'),
                  hint: strings.tr('account.passwordHint'),
                  controller: _password,
                  enabled: !busy,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: widget.mode == AuthFormMode.register
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: widget.mode == AuthFormMode.signIn
                      ? (_) => _submit()
                      : null,
                  validator: _validatePassword,
                ),
              ],
              if (widget.mode == AuthFormMode.register) ...[
                const SizedBox(height: 16),
                StackCardInput(
                  key: const Key('account.confirmPassword'),
                  label: strings.tr('account.confirmPassword'),
                  controller: _confirmation,
                  enabled: !busy,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => value == _password.text
                      ? null
                      : strings.tr('account.passwordMismatch'),
                ),
              ],
              const SizedBox(height: 20),
              StackCardButton(
                key: const Key('account.submit'),
                label: strings.tr(
                  widget.mode == AuthFormMode.resetPassword
                      ? 'account.sendReset'
                      : titleKey,
                ),
                icon: Icons.arrow_forward_rounded,
                primary: true,
                loading: auth.isLoading || _confirming,
                onPressed: busy ? null : _submit,
              ),
              if (errorKey != null) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(strings.tr(errorKey))),
              ],
              if (_resetSent) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(strings.tr('account.resetSuccess')),
                ),
              ],
              if (widget.mode != AuthFormMode.resetPassword) ...[
                const SizedBox(height: 12),
                StackCardButton(
                  key: const Key('account.google'),
                  label: strings.tr('account.google'),
                  icon: Icons.account_circle_outlined,
                  onPressed: busy ? null : _google,
                ),
              ],
              const SizedBox(height: 12),
              if (widget.mode == AuthFormMode.signIn) ...[
                TextButton(
                  onPressed: busy ? null : () => _openMode('/register'),
                  child: Text(
                    strings.tr('account.register'),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => _openMode('/reset-password'),
                  child: Text(
                    strings.tr('account.forgotPassword'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else
                TextButton(
                  onPressed: busy ? null : () => _openMode('/sign-in'),
                  child: Text(
                    strings.tr('account.backToSignIn'),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 12),
              StackCardButton(
                key: const Key('account.guest'),
                label: strings.tr('account.guest'),
                onPressed: busy
                    ? null
                    : () {
                        ref.read(guestAccessProvider.notifier).enter();
                        context.go('/home');
                      },
              ),
              const SizedBox(height: 20),
              Text(
                strings.tr('account.guestNote'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
