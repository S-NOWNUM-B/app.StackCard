import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../shared/widgets/stackcard_brand.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../domain/demo_session.dart';
import 'auth_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
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
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.all(constraints.maxWidth >= 700 ? 32 : 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 64).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: LayoutBuilder(
                    builder: (context, content) {
                      final introduction = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const StackCardBrand(),
                          const SizedBox(height: 48),
                          Text(
                            context.strings.tr('auth.hero'),
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            context.strings.tr('auth.intro'),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.light
                                      ? context.colors.textPrimary
                                      : context.colors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 32),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(context.strings.tr('nav.projects')),
                              ),
                              Chip(
                                label: Text(context.strings.tr('auth.skills')),
                              ),
                              Chip(
                                label: Text(context.strings.tr('auth.story')),
                              ),
                            ],
                          ),
                        ],
                      );
                      final form = StackCardCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.strings.tr('auth.title'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.strings.tr('auth.description'),
                                style: Theme.of(context).textTheme.bodyMedium,
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
                                    : context.strings.tr('auth.invalidEmail'),
                              ),
                              const SizedBox(height: 20),
                              StackCardButton(
                                label: context.strings.tr('auth.open'),
                                icon: Icons.arrow_forward_rounded,
                                primary: true,
                                loading: auth.isLoading,
                                onPressed: auth.isLoading ? null : _openDemo,
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
                              const SizedBox(height: 20),
                              Text(
                                context.strings.tr('auth.note'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.light
                                          ? context.colors.textPrimary
                                          : context.colors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                      return content.maxWidth >= 800 &&
                              MediaQuery.textScalerOf(context).scale(16) <= 24
                          ? Row(
                              children: [
                                Expanded(child: introduction),
                                const SizedBox(width: 48),
                                Expanded(child: form),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                introduction,
                                const SizedBox(height: 32),
                                form,
                              ],
                            );
                    },
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
