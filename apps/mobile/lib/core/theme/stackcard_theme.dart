import 'package:flutter/material.dart';

import 'stackcard_colors.dart';
import 'stackcard_tokens.dart';

abstract final class StackCardTheme {
  static final dark = _build(Brightness.dark, StackCardColors.dark);
  static final light = _build(Brightness.light, StackCardColors.light);

  static ThemeData _build(Brightness brightness, StackCardColors colors) {
    final isDark = brightness == Brightness.dark;
    final inverse = isDark ? StackCardColors.light : StackCardColors.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      // Obsidian сохраняет AA для обычного текста на Signal Red.
      onPrimary: StackCardColors.dark.background,
      primaryContainer: colors.accentSoft,
      onPrimaryContainer: colors.textPrimary,
      secondary: colors.textPrimary,
      onSecondary: colors.background,
      secondaryContainer: colors.surfaceHover,
      onSecondaryContainer: colors.textPrimary,
      tertiary: colors.textSecondary,
      onTertiary: isDark ? colors.background : colors.surface,
      tertiaryContainer: colors.surfaceElevated,
      onTertiaryContainer: colors.textPrimary,
      error: colors.error,
      onError: isDark ? colors.background : colors.surface,
      errorContainer: colors.surfaceElevated,
      onErrorContainer: colors.textPrimary,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: isDark ? colors.textSecondary : colors.textPrimary,
      surfaceDim: colors.background,
      surfaceBright: colors.surfaceHover,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surfaceElevated,
      surfaceContainerHighest: colors.surfaceHover,
      outline: colors.textSecondary,
      outlineVariant: colors.border,
      inverseSurface: inverse.surface,
      onInverseSurface: inverse.textPrimary,
      inversePrimary: colors.accent,
      shadow: StackCardColors.dark.background,
      scrim: StackCardColors.dark.background,
      surfaceTint: Colors.transparent,
    );
    final textTheme = TextTheme(
      displayLarge: _text(48, FontWeight.w700, 1.1, -1.5),
      displayMedium: _text(40, FontWeight.w700, 1.15, -1.2),
      displaySmall: _text(36, FontWeight.w700, 1.15, -1),
      headlineLarge: _text(32, FontWeight.w700, 1.2, -0.8),
      headlineMedium: _text(28, FontWeight.w700, 1.2, -0.6),
      headlineSmall: _text(24, FontWeight.w700, 1.25, -0.4),
      titleLarge: _text(20, FontWeight.w700, 1.3, -0.3),
      titleMedium: _text(16, FontWeight.w600, 1.4, -0.1),
      titleSmall: _text(14, FontWeight.w600, 1.4, 0),
      bodyLarge: _text(16, FontWeight.w400, 1.5, 0),
      bodyMedium: _text(14, FontWeight.w400, 1.5, 0),
      bodySmall: _text(12, FontWeight.w400, 1.5, 0),
      labelLarge: _text(14, FontWeight.w700, 1.3, 0),
      labelMedium: _text(12, FontWeight.w600, 1.3, 0.1),
      labelSmall: _text(11, FontWeight.w600, 1.3, 0.2),
    ).apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);
    final controlBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(StackCardRadius.medium),
      borderSide: BorderSide(color: colors.textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'DM Sans',
      fontFamilyFallback: const ['Noto Sans'],
      textTheme: textTheme,
      extensions: [colors],
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.borderSubtle,
      disabledColor: colors.textSecondary,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StackCardRadius.xlarge),
          side: BorderSide(color: colors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.all(StackCardSpacing.lg),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        // Сообщение остаётся читаемым и на фоне страницы в light.
        errorStyle: textTheme.bodySmall,
        errorMaxLines: 3,
        border: controlBorder,
        enabledBorder: controlBorder,
        focusedBorder: controlBorder.copyWith(
          borderSide: BorderSide(color: colors.accent, width: 2),
        ),
        errorBorder: controlBorder.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: controlBorder.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        disabledBorder: controlBorder.copyWith(
          borderSide: BorderSide(color: colors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.surfaceHover,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.accent
                : colors.textPrimary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.surfaceHover,
        selectedIconTheme: IconThemeData(color: colors.accent),
        unselectedIconTheme: IconThemeData(color: colors.textPrimary),
        selectedLabelTextStyle: textTheme.labelMedium,
        unselectedLabelTextStyle: textTheme.labelMedium,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.surfaceHover,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(StackCardRadius.small),
        ),
        textStyle: textTheme.bodySmall,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: colors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StackCardRadius.medium),
          side: BorderSide(color: colors.border),
        ),
      ),
    );
  }

  static TextStyle _text(
    double size,
    FontWeight weight,
    double height,
    double letterSpacing,
  ) {
    return TextStyle(
      fontFamily: 'DM Sans',
      fontFamilyFallback: const ['Noto Sans'],
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
