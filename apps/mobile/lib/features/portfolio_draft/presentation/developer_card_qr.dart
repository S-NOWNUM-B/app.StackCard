import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Чёрные целые модули, белая quiet zone в четыре модуля. Логотип не закрывает QR.
class DeveloperCardQr extends StatefulWidget {
  const DeveloperCardQr({super.key, required this.url});
  final Uri url;

  @override
  State<DeveloperCardQr> createState() => _DeveloperCardQrState();
}

class _DeveloperCardQrState extends State<DeveloperCardQr> {
  late QrImage _image;

  @override
  void initState() {
    super.initState();
    _encode();
  }

  @override
  void didUpdateWidget(DeveloperCardQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) _encode();
  }

  void _encode() {
    _image = QrImage(
      QrCode.fromData(
        data: widget.url.toString(),
        errorCorrectLevel: QrErrorCorrectLevel.M,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'QR-код портфолио: ${widget.url}',
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final modules = _image.moduleCount + 8;
          final available = constraints.maxWidth.clamp(0, 280).toDouble();
          final side = (available / modules).floorToDouble() * modules;
          return Center(
            child: SizedBox.square(
              key: const Key('developerCard.qr'),
              dimension: side,
              child: CustomPaint(painter: _QrPainter(_image)),
            ),
          );
        },
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);
  final QrImage image;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final module = size.width / (image.moduleCount + 8);
    final ink = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (image.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH(
              (col + 4) * module,
              (row + 4) * module,
              module,
              module,
            ),
            ink,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      !identical(image, oldDelegate.image);
}
