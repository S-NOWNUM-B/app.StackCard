import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'app_diagnostics.dart';

final class FirebaseDiagnosticsSink implements DiagnosticsSink {
  FirebaseDiagnosticsSink(this._crashlytics);
  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _crashlytics.setCrashlyticsCollectionEnabled(enabled);

  @override
  Future<void> deleteUnsentReports() => _crashlytics.deleteUnsentReports();

  @override
  Future<void> record(
    DiagnosticCode code,
    StackTrace stack, {
    required bool fatal,
  }) => _crashlytics.recordError(
    'StackCard.${code.name}',
    stack,
    fatal: fatal,
    printDetails: false,
  );
}
