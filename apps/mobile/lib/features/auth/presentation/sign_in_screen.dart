import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/stackcard_brand.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../domain/demo_session.dart';
import '../auth_providers.dart';
import 'account_auth_form.dart';
import 'auth_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.mode = AuthFormMode.signIn});

  final AuthFormMode mode;
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'alex@example.dev');
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _openDemo() async {
    if (ref.read(authControllerProvider).isLoading ||
        !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final opened = await ref
        .read(authControllerProvider.notifier)
        .openDemo(_email.text);
    if (mounted && opened) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final accountConfigured = ref.watch(accountAuthRepositoryProvider) != null;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.all(constraints.maxWidth >= 700 ? 32 : 16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const StackCardBrand(),
                    const SizedBox(height: 32),
                    accountConfigured
                        ? AccountAuthForm(mode: widget.mode)
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    context.strings.tr('auth.title'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  const SizedBox(height: 24),
                                  StackCardInput(
                                    label: context.strings.tr('auth.email'),
                                    hint: 'alex@example.dev',
                                    controller: _email,
                                    enabled: !auth.isLoading,
                                    prefixIcon: Icons.alternate_email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _openDemo(),
                                    validator: (value) =>
                                        validateDemoEmail(value) == null
                                        ? null
                                        : context.strings.tr(
                                            'auth.invalidEmail',
                                          ),
                                  ),
                                  const SizedBox(height: 20),
                                  StackCardButton(
                                    label: context.strings.tr('auth.open'),
                                    icon: Icons.arrow_forward_rounded,
                                    primary: true,
                                    loading: auth.isLoading,
                                    onPressed: auth.isLoading
                                        ? null
                                        : _openDemo,
                                  ),
                                  if (auth.hasError) ...[
                                    const SizedBox(height: 12),
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        context.strings.tr('auth.error'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
