part of 'package:family_money_management_app/main.dart';

/// Pure image-analysis pipeline behind "import a card from a photo"
/// (issues #225–#227): detects a QR code or an EAN-13 barcode in the photo
/// and samples its dominant colour. Plain functions of the image bytes —
/// no widget state, no I/O — so the whole importer is unit-tested.

/// What the importer managed to read from a card photo. [number] is null
/// when no code was detected (the review sheet then falls back to manual
/// entry); [color] is null when the photo has no dominant hue (the review
/// sheet then offers the palette instead).
class CardScanResult {
  const CardScanResult({this.number, this.codeType = 'barcode', this.color});
  final String? number;
  final String codeType;
  final Color? color;
  bool get numberDetected => number != null && number!.isNotEmpty;
  bool get colorSampled => color != null;
}

/// Runs the full detection pipeline on raw photo [bytes]. Never throws —
/// an undecodable image simply yields an empty result (issue #226: failures
/// fall back to manual entry, not an error).
CardScanResult analyzeCardImage(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) return const CardScanResult();
  // Downscale for speed; barcodes survive this fine at this width.
  final image = decoded.width > 1000
      ? img.copyResize(decoded, width: 1000)
      : decoded;
  final color = dominantColorOf(image);
  final qr = _decodeQr(image);
  if (qr != null && qr.isNotEmpty) {
    return CardScanResult(number: qr, codeType: 'qr', color: color);
  }
  final ean = decodeEan13(image);
  if (ean != null) {
    return CardScanResult(number: ean, codeType: 'barcode', color: color);
  }
  return CardScanResult(color: color);
}

String? _decodeQr(img.Image image) {
  try {
    final rgba = image.convert(numChannels: 4);
    final pixels = rgba
        .getBytes(order: img.ChannelOrder.abgr)
        .buffer
        .asInt32List();
    final source = RGBLuminanceSource(rgba.width, rgba.height, pixels);
    final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
    return QRCodeReader().decode(bitmap).text;
  } catch (_) {
    return null;
  }
}

// EAN-13 digit encodings as run-length widths of the 4 alternating runs in
// each 7-module digit (left digits start with a space, right with a bar —
// the widths are identical either way, which is all the matcher compares).
const List<List<int>> _kEanL = [
  [3, 2, 1, 1],
  [2, 2, 2, 1],
  [2, 1, 2, 2],
  [1, 4, 1, 1],
  [1, 1, 3, 2],
  [1, 2, 3, 1],
  [1, 1, 1, 4],
  [1, 3, 1, 2],
  [1, 2, 1, 3],
  [3, 1, 1, 2],
];

// First (implied) digit from the parity pattern of the six left digits:
// `false` = L(odd), `true` = G(even).
const List<List<bool>> _kEanParity = [
  [false, false, false, false, false, false],
  [false, false, true, false, true, true],
  [false, false, true, true, false, true],
  [false, false, true, true, true, false],
  [false, true, false, false, true, true],
  [false, true, true, false, false, true],
  [false, true, true, true, false, false],
  [false, true, false, true, false, true],
  [false, true, false, true, true, false],
  [false, true, true, false, true, false],
];

/// True when [digits] is a well-formed EAN-13 number (13 digits, valid
/// check digit) — also decides which symbology the card face renders.
bool isValidEan13(String digits) {
  if (digits.length != 13 || !RegExp(r'^[0-9]{13}$').hasMatch(digits)) {
    return false;
  }
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    final d = digits.codeUnitAt(i) - 0x30;
    sum += (i % 2 == 0) ? d : 3 * d;
  }
  return sum % 10 == 0;
}

/// Scanline EAN-13 decoder: tries several horizontal lines (both reading
/// directions), run-length encodes each against a mid-range threshold, and
/// decodes any 59-run window that matches guard + digit patterns and the
/// EAN check digit. Returns the 13 digits, or null when nothing decodes.
String? decodeEan13(img.Image image) {
  for (final frac in const [0.5, 0.4, 0.6, 0.3, 0.7, 0.2, 0.8, 0.45, 0.55]) {
    final y = (image.height * frac).round().clamp(0, image.height - 1);
    final runs = _rowRuns(image, y);
    if (runs == null) continue;
    final hit = _decodeRuns(runs) ?? _decodeRuns(runs.reversed.toList());
    if (hit != null) return hit;
  }
  return null;
}

/// Run-length encodes row [y]: luminance-thresholded, returned as
/// alternating (isDark, length) pairs flattened to lengths with the parity
/// convention "first run is white". Null when the row has no contrast.
List<int>? _rowRuns(img.Image image, int y) {
  final lum = List<int>.generate(image.width, (x) {
    final p = image.getPixel(x, y);
    return ((p.rNormalized + p.gNormalized + p.bNormalized) * 85).round();
  });
  var lo = 255, hi = 0;
  for (final v in lum) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  if (hi - lo < 60) return null;
  final threshold = (hi + lo) ~/ 2;
  final runs = <int>[];
  var dark = false; // enforced leading-white parity
  var len = 0;
  for (final v in lum) {
    final d = v < threshold;
    if (d == dark) {
      len++;
    } else {
      runs.add(len);
      dark = d;
      len = 1;
    }
  }
  runs.add(len);
  return runs;
}

String? _decodeRuns(List<int> runs) {
  // Runs alternate white/dark starting white (index parity: even = white),
  // so candidate start guards (dark 1-1-1) sit at odd indices.
  for (var i = 1; i + 59 <= runs.length; i += 2) {
    final module = (runs[i] + runs[i + 1] + runs[i + 2]) / 3.0;
    if (module <= 0.6) continue;
    if (!_isGuard(runs, i, 3, module)) continue;
    if (!_isGuard(runs, i + 27, 5, module)) continue; // middle guard
    if (!_isGuard(runs, i + 56, 3, module)) continue; // end guard
    final parities = <bool>[];
    final digits = <int>[];
    var ok = true;
    for (var d = 0; d < 6 && ok; d++) {
      final hit = _matchDigit(runs, i + 3 + d * 4, module, withParity: true);
      if (hit == null) {
        ok = false;
      } else {
        digits.add(hit.$1);
        parities.add(hit.$2);
      }
    }
    for (var d = 0; d < 6 && ok; d++) {
      final hit = _matchDigit(runs, i + 32 + d * 4, module, withParity: false);
      if (hit == null) {
        ok = false;
      } else {
        digits.add(hit.$1);
      }
    }
    if (!ok) continue;
    final first = _kEanParity.indexWhere((p) {
      for (var k = 0; k < 6; k++) {
        if (p[k] != parities[k]) return false;
      }
      return true;
    });
    if (first < 0) continue;
    final code = '$first${digits.join()}';
    if (isValidEan13(code)) return code;
  }
  return null;
}

bool _isGuard(List<int> runs, int at, int count, double module) {
  for (var k = 0; k < count; k++) {
    final w = runs[at + k] / module;
    if (w < 0.4 || w > 1.8) return false;
  }
  return true;
}

/// Matches the 4 runs at [at] against the digit tables, normalized to the
/// digit's 7-module width. Returns (digit, isGCode) or null when nothing
/// matches closely enough.
(int, bool)? _matchDigit(
  List<int> runs,
  int at,
  double module, {
  required bool withParity,
}) {
  final total = runs[at] + runs[at + 1] + runs[at + 2] + runs[at + 3];
  if (total <= 0 || (total / module) < 4.5 || (total / module) > 10.5) {
    return null;
  }
  final scaled = [for (var k = 0; k < 4; k++) runs[at + k] * 7.0 / total];
  var best = -1;
  var bestG = false;
  var bestErr = double.infinity;
  for (var d = 0; d < 10; d++) {
    final l = _kEanL[d];
    var errL = 0.0, errG = 0.0;
    for (var k = 0; k < 4; k++) {
      errL += (scaled[k] - l[k]).abs();
      errG += (scaled[k] - l[3 - k]).abs();
    }
    if (errL < bestErr) {
      bestErr = errL;
      best = d;
      bestG = false;
    }
    if (withParity && errG < bestErr) {
      bestErr = errG;
      best = d;
      bestG = true;
    }
  }
  if (best < 0 || bestErr > 1.8) return null;
  return (best, bestG);
}

/// Samples the photo's dominant hue: saturated pixels are bucketed by hue,
/// and the winning bucket's average colour is returned when it clearly
/// dominates. Null when the photo has no dominant hue (mostly white/grey
/// cards) — the caller then offers the palette instead, never a random
/// colour (issue #225).
Color? dominantColorOf(img.Image image) {
  const bins = 12;
  final counts = List<int>.filled(bins, 0);
  final sumR = List<double>.filled(bins, 0);
  final sumG = List<double>.filled(bins, 0);
  final sumB = List<double>.filled(bins, 0);
  var sampled = 0;
  final stepX = math.max(1, image.width ~/ 80);
  final stepY = math.max(1, image.height ~/ 80);
  for (var y = 0; y < image.height; y += stepY) {
    for (var x = 0; x < image.width; x += stepX) {
      final p = image.getPixel(x, y);
      final r = p.rNormalized.toDouble();
      final g = p.gNormalized.toDouble();
      final b = p.bNormalized.toDouble();
      sampled++;
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final delta = maxC - minC;
      if (maxC < 0.18 || maxC > 0.97 || delta / math.max(maxC, 1e-6) < 0.3) {
        continue; // too dark, blown out, or not saturated enough
      }
      double hue;
      if (delta == 0) {
        hue = 0;
      } else if (maxC == r) {
        hue = 60 * (((g - b) / delta) % 6);
      } else if (maxC == g) {
        hue = 60 * (((b - r) / delta) + 2);
      } else {
        hue = 60 * (((r - g) / delta) + 4);
      }
      if (hue < 0) hue += 360;
      final bin = (hue / (360 / bins)).floor().clamp(0, bins - 1);
      counts[bin]++;
      sumR[bin] += r;
      sumG[bin] += g;
      sumB[bin] += b;
    }
  }
  if (sampled == 0) return null;
  var best = 0;
  for (var k = 1; k < bins; k++) {
    if (counts[k] > counts[best]) best = k;
  }
  final n = counts[best];
  // A colour only counts as "dominant" when it covers a real share of the
  // photo — otherwise the review sheet falls back to the palette.
  if (n < 24 || n / sampled < 0.06) return null;
  return Color.fromARGB(
    0xff,
    (sumR[best] / n * 255).round().clamp(0, 255),
    (sumG[best] / n * 255).round().clamp(0, 255),
    (sumB[best] / n * 255).round().clamp(0, 255),
  );
}
