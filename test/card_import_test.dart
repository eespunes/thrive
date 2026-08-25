import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:family_money_management_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// The pure photo-import pipeline (issues #225-#227): EAN-13 and QR
// detection plus dominant-colour sampling, exercised on synthetically
// rendered images. The barcodes are drawn by package:barcode — an
// independent encoder — so the scanline decoder is tested against a
// known-good implementation, not itself.

/// Renders [code] with [symbology] as black bars/modules on a white image
/// with a quiet margin, optionally on a coloured background band around it.
img.Image _render(
  bc.Barcode symbology,
  String code, {
  int width = 480,
  int height = 180,
  int margin = 40,
  img.Color? background,
}) {
  final image = img.Image(
    width: width + 2 * margin,
    height: height + 2 * margin,
  );
  img.fill(image, color: background ?? img.ColorRgb8(255, 255, 255));
  img.fillRect(
    image,
    x1: margin ~/ 2,
    y1: margin ~/ 2,
    x2: image.width - margin ~/ 2,
    y2: image.height - margin ~/ 2,
    color: img.ColorRgb8(255, 255, 255),
  );
  for (final el in symbology.make(
    code,
    width: width.toDouble(),
    height: height.toDouble(),
  )) {
    if (el is bc.BarcodeBar && el.black) {
      img.fillRect(
        image,
        x1: margin + el.left.round(),
        y1: margin + el.top.round(),
        x2: margin + (el.left + el.width).round() - 1,
        y2: margin + (el.top + el.height).round() - 1,
        color: img.ColorRgb8(0, 0, 0),
      );
    }
  }
  return image;
}

void main() {
  const ean = '5901234123457';

  test('decodeEan13 reads a rendered EAN-13', () {
    expect(decodeEan13(_render(bc.Barcode.ean13(), ean)), ean);
  });

  test('decodeEan13 reads an upside-down barcode', () {
    final flipped = img.flipHorizontal(_render(bc.Barcode.ean13(), ean));
    expect(decodeEan13(flipped), ean);
  });

  test('decodeEan13 returns null on a blank image', () {
    final blank = img.Image(width: 200, height: 100);
    img.fill(blank, color: img.ColorRgb8(255, 255, 255));
    expect(decodeEan13(blank), isNull);
  });

  test('analyzeCardImage: EAN-13 photo → barcode + number', () {
    final bytes = img.encodePng(_render(bc.Barcode.ean13(), ean));
    final res = analyzeCardImage(bytes);
    expect(res.number, ean);
    expect(res.codeType, 'barcode');
    expect(res.numberDetected, isTrue);
  });

  test('analyzeCardImage: QR photo → qr + content', () {
    final bytes = img.encodePng(
      _render(bc.Barcode.qrCode(), '9876543210', width: 220, height: 220),
    );
    final res = analyzeCardImage(bytes);
    expect(res.number, '9876543210');
    expect(res.codeType, 'qr');
  });

  test('analyzeCardImage: garbage bytes → empty result, no throw', () {
    final res = analyzeCardImage(Uint8List.fromList([1, 2, 3, 4]));
    expect(res.numberDetected, isFalse);
    expect(res.colorSampled, isFalse);
  });

  test('analyzeCardImage samples the dominant colour around a barcode', () {
    final bytes = img.encodePng(
      _render(bc.Barcode.ean13(), ean, background: img.ColorRgb8(200, 30, 40)),
    );
    final res = analyzeCardImage(bytes);
    expect(res.colorSampled, isTrue);
    final c = res.color!;
    expect((c.r * 255).round(), greaterThan((c.g * 255).round()));
    expect((c.r * 255).round(), greaterThan((c.b * 255).round()));
  });

  test('dominantColorOf: saturated photo → its hue', () {
    final red = img.Image(width: 120, height: 80);
    img.fill(red, color: img.ColorRgb8(190, 25, 35));
    final c = dominantColorOf(red)!;
    expect((c.r * 255).round(), greaterThan(150));
    expect((c.g * 255).round(), lessThan(80));
  });

  test('dominantColorOf: grey/white photo → null (palette fallback)', () {
    final grey = img.Image(width: 120, height: 80);
    img.fill(grey, color: img.ColorRgb8(210, 212, 214));
    expect(dominantColorOf(grey), isNull);
    final dark = img.Image(width: 60, height: 40);
    img.fill(dark, color: img.ColorRgb8(10, 10, 12));
    expect(dominantColorOf(dark), isNull);
  });

  test('analyzeCardImage downscales very wide photos and still decodes', () {
    final big = img.copyResize(_render(bc.Barcode.ean13(), ean), width: 1600);
    final res = analyzeCardImage(img.encodePng(big));
    expect(res.number, ean);
  });
}
