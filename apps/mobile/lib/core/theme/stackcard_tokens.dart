/// Отступы в логических пикселях.
abstract final class StackCardSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double cardPadding = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class StackCardRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double xlarge = 24;
  static const double capsule = 999;
}

/// Размеры controls и single-column mobile content из Figma.
abstract final class StackCardSize {
  static const double touchTarget = 48;
  static const double inputHeight = 56;
  static const double contentMaxWidth = 600;
}

/// Static/reduced motion выбирается caller; эта группа не хранит preferences.
abstract final class StackCardMotion {
  static const fast = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 280);
}
