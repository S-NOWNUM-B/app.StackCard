enum AppTheme { dark, light, system }

enum AppLanguage { ru, en }

final class AppSettings {
  const AppSettings({
    this.theme = AppTheme.dark,
    this.language = AppLanguage.ru,
    this.showSourceDescriptions = true,
    this.reducedMotion = false,
  });

  final AppTheme theme;
  final AppLanguage language;
  final bool showSourceDescriptions;
  final bool reducedMotion;

  AppSettings copyWith({
    AppTheme? theme,
    AppLanguage? language,
    bool? showSourceDescriptions,
    bool? reducedMotion,
  }) => AppSettings(
    theme: theme ?? this.theme,
    language: language ?? this.language,
    showSourceDescriptions:
        showSourceDescriptions ?? this.showSourceDescriptions,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      theme == other.theme &&
      language == other.language &&
      showSourceDescriptions == other.showSourceDescriptions &&
      reducedMotion == other.reducedMotion;

  @override
  int get hashCode =>
      Object.hash(theme, language, showSourceDescriptions, reducedMotion);
}
