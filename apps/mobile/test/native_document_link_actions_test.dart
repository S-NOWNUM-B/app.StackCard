import 'dart:async';

import 'package:app_stackcard/features/portfolio_draft/domain/document_publication.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/native_document_link_actions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stackcard/document_links');
  const actions = NativeDocumentLinkActions();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final url = Uri.parse('https://example.test/d/public-document');

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Matcher failure(DocumentPublicationFailureKind kind) =>
      isA<DocumentPublicationFailure>().having(
        (error) => error.kind,
        'kind',
        kind,
      );

  test(
    'open and share send only the confirmed URL to the native channel',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });

      await actions.open(url);
      await actions.share(url);

      expect(calls.map((call) => call.method), ['open', 'share']);
      expect(calls.map((call) => call.arguments), [
        {'url': url.toString()},
        {'url': url.toString()},
      ]);
    },
  );

  test('http emulator URL is forwarded without rewriting it', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });
    const value = 'http://127.0.0.1:3000/d/public-document';

    await actions.open(Uri.parse(value));

    expect(captured?.arguments, {'url': value});
  });

  for (final invalid in [
    '',
    '/d/public-document',
    'file:///tmp/document',
    'mailto:person@example.test',
    'javascript:alert(1)',
    'https://',
    'https://person:password@example.test/d/public-document',
    'https://person@example.test/d/public-document',
    'https://example.test:65536/d/public-document',
  ]) {
    test('rejects $invalid before the native channel is invoked', () async {
      var invoked = false;
      messenger.setMockMethodCallHandler(channel, (_) async {
        invoked = true;
        return true;
      });

      for (final action in [actions.open, actions.share]) {
        await expectLater(
          action(Uri.parse(invalid)),
          throwsA(failure(DocumentPublicationFailureKind.invalidData)),
        );
      }
      expect(invoked, isFalse);
    });
  }

  test('URI normalization never forwards empty credential syntax', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });

    await actions.open(Uri.parse('https://@example.test/d/public-document'));

    expect(captured?.arguments, {
      'url': 'https://example.test/d/public-document',
    });
  });

  test('missing native handler reports a typed unavailable failure', () async {
    await expectLater(
      actions.open(url),
      throwsA(failure(DocumentPublicationFailureKind.unavailable)),
    );
  });

  for (final code in ['unavailable', 'unsupported', 'action_failed']) {
    test('maps native $code to a typed unavailable failure', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: code,
          message: 'private platform details',
        );
      });

      await expectLater(
        actions.share(url),
        throwsA(failure(DocumentPublicationFailureKind.unavailable)),
      );
    });
  }

  test('maps native invalid URL to a typed validation failure', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'invalid_url');
    });

    await expectLater(
      actions.open(url),
      throwsA(failure(DocumentPublicationFailureKind.invalidData)),
    );
  });

  for (final response in [
    null,
    false,
    'true',
    {'accepted': true},
  ]) {
    test('does not report success for native response $response', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => response);

      await expectLater(
        actions.share(url),
        throwsA(failure(DocumentPublicationFailureKind.unavailable)),
      );
    });
  }

  testWidgets('native timeout releases the action with a typed failure', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    final checked = expectLater(
      actions.open(url),
      throwsA(failure(DocumentPublicationFailureKind.unavailable)),
    );

    await tester.pump(const Duration(seconds: 11));
    await checked;
    pending.complete(true);
    await tester.pump();
  });
}
