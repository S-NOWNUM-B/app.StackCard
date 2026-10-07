import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

import '../domain/portfolio_media.dart';

/// Ограничения проверяются до выделения памяти под пиксели.
final class PortfolioImageProcessor {
  const PortfolioImageProcessor();

  Future<PreparedPortfolioImage> prepare(
    Uint8List bytes, {
    String? mimeType,
  }) async {
    try {
      final encoded = await compute(
        _prepareImage,
        (bytes: bytes, mimeType: mimeType),
        debugLabel: 'portfolio-image-prepare',
      ).timeout(const Duration(seconds: 30));
      return PreparedPortfolioImage(encoded);
    } on TimeoutException {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);
    }
  }

  Future<void> validatePrepared(Uint8List bytes) async {
    try {
      await compute(
        _validatePreparedImage,
        bytes,
        debugLabel: 'portfolio-image-validate',
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);
    }
  }
}

Uint8List _prepareImage(({Uint8List bytes, String? mimeType}) input) {
  try {
    final bytes = input.bytes;
    if (bytes.length > portfolioImageOriginalMaxBytes) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.tooLarge);
    }
    if (bytes.isEmpty) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidImage);
    }
    final mimeType = _imageMimeType(bytes);
    final suppliedMime = input.mimeType?.split(';').first.trim().toLowerCase();
    final normalizedMime = suppliedMime == 'image/jpg'
        ? 'image/jpeg'
        : suppliedMime;
    if (mimeType == null ||
        (normalizedMime != null &&
            normalizedMime.isNotEmpty &&
            normalizedMime != mimeType)) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidType);
    }
    final decoder = switch (mimeType) {
      'image/jpeg' => image.JpegDecoder(),
      'image/png' => image.PngDecoder(),
      _ => image.WebPDecoder(),
    };
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width < 1 ||
        info.height < 1 ||
        info.numFrames > 1) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidImage);
    }
    if (info.width > 8192 ||
        info.height > 8192 ||
        info.width * info.height > 24000000) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.tooLarge);
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidImage);
    }
    var resized = image.bakeOrientation(decoded);
    if (resized.width > portfolioImageMaxDimension ||
        resized.height > portfolioImageMaxDimension) {
      resized = image.copyResize(
        resized,
        width: resized.width >= resized.height
            ? portfolioImageMaxDimension
            : null,
        height: resized.height > resized.width
            ? portfolioImageMaxDimension
            : null,
        interpolation: image.Interpolation.average,
      );
    }
    // Новый RGB canvas исключает EXIF/GPS и задаёт белый фон прозрачному PNG.
    final flattened = image.Image(
      width: resized.width,
      height: resized.height,
      numChannels: 3,
    );
    image.fill(flattened, color: image.ColorRgb8(255, 255, 255));
    image.compositeImage(flattened, resized);
    final output = image.encodeJpg(flattened, quality: 85);
    if (output.length > portfolioImageMaxBytes) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.tooLarge);
    }
    return output;
  } on PortfolioMediaFailure {
    rethrow;
  } catch (_) {
    throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidImage);
  }
}

void _validatePreparedImage(Uint8List bytes) {
  if (bytes.length > portfolioImageMaxBytes) {
    throw const PortfolioMediaFailure(PortfolioMediaFailureKind.tooLarge);
  }
  if (_imageMimeType(bytes) != 'image/jpeg') {
    throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidType);
  }
  try {
    final decoder = image.JpegDecoder();
    final info = decoder.startDecode(bytes);
    if (info == null || info.width < 1 || info.height < 1) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidImage);
    }
    if (info.width > portfolioImageMaxDimension ||
        info.height > portfolioImageMaxDimension) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.tooLarge);
    }
    if (decoder.decodeFrame(0) == null) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidImage);
    }
  } on PortfolioMediaFailure {
    rethrow;
  } catch (_) {
    throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidImage);
  }
}

String? _imageMimeType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length >= 8 &&
      List.generate(
        8,
        (index) => bytes[index] == pngSignature[index],
      ).every((matches) => matches)) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}
