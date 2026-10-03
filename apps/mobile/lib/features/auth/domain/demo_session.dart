String? validateDemoEmail(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Укажите корректный email';

final class DemoSession {
  DemoSession({required String email}) : email = email.trim().toLowerCase();

  final String email;
}
