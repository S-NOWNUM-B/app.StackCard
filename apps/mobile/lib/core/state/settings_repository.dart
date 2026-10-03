import 'app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

enum SettingsFailureKind { read, write }

final class SettingsFailure implements Exception {
  const SettingsFailure(this.kind);

  final SettingsFailureKind kind;

  @override
  String toString() => 'SettingsFailure(${kind.name})';
}
