import 'package:flutter/material.dart';

import 'stackcard_colors.dart';
import 'stackcard_tokens.dart';

abstract final class StackCardTheme {
  static final dark = _build(Brightness.dark, StackCardColors.dark);
  static final light = _build(Brightness.light, StackCardColors.light);

  /// Формы входа используют спокойные controls без ярких рекламных поверхностей.
  static ThemeData authentication(ThemeData base) {
    final colors =
        base.extension<StackCardColors>() ??
        (base.brightness == Brightness.dark
            ? StackCardColors.dark
            : StackCardColors.light);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(StackCardRadius.medium),
      borderSide: BorderSide(
        color: base.brightness == Brightness.dark
            ? colors.textMuted
            : colors.textSecondary,
      ),
    );
    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: base.textTheme.bodyLarge?.copyWith(
          color: colors.textSecondary,
        ),
        floatingLabelStyle: base.textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
        ),
        prefixIconColor: colors.textSecondary,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.textPrimary, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        disabledBorder: border.copyWith(
          borderSide: BorderSide(color: colors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
          textStyle: WidgetStatePropertyAll(base.textTheme.titleMedium),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StackCardRadius.medium),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textSecondary,
          alignment: Alignment.centerLeft,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: base.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StackCardRadius.medium),
          ),
        ),
      ),
      textSelectionTheme: base.textSelectionTheme.copyWith(
        cursorColor: colors.textPrimary,
        selectionColor: colors.cyan.withValues(alpha: 0.25),
        selectionHandleColor: colors.textPrimary,
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: base.colorScheme.primary,
      ),
    );
  }

  static ThemeData _build(Brightness brightness, StackCardColors colors) {
    final isDark = brightness == Brightness.dark;
    final inverse = isDark ? StackCardColors.light : StackCardColors.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      // Этот оттенок Signal Red сохраняет AA для белого текста кнопок.
      primary: colors.accentHover,
      onPrimary: Colors.white,
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
      displayLarge: _text(64, FontWeight.w500, 0.98, -3),
      displayMedium: _text(52, FontWeight.w500, 1.0, -2.4),
      displaySmall: _text(40, FontWeight.w500, 1.05, -1.8),
      headlineLarge: _text(36, FontWeight.w500, 1.08, -1.4),
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
    final controlBorder = UnderlineInputBorder(
      borderRadius: BorderRadius.circular(StackCardRadius.small),
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
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textSecondary,
        ),
      ),
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
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.acid,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.ink
                : colors.textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.acid,
        selectedIconTheme: IconThemeData(color: colors.ink),
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
