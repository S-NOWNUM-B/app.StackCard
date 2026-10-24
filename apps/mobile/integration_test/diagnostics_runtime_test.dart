import 'package:app_stackcard/core/diagnostics/app_diagnostics.dart';
import 'package:app_stackcard/core/diagnostics/firebase_diagnostics_sink.dart';
import 'package:app_stackcard/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Только synthetic report: ordinary Auth/draft/preferences не открываются.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_DIAGNOSTICS_ACCEPTANCE');
  testWidgets(
    'explicit opt-in sends a sanitized Crashlytics acceptance report',
    (tester) async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final sdk = FirebaseCrashlytics.instance;
      final previouslyEnabled = sdk.isCrashlyticsCollectionEnabled;
      final diagnostics = AppDiagnostics(
        sink: FirebaseDiagnosticsSink(sdk),
        readConsent: () async => false,
        writeConsent: (_) async {},
      );
      try {
        await diagnostics.initialize();
        expect(diagnostics.enabled, isFalse);
        await diagnostics.setEnabled(true);
        expect(diagnostics.enabled, isTrue);
        await diagnostics.report(
          DiagnosticCode.acceptance,
          StackTrace.current,
          fatal: true,
        );
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Диагностика: тестовый отчёт отправлен в SDK'),
              ),
            ),
          ),
        );
        // Fatal Dart report передаётся SDK без падения процесса; доставка проверяется в Console отдельно.
        await Future<void>.delayed(const Duration(seconds: 30));
      } finally {
        await diagnostics.setEnabled(false);
        diagnostics.dispose();
        await sdk.setCrashlyticsCollectionEnabled(previouslyEnabled);
      }
    },
    skip: !enabled,
  );
}
