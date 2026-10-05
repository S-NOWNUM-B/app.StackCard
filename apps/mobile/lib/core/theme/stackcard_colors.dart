import 'package:flutter/material.dart';

/// Семантические цвета принятой StackCard Design v2, R3.1–R3.4.
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
    this.acid = const Color(0xFFC7FF1A),
    this.cyan = const Color(0xFF6FE7F2),
    this.pink = const Color(0xFFFF6AB2),
    this.ink = const Color(0xFF070708),
    required this.success,
    required this.warning,
    required this.error,
    Color? primary,
    Color? onPrimary,
    Color? borderStrong,
    Color? paper,
    Color? sourceText,
    Color? focus,
    Color? textMeta,
    Color? controlOutline,
    Color? accentText,
    Color? successText,
    Color? primaryOutline,
  }) : primary = primary ?? accent,
       onPrimary = onPrimary ?? ink,
       borderStrong = borderStrong ?? border,
       paper = paper ?? const Color(0xFFF4F5F7),
       sourceText = sourceText ?? cyan,
       focus = focus ?? accent,
       textMeta = textMeta ?? textSecondary,
       controlOutline = controlOutline ?? textMuted,
       accentText = accentText ?? accent,
       successText = successText ?? success,
       primaryOutline = primaryOutline ?? onPrimary ?? ink;

  static const dark = StackCardColors(
    background: Color(0xFF070708),
    surface: Color(0xFF0D0E11),
    surfaceElevated: Color(0xFF14161B),
    surfaceHover: Color(0xFF1B1E24),
    border: Color(0xFF272A32),
    borderSubtle: Color(0xFF20232A),
    textPrimary: Color(0xFFF4F5F7),
    textSecondary: Color(0xFFA4A8B3),
    textMuted: Color(0xFF737884),
    accent: Color(0xFFC7FF1A),
    accentHover: Color(0xFFAFDC10),
    accentSoft: Color(0xFF252F0A),
    acid: Color(0xFFC7FF1A),
    cyan: Color(0xFF6FE7F2),
    pink: Color(0xFFFF6AB2),
    ink: Color(0xFF070708),
    success: Color(0xFF41E68A),
    warning: Color(0xFFFFD166),
    error: Color(0xFFF06272),
    primary: Color(0xFFC7FF1A),
    onPrimary: Color(0xFF070708),
    borderStrong: Color(0xFF373B46),
    paper: Color(0xFFF4F5F7),
    sourceText: Color(0xFF6FE7F2),
    focus: Color(0xFFC7FF1A),
    textMeta: Color(0xFFA4A8B3),
    controlOutline: Color(0xFF737884),
    accentText: Color(0xFFC7FF1A),
    successText: Color(0xFF41E68A),
    primaryOutline: Color(0xFFC7FF1A),
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
    textMuted: Color(0xFF676C77),
    accent: Color(0xFFC7FF1A),
    accentHover: Color(0xFFAFDC10),
    accentSoft: Color(0xFFEAF6C9),
    acid: Color(0xFFC7FF1A),
    cyan: Color(0xFF6FE7F2),
    pink: Color(0xFFFF6AB2),
    ink: Color(0xFF070708),
    success: Color(0xFF168449),
    warning: Color(0xFF996000),
    error: Color(0xFFC92D45),
    primary: Color(0xFFC7FF1A),
    onPrimary: Color(0xFF070708),
    borderStrong: Color(0xFFB8BBC4),
    paper: Color(0xFFF4F5F7),
    sourceText: Color(0xFF0B6570),
    focus: Color(0xFF526B00),
    textMeta: Color(0xFF676C77),
    controlOutline: Color(0xFF676C77),
    accentText: Color(0xFF526B00),
    successText: Color(0xFF147B44),
    primaryOutline: Color(0xFF070708),
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
  final Color primary;
  final Color onPrimary;
  final Color borderStrong;
  final Color paper;
  final Color sourceText;
  final Color focus;
  final Color textMeta;
  final Color controlOutline;
  final Color accentText;
  final Color successText;
  final Color primaryOutline;

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
    Color? primary,
    Color? onPrimary,
    Color? borderStrong,
    Color? paper,
    Color? sourceText,
    Color? focus,
    Color? textMeta,
    Color? controlOutline,
    Color? accentText,
    Color? successText,
    Color? primaryOutline,
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
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      borderStrong: borderStrong ?? this.borderStrong,
      paper: paper ?? this.paper,
      sourceText: sourceText ?? this.sourceText,
      focus: focus ?? this.focus,
      textMeta: textMeta ?? this.textMeta,
      controlOutline: controlOutline ?? this.controlOutline,
      accentText: accentText ?? this.accentText,
      successText: successText ?? this.successText,
      primaryOutline: primaryOutline ?? this.primaryOutline,
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
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      sourceText: Color.lerp(sourceText, other.sourceText, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      textMeta: Color.lerp(textMeta, other.textMeta, t)!,
      controlOutline: Color.lerp(controlOutline, other.controlOutline, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      primaryOutline: Color.lerp(primaryOutline, other.primaryOutline, t)!,
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
