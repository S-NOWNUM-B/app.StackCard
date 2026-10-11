import 'dart:typed_data';

import 'portfolio_content.dart';

enum PortfolioPdfFailureKind { invalidData, generation, unavailable }

final class PortfolioPdfFailure implements Exception {
  const PortfolioPdfFailure(this.kind);

  final PortfolioPdfFailureKind kind;

  @override
  String toString() => 'PortfolioPdfFailure(${kind.name})';
}

/// Генератор получает уже разрешённую сохранённую версию основного портфолио.
abstract interface class PortfolioPdfGenerator {
  Future<Uint8List> generate(
    PortfolioContent savedContent, {
    Uint8List? avatarBytes,
  });
}

abstract interface class PortfolioPdfFileActions {
  /// true означает запись файла, false — отмену системного диалога владельцем.
  Future<bool> savePdf(
    Uint8List bytes, {
    String filename = 'stackcard-portfolio.pdf',
  });
}

const portfolioPdfMaximumBytes = 20 * 1024 * 1024;

bool isPortfolioPdfFilename(String value) =>
    RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}\.pdf$').hasMatch(value);

bool isPortfolioPdfBytes(Uint8List bytes) =>
    bytes.length >= 5 &&
    bytes.length <= portfolioPdfMaximumBytes &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46 &&
    bytes[4] == 0x2d;
