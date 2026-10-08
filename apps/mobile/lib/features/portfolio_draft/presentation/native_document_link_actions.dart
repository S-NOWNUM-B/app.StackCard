import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/document_publication.dart';

/// Открывает подтверждённую public ссылку через системные Android/iOS действия.
final class NativeDocumentLinkActions implements DocumentLinkActions {
  const NativeDocumentLinkActions({
    this._channel = const MethodChannel('stackcard/document_links'),
  });

  final MethodChannel _channel;

  @override
  Future<void> open(Uri url) => _invoke('open', url);

  @override
  Future<void> share(Uri url) => _invoke('share', url);

  Future<void> _invoke(String method, Uri url) async {
    if (!url.hasAuthority ||
        (url.scheme != 'https' && url.scheme != 'http') ||
        url.host.isEmpty ||
        url.authority.contains('@') ||
        url.userInfo.isNotEmpty ||
        url.port > 65535) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.invalidData,
      );
    }
    try {
      final accepted = await _channel
          .invokeMethod<Object?>(method, {'url': url.toString()})
          .timeout(const Duration(seconds: 10));
      if (accepted != true) {
        throw const DocumentPublicationFailure(
          DocumentPublicationFailureKind.unavailable,
        );
      }
    } on MissingPluginException {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.unavailable,
      );
    } on PlatformException catch (error) {
      throw DocumentPublicationFailure(switch (error.code) {
        'invalid_url' => DocumentPublicationFailureKind.invalidData,
        _ => DocumentPublicationFailureKind.unavailable,
      });
    } on TimeoutException {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.unavailable,
      );
    }
  }
}
