import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../shared/widgets/stackcard_brand.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';
import '../../shared/widgets/stackcard_input.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'alex@example.dev');
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _openDemo() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.all(constraints.maxWidth >= 700 ? 32 : 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 64).clamp(0, double.infinity),
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
                          'Ваш код.\nВаша история.',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Соберите проекты, навыки и опыт в одном портфолио. Покажите то, что умеете создавать.',
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
                          children: const [
                            Chip(label: Text('Проекты')),
                            Chip(label: Text('Навыки')),
                            Chip(label: Text('Ваша история')),
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
                              'Знакомство со StackCard',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Откройте демонстрационное портфолио и изучите интерфейс.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            StackCardInput(
                              label: 'Email для примера',
                              hint: 'alex@example.dev',
                              controller: _email,
                              prefixIcon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _openDemo(),
                              validator: (value) =>
                                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(value?.trim() ?? '')
                                  ? null
                                  : 'Укажите корректный email',
                            ),
                            const SizedBox(height: 20),
                            StackCardButton(
                              label: 'Открыть демо',
                              icon: Icons.arrow_forward_rounded,
                              primary: true,
                              onPressed: _openDemo,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Это демо на примерах данных. Email проверяется только на экране и не сохраняется. Авторизация будет подключена позднее.',
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
