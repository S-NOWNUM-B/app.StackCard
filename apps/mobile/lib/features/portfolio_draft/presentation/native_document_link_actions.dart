import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/document_publication.dart';
import '../domain/portfolio_pdf.dart';

/// Открывает подтверждённую public ссылку через системные Android/iOS действия.
final class NativeDocumentLinkActions
    implements DocumentLinkActions, PortfolioPdfFileActions {
  const NativeDocumentLinkActions({
    this._channel = const MethodChannel('stackcard/document_links'),
  });

  final MethodChannel _channel;

  @override
  Future<void> open(Uri url) => _invoke('open', url);

  @override
  Future<void> share(Uri url) => _invoke('share', url);

  @override
  Future<bool> savePdf(
    Uint8List bytes, {
    String filename = 'stackcard-portfolio.pdf',
  }) async {
    if (!isPortfolioPdfBytes(bytes) || !isPortfolioPdfFilename(filename)) {
      throw const PortfolioPdfFailure(PortfolioPdfFailureKind.invalidData);
    }
    try {
      // Системный picker остаётся открыт до выбора/отмены, без URL timeout.
      final saved = await _channel.invokeMethod<Object?>('savePdf', {
        'bytes': bytes,
        'filename': filename,
      });
      if (saved is! bool) {
        throw const PortfolioPdfFailure(PortfolioPdfFailureKind.unavailable);
      }
      return saved;
    } on MissingPluginException {
      throw const PortfolioPdfFailure(PortfolioPdfFailureKind.unavailable);
    } on PlatformException catch (error) {
      throw PortfolioPdfFailure(
        error.code == 'invalid_pdf'
            ? PortfolioPdfFailureKind.invalidData
            : PortfolioPdfFailureKind.unavailable,
      );
    }
  }

  Future<void> _invoke(String method, Uri url) async {
    final publicUrl =
        url.hasAuthority &&
        (url.scheme == 'https' || url.scheme == 'http') &&
        url.host.isNotEmpty &&
        !url.authority.contains('@') &&
        url.userInfo.isEmpty &&
        url.port <= 65535;
    final value = url.toString();
    final contactUrl =
        method == 'open' &&
        (RegExp(
              r"^mailto:[a-zA-Z0-9.!$&'*+/=_^`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)+$",
            ).hasMatch(value) ||
            RegExp(r'^tel:\+[0-9]{7,15}$').hasMatch(value));
    if (!publicUrl && !contactUrl) {
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
