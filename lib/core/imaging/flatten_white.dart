import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Composites an image with an alpha channel onto white paper.
///
/// PDFKit (and Android's PdfRenderer) draw each page into a buffer that starts
/// as transparent black — RGB 0, alpha 0. Digital PDFs rarely paint a white
/// rectangle behind the text, so "the page" is mostly those empty pixels.
/// Taking only the RGB channels turns that into a solid black scan.
img.Image flattenOntoWhite(img.Image source) {
  if (source.numChannels < 4) return source;

  final out = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  for (final pixel in source) {
    final a = pixel.a / 255.0;
    out.setPixelRgb(
      pixel.x,
      pixel.y,
      _blend(pixel.r.toInt(), a),
      _blend(pixel.g.toInt(), a),
      _blend(pixel.b.toInt(), a),
    );
  }
  return out;
}

/// Straight-alpha blend of [channel] over white.
int _blend(int channel, double a) {
  return (channel * a + 255 * (1 - a)).round().clamp(0, 255);
}

/// Encodes [source] as a JPEG after flattening any alpha onto white.
Uint8List flattenEncodedOntoWhiteJpeg(Uint8List encoded, {int quality = 92}) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) return encoded;
  final flat = flattenOntoWhite(decoded);
  return Uint8List.fromList(img.encodeJpg(flat, quality: quality));
}

/// PDFKit fills `premultipliedLast` RGBA. Transparent areas are (0,0,0,0).
///
/// `C_out = C_src + 255 * (1 - a)` restores the page onto white without
/// double-multiplying the ink that is already premultiplied.
Uint8List flattenPremultipliedRgbaToJpeg(
  Uint8List rgba, {
  required int width,
  required int height,
  int quality = 92,
}) {
  if (rgba.length < width * height * 4) {
    throw ArgumentError('RGBA buffer is smaller than width × height × 4');
  }
  final out = img.Image(width: width, height: height, numChannels: 3);
  var i = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final a = rgba[i + 3];
      final inv = 255 - a;
      out.setPixelRgb(
        x,
        y,
        (rgba[i] + inv).clamp(0, 255),
        (rgba[i + 1] + inv).clamp(0, 255),
        (rgba[i + 2] + inv).clamp(0, 255),
      );
      i += 4;
    }
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}

/// Same buffer interpreted as straight (non-premultiplied) RGBA over white.
Uint8List flattenStraightRgbaToJpeg(
  Uint8List rgba, {
  required int width,
  required int height,
  int quality = 92,
}) {
  if (rgba.length < width * height * 4) {
    throw ArgumentError('RGBA buffer is smaller than width × height × 4');
  }
  final out = img.Image(width: width, height: height, numChannels: 3);
  var i = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final a = rgba[i + 3] / 255.0;
      out.setPixelRgb(
        x,
        y,
        _blend(rgba[i], a),
        _blend(rgba[i + 1], a),
        _blend(rgba[i + 2], a),
      );
      i += 4;
    }
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}

/// Turns a PDFKit / PdfRenderer RGBA buffer into a JPEG on white paper.
///
/// Tries the premultiplied blend first (what iOS writes). If that still
/// comes out black — some Android builds hand over straight alpha — retries
/// with a straight-alpha blend.
Uint8List rasterPdfPageToJpeg(
  Uint8List rgba, {
  required int width,
  required int height,
  int quality = 92,
}) {
  final premul = flattenPremultipliedRgbaToJpeg(
    rgba,
    width: width,
    height: height,
    quality: quality,
  );
  if (!isMostlyBlack(premul)) return premul;

  final straight = flattenStraightRgbaToJpeg(
    rgba,
    width: width,
    height: height,
    quality: quality,
  );
  if (!isMostlyBlack(straight)) return straight;

  return premul;
}

/// True when almost every pixel is near black — the failure mode of a
/// transparent PDF page that was flattened as RGB-only.
bool isMostlyBlack(
  Uint8List jpeg, {
  double threshold = 0.97,
  int lumaCutoff = 18,
}) {
  final decoded = img.decodeImage(jpeg);
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    return false;
  }
  final step = math.max(1, (decoded.width * decoded.height / 4000).ceil());
  var dark = 0;
  var total = 0;
  var i = 0;
  for (final pixel in decoded) {
    if (i % step == 0) {
      total++;
      final luma =
          (pixel.r.toInt() * 77 +
              pixel.g.toInt() * 150 +
              pixel.b.toInt() * 29) >>
          8;
      if (luma <= lumaCutoff) dark++;
    }
    i++;
  }
  if (total == 0) return false;
  return dark / total >= threshold;
}
