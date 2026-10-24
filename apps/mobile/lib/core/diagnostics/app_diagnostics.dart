import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDiagnosticsProvider = Provider<AppDiagnostics?>((_) => null);

enum DiagnosticCode { flutterFramework, unhandledAsync, acceptance }

abstract interface class DiagnosticsSink {
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> deleteUnsentReports();
  Future<void> record(
    DiagnosticCode code,
    StackTrace stack, {
    required bool fatal,
  });
}

/// Сообщения exception, widget context и пользовательские значения не принимаются.
final class AppDiagnostics extends ChangeNotifier {
  AppDiagnostics({
    required this._sink,
    required this._readConsent,
    required this._writeConsent,
  });

  final DiagnosticsSink _sink;
  final Future<bool> Function() _readConsent;
  final Future<void> Function(bool) _writeConsent;
  bool _enabled = false;
  bool _busy = false;
  bool _failed = false;
  bool _disposed = false;
  int _reports = 0;
  VoidCallback? _restoreHandlers;
  bool get enabled => _enabled;
  bool get busy => _busy;
  bool get failed => _failed;

  Future<void> initialize() async {
    try {
      final consent = await _readConsent();
      await _sink.setCollectionEnabled(consent);
      if (!consent) await _sink.deleteUnsentReports();
      _enabled = consent;
    } catch (_) {
      _failed = true;
      await _disableSink();
    }
  }

  Future<void> _disableSink() async {
    _enabled = false;
    try {
      await _sink.setCollectionEnabled(false);
      await _sink.deleteUnsentReports();
    } catch (_) {
      _failed = true;
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_busy || _disposed) return;
    _busy = true;
    _failed = false;
    // До ACK настройки никакие новые Dart reports не записываются.
    _enabled = false;
    notifyListeners();
    try {
      await _sink.setCollectionEnabled(false);
      await _sink.deleteUnsentReports();
      await _writeConsent(value);
      if (value) await _sink.setCollectionEnabled(true);
      _enabled = value;
    } catch (_) {
      _failed = true;
      await _disableSink();
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> report(
    DiagnosticCode code,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    if (!_enabled || _busy || _disposed || _reports >= 20) return;
    _reports++;
    try {
      await _sink.record(code, diagnosticStack(stack), fatal: fatal);
    } catch (_) {
      // Сбой диагностики не вызывает рекурсию в глобальном error handler.
    }
  }

  void installErrorHandlers() {
    if (_restoreHandlers != null || _disposed) return;
    final previousFlutter = FlutterError.onError;
    final previousAsync = PlatformDispatcher.instance.onError;
    void flutterHandler(FlutterErrorDetails details) {
      report(
        DiagnosticCode.flutterFramework,
        details.stack ?? StackTrace.empty,
      ).ignore();
      // Debug console сохраняет средства разработки; в release raw details не выводятся.
      if (kDebugMode) previousFlutter?.call(details);
    }

    bool asyncHandler(Object error, StackTrace stack) {
      report(DiagnosticCode.unhandledAsync, stack, fatal: true).ignore();
      if (kDebugMode) return previousAsync?.call(error, stack) ?? false;
      return true;
    }

    FlutterError.onError = flutterHandler;
    PlatformDispatcher.instance.onError = asyncHandler;
    _restoreHandlers = () {
      if (FlutterError.onError == flutterHandler) {
        FlutterError.onError = previousFlutter;
      }
      if (PlatformDispatcher.instance.onError == asyncHandler) {
        PlatformDispatcher.instance.onError = previousAsync;
      }
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _enabled = false;
    _restoreHandlers?.call();
    super.dispose();
  }
}

/// Только package-relative Dart source positions, без имён функций, URI и путей устройства.
StackTrace diagnosticStack(StackTrace source) {
  final frames =
      RegExp(
            r'\(package:app_stackcard/([a-zA-Z0-9_/]+\.dart):([0-9]{1,7}):([0-9]{1,7})\)',
          )
          .allMatches(source.toString())
          .where((frame) => _diagnosticSources.contains(frame[1]))
          .take(32)
          .toList();
  if (frames.isEmpty) {
    // Непустой redacted marker запрещает SDK подставить несокращённый StackTrace.current.
    return StackTrace.fromString(
      '#0 StackCard.redacted (package:app_stackcard/core/diagnostics/app_diagnostics.dart:0:0)',
    );
  }
  return StackTrace.fromString(
    [
      for (var index = 0; index < frames.length; index++)
        '#$index StackCard.frame (package:app_stackcard/${frames[index][1]}:${frames[index][2]}:${frames[index][3]})',
    ].join('\n'),
  );
}

// Явный allowlist: произвольный текст даже внутри поддельного package URI не отправляется.
const _diagnosticSources = {
  'main.dart',
  'app/local_runtime.dart',
  'core/diagnostics/app_diagnostics.dart',
  'core/state/appearance_controller.dart',
  'features/auth/presentation/auth_controller.dart',
  'features/auth/presentation/sign_in_screen.dart',
  'features/auth/presentation/personalization_screen.dart',
  'features/home/home_screen.dart',
  'features/projects/presentation/projects_screen.dart',
  'features/settings/settings_screen.dart',
  'features/settings/settings_account_screen.dart',
  'features/portfolio_draft/presentation/portfolio_draft_controller.dart',
  'features/portfolio_draft/presentation/main_portfolio_editor_screen.dart',
  'features/portfolio_draft/presentation/developer_card_screen.dart',
  'features/portfolio_draft/presentation/portfolio_document_publication_screen.dart',
  'features/github_import/presentation/github_import_controller.dart',
  'features/notifications/notifications_controller.dart',
  'features/inbox/presentation/inbox_screen.dart',
};
