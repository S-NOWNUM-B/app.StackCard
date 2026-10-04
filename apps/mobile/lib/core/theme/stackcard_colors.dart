import 'package:flutter/material.dart';

/// Утверждённая палитра StackCard для обеих тем.
@immutable
class StackCardColors extends ThemeExtension<StackCardColors> {
  const StackCardColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHover,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    this.acid = const Color(0xFFC8FF31),
    this.cyan = const Color(0xFF79E8F2),
    this.pink = const Color(0xFFFF79B7),
    this.ink = const Color(0xFF09090B),
    required this.success,
    required this.warning,
    required this.error,
  });

  static const dark = StackCardColors(
    background: Color(0xFF09090B),
    surface: Color(0xFF111113),
    surfaceElevated: Color(0xFF18181B),
    surfaceHover: Color(0xFF202024),
    border: Color(0xFF29292E),
    borderSubtle: Color(0xFF1F1F23),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    accent: Color(0xFFFF0012),
    accentHover: Color(0xFFE60010),
    accentSoft: Color(0xFF351014),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  );

  static const light = StackCardColors(
    background: Color(0xFFF5F5F6),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFAFAFA),
    surfaceHover: Color(0xFFEFEFF1),
    border: Color(0xFFDEDEE3),
    borderSubtle: Color(0xFFE8E8EC),
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF52525B),
    textMuted: Color(0xFFA1A1AA),
    accent: Color(0xFFFF0012),
    accentHover: Color(0xFFE60010),
    accentSoft: Color(0xFFFFE5E7),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
  );

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHover;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color acid;
  final Color cyan;
  final Color pink;
  final Color ink;
  final Color success;
  final Color warning;
  final Color error;

  @override
  StackCardColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHover,
    Color? border,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentHover,
    Color? accentSoft,
    Color? acid,
    Color? cyan,
    Color? pink,
    Color? ink,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return StackCardColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSoft: accentSoft ?? this.accentSoft,
      acid: acid ?? this.acid,
      cyan: cyan ?? this.cyan,
      pink: pink ?? this.pink,
      ink: ink ?? this.ink,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  StackCardColors lerp(covariant StackCardColors? other, double t) {
    if (other == null) return this;
    return StackCardColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      acid: Color.lerp(acid, other.acid, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      pink: Color.lerp(pink, other.pink, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension StackCardColorsContext on BuildContext {
  StackCardColors get colors {
    final theme = Theme.of(this);
    return theme.extension<StackCardColors>() ??
        (theme.brightness == Brightness.dark
            ? StackCardColors.dark
            : StackCardColors.light);
  }
}
