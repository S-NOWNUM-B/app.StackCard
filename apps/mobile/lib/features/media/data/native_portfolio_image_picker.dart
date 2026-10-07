import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/portfolio_media.dart';
import 'portfolio_image_processor.dart';

final class NativePortfolioImagePicker implements PortfolioImagePicker {
  NativePortfolioImagePicker({
    ImagePicker? picker,
    this._processor = const PortfolioImageProcessor(),
  }) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final PortfolioImageProcessor _processor;
  bool _selecting = false;

  @override
  Future<PreparedPortfolioImage?> pick(PortfolioImageSource source) async {
    if (_selecting) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);
    }
    _selecting = true;
    try {
      final file = await _picker.pickImage(
        source: source == PortfolioImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      final length = await file.length().timeout(const Duration(seconds: 10));
      if (length > portfolioImageOriginalMaxBytes) {
        throw const PortfolioMediaFailure(PortfolioMediaFailureKind.tooLarge);
      }
      final bytes = await file.readAsBytes().timeout(
        const Duration(seconds: 10),
      );
      return await _processor.prepare(bytes, mimeType: file.mimeType);
    } on PortfolioMediaFailure {
      rethrow;
    } on PlatformException catch (error) {
      throw PortfolioMediaFailure(switch (error.code) {
        'camera_access_denied' ||
        'camera_access_restricted' ||
        'photo_access_denied' ||
        'photo_access_restricted' => PortfolioMediaFailureKind.permissionDenied,
        _ => PortfolioMediaFailureKind.unavailable,
      });
    } catch (_) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);
    } finally {
      _selecting = false;
    }
  }
}
