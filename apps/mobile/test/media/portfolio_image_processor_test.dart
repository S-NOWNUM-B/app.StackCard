import 'package:app_stackcard/features/media/media.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

Matcher _failure(PortfolioMediaFailureKind kind) => isA<PortfolioMediaFailure>()
    .having((failure) => failure.kind, 'kind', kind);

class _Picker extends Fake implements ImagePicker {
  XFile? file;
  Object? failure;
  ImageSource? source;
  bool? metadata;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    metadata = requestFullMetadata;
    if (failure != null) throw failure!;
    return file;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const processor = PortfolioImageProcessor();

  test('Prepared bytes copy caller data and cannot be mutated', () {
    final original = Uint8List.fromList([1, 2, 3]);
    final prepared = PreparedPortfolioImage(original);
    original[0] = 5;
    expect(prepared.bytes, [1, 2, 3]);
    expect(() => prepared.bytes[0] = 8, throwsUnsupportedError);
  });

  test('MIME declaration cannot disguise SVG, HEIC or a PNG as JPEG', () async {
    for (final bytes in [
      Uint8List.fromList('<svg></svg>'.codeUnits),
      Uint8List.fromList([0, 0, 0, 12, ...'ftypheic'.codeUnits]),
    ]) {
      await expectLater(
        processor.prepare(bytes, mimeType: 'image/jpeg'),
        throwsA(_failure(PortfolioMediaFailureKind.invalidType)),
      );
    }
    final png = image.encodePng(image.Image(width: 1, height: 1));
    await expectLater(
      processor.prepare(png, mimeType: 'image/jpeg'),
      throwsA(_failure(PortfolioMediaFailureKind.invalidType)),
    );
  });

  test(
    'Original file limit and empty/corrupt image failures are typed',
    () async {
      await expectLater(
        processor.prepare(Uint8List(portfolioImageOriginalMaxBytes + 1)),
        throwsA(_failure(PortfolioMediaFailureKind.tooLarge)),
      );
      await expectLater(
        processor.prepare(Uint8List(0)),
        throwsA(_failure(PortfolioMediaFailureKind.invalidImage)),
      );
      await expectLater(
        processor.prepare(Uint8List.fromList([0xff, 0xd8, 0xff, 0x00])),
        throwsA(_failure(PortfolioMediaFailureKind.invalidImage)),
      );
    },
  );

  test('PNG header pixel bomb is rejected before decoding pixels', () async {
    final png = image.encodePng(image.Image(width: 1, height: 1));
    final patched = Uint8List.fromList(png);
    final view = ByteData.sublistView(patched);
    view.setUint32(16, 8192);
    view.setUint32(20, 8192);
    var crc = 0xffffffff;
    for (final byte in patched.sublist(12, 29)) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
      }
    }
    view.setUint32(29, crc ^ 0xffffffff);
    await expectLater(
      processor.prepare(patched),
      throwsA(_failure(PortfolioMediaFailureKind.tooLarge)),
    );
  });

  test(
    'Resize preserves aspect and alpha is flattened on white as JPEG',
    () async {
      final original = image.Image(width: 2000, height: 1000, numChannels: 4);
      original.exif.imageIfd.imageDescription = 'private location description';
      final prepared = await processor.prepare(
        image.encodePng(original),
        mimeType: 'image/png',
      );
      final decoded = image.decodeJpg(prepared.bytes)!;
      expect(decoded.width, 1600);
      expect(decoded.height, 800);
      expect(decoded.getPixel(0, 0).r, greaterThan(245));
      expect(decoded.getPixel(0, 0).g, greaterThan(245));
      expect(decoded.getPixel(0, 0).b, greaterThan(245));
      expect(decoded.exif.imageIfd.imageDescription, isNull);
      expect(prepared.bytes.length, lessThanOrEqualTo(portfolioImageMaxBytes));
      await processor.validatePrepared(prepared.bytes);
    },
  );

  test('JPEG orientation is baked and EXIF is removed', () async {
    final original = image.Image(width: 40, height: 20);
    original.exif.imageIfd.orientation = 6;
    original.exif.imageIfd.imageDescription = 'private EXIF';
    final prepared = await processor.prepare(image.encodeJpg(original));
    final decoded = image.decodeJpg(prepared.bytes)!;
    expect((decoded.width, decoded.height), (20, 40));
    expect(decoded.exif.imageIfd.hasOrientation, isFalse);
    expect(decoded.exif.imageIfd.imageDescription, isNull);
  });

  test('WebP is decoded and re-encoded as a bounded JPEG', () async {
    final original = image.Image(width: 6, height: 4);
    image.fill(original, color: image.ColorRgb8(20, 120, 200));
    final prepared = await processor.prepare(
      image.encodeWebP(original),
      mimeType: 'image/webp',
    );
    final decoded = image.decodeJpg(prepared.bytes)!;
    expect((decoded.width, decoded.height), (6, 4));
    expect(decoded.getPixel(0, 0).b, greaterThan(180));
  });

  test(
    'Prepared boundary rejects oversized output and non-JPEG input',
    () async {
      await expectLater(
        processor.validatePrepared(Uint8List(portfolioImageMaxBytes + 1)),
        throwsA(_failure(PortfolioMediaFailureKind.tooLarge)),
      );
      await expectLater(
        processor.validatePrepared(
          image.encodePng(image.Image(width: 1, height: 1)),
        ),
        throwsA(_failure(PortfolioMediaFailureKind.invalidType)),
      );
      await expectLater(
        processor.validatePrepared(
          image.encodeJpg(image.Image(width: 1601, height: 1)),
        ),
        throwsA(_failure(PortfolioMediaFailureKind.tooLarge)),
      );
    },
  );

  test(
    'Native picker preserves cancellation and maps permission failure',
    () async {
      final sdk = _Picker();
      final picker = NativePortfolioImagePicker(picker: sdk);
      expect(await picker.pick(PortfolioImageSource.gallery), isNull);
      expect(sdk.source, ImageSource.gallery);
      expect(sdk.metadata, isFalse);
      sdk.failure = PlatformException(
        code: 'camera_access_denied',
        message: 'private raw message',
      );
      await expectLater(
        picker.pick(PortfolioImageSource.camera),
        throwsA(_failure(PortfolioMediaFailureKind.permissionDenied)),
      );
      sdk.failure = null;
      sdk.file = XFile.fromData(
        image.encodePng(image.Image(width: 3, height: 2)),
        mimeType: 'image/png',
      );
      expect(
        await picker.pick(PortfolioImageSource.gallery),
        isA<PreparedPortfolioImage>(),
      );
    },
  );

  test(
    'Private media paths require exact owner, lowercase UUID and full match',
    () {
      const path = 'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg';
      expect(isPortfolioMediaPathForOwner(path, 'owner'), isTrue);
      for (final invalid in [
        path.replaceFirst('owner', 'other'),
        '$path\n',
        '$path/child',
        path.replaceFirst('abcdef', 'ABCDEF'),
        path.replaceFirst('.jpg', '.png'),
        'https://example.dev/$path',
      ]) {
        expect(isPortfolioMediaPathForOwner(invalid, 'owner'), isFalse);
      }
    },
  );
}
