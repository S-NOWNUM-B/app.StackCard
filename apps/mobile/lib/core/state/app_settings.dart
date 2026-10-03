enum AppTheme { dark, light, system }

enum AppLanguage { ru, en }

final class AppSettings {
  const AppSettings({
    this.theme = AppTheme.dark,
    this.language = AppLanguage.ru,
    this.showSourceDescriptions = true,
  });

  final AppTheme theme;
  final AppLanguage language;
  final bool showSourceDescriptions;

  AppSettings copyWith({
    AppTheme? theme,
    AppLanguage? language,
    bool? showSourceDescriptions,
  }) => AppSettings(
    theme: theme ?? this.theme,
    language: language ?? this.language,
    showSourceDescriptions:
        showSourceDescriptions ?? this.showSourceDescriptions,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      theme == other.theme &&
      language == other.language &&
      showSourceDescriptions == other.showSourceDescriptions;

  @override
  int get hashCode => Object.hash(theme, language, showSourceDescriptions);
}
