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
      borderSide: BorderSide(color: colors.controlOutline),
    );
    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: colors.surfaceElevated,
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
          borderSide: BorderSide(color: colors.focus, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        disabledBorder: border.copyWith(
          borderSide: BorderSide(color: colors.controlOutline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: (base.filledButtonTheme.style ?? const ButtonStyle()).merge(
          ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(
              Size(StackCardSize.touchTarget, StackCardSize.touchTarget),
            ),
            textStyle: WidgetStatePropertyAll(base.textTheme.titleMedium),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StackCardRadius.medium),
              ),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textMeta,
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
        selectionColor: colors.primary.withValues(alpha: 0.25),
        selectionHandleColor: colors.textPrimary,
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: colors.accentText,
      ),
    );
  }

  static ThemeData _build(Brightness brightness, StackCardColors colors) {
    final isDark = brightness == Brightness.dark;
    final inverse = isDark ? StackCardColors.light : StackCardColors.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      // Primary fill и ink точно соответствуют обеим Figma modes.
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.accentSoft,
      onPrimaryContainer: colors.textPrimary,
      secondary: colors.textPrimary,
      onSecondary: colors.background,
      secondaryContainer: colors.surfaceHover,
      onSecondaryContainer: colors.textPrimary,
      tertiary: colors.sourceText,
      onTertiary: isDark ? colors.background : colors.surface,
      tertiaryContainer: colors.surfaceElevated,
      onTertiaryContainer: colors.textPrimary,
      error: colors.error,
      onError: isDark ? colors.background : colors.surface,
      errorContainer: colors.surfaceElevated,
      onErrorContainer: colors.error,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      surfaceDim: colors.background,
      surfaceBright: colors.surfaceHover,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surfaceElevated,
      surfaceContainerHighest: colors.surfaceHover,
      outline: colors.controlOutline,
      outlineVariant: colors.border,
      inverseSurface: inverse.surface,
      onInverseSurface: inverse.textPrimary,
      inversePrimary: colors.primary,
      shadow: StackCardColors.dark.background,
      scrim: StackCardColors.dark.background,
      surfaceTint: Colors.transparent,
    );
    // Десять Manrope styles из принятой DS; Flutter roles без новой scale.
    final textTheme = TextTheme(
      displayLarge: _text(40, FontWeight.w800, 1.2, -1),
      displayMedium: _text(40, FontWeight.w800, 1.2, -1),
      displaySmall: _text(40, FontWeight.w800, 1.2, -1),
      headlineLarge: _text(28, FontWeight.w700, 1.2, -0.6),
      headlineMedium: _text(28, FontWeight.w700, 1.2, -0.6),
      headlineSmall: _text(24, FontWeight.w700, 1.25, -0.4),
      titleLarge: _text(20, FontWeight.w700, 1.3, -0.3),
      titleMedium: _text(16, FontWeight.w600, 1.4, -0.1),
      titleSmall: _text(14, FontWeight.w700, 1.3, 0),
      bodyLarge: _text(16, FontWeight.w400, 1.5, 0),
      bodyMedium: _text(14, FontWeight.w400, 1.5, 0),
      bodySmall: _text(12, FontWeight.w400, 1.5, 0),
      labelLarge: _text(16, FontWeight.w600, 1.4, -0.1),
      labelMedium: _text(14, FontWeight.w700, 1.3, 0),
      labelSmall: _text(12, FontWeight.w600, 1.5, 0),
    ).apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);
    final controlBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(StackCardRadius.medium),
      borderSide: BorderSide(color: colors.controlOutline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Manrope',
      fontFamilyFallback: const ['Noto Sans'],
      textTheme: textTheme,
      extensions: [colors],
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.borderSubtle,
      disabledColor: colors.textMeta,
      splashFactory: NoSplash.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceHover,
          disabledForegroundColor: colors.textMeta,
          minimumSize: const Size(
            StackCardSize.touchTarget,
            StackCardSize.touchTarget,
          ),
          padding: const EdgeInsets.all(StackCardSpacing.sm),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: colors.primaryOutline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StackCardRadius.medium),
          ),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textMeta,
          minimumSize: const Size(
            StackCardSize.touchTarget,
            StackCardSize.touchTarget,
          ),
          textStyle: textTheme.labelLarge,
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
          borderRadius: BorderRadius.circular(StackCardRadius.large),
          side: BorderSide(color: colors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.all(StackCardSpacing.lg),
        labelStyle: textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: colors.textMeta,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: colors.textMeta),
        // Сообщение остаётся читаемым и на фоне страницы в light.
        errorStyle: textTheme.bodySmall?.copyWith(color: colors.error),
        errorMaxLines: 3,
        border: controlBorder,
        enabledBorder: controlBorder,
        focusedBorder: controlBorder.copyWith(
          borderSide: BorderSide(color: colors.focus, width: 2),
        ),
        errorBorder: controlBorder.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: controlBorder.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        disabledBorder: controlBorder.copyWith(
          borderSide: BorderSide(color: colors.controlOutline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primary,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.onPrimary
                : colors.textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary,
        selectedIconTheme: IconThemeData(color: colors.onPrimary),
        unselectedIconTheme: IconThemeData(color: colors.textPrimary),
        selectedLabelTextStyle: textTheme.labelMedium,
        unselectedLabelTextStyle: textTheme.labelMedium,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accentText,
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
      fontFamily: 'Manrope',
      fontFamilyFallback: const ['Noto Sans'],
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
