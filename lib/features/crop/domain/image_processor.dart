import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/core/imaging/raster.dart';

/// Scan enhancement presets, in the order they appear in the crop screen.
enum ScanFilter { original, magic, grayscale, bw, enhance }

/// Tone + filter settings for one page.
@immutable
class ScanAdjustments {
  const ScanAdjustments({
    this.filter = ScanFilter.magic,
    this.brightness = 0,
    this.contrast = 0,
    this.rotationTurns = 0,
  });

  final ScanFilter filter;

  /// -1..1, neutral at 0.
  final double brightness;

  /// -1..1, neutral at 0.
  final double contrast;

  /// 90° clockwise turns applied to the original capture before crop (0–3).
  final int rotationTurns;

  bool get isNeutralTone => brightness.abs() < 0.001 && contrast.abs() < 0.001;

  bool get isNoOp => filter == ScanFilter.original && isNeutralTone;

  ScanAdjustments copyWith({
    ScanFilter? filter,
    double? brightness,
    double? contrast,
    int? rotationTurns,
  }) {
    return ScanAdjustments(
      filter: filter ?? this.filter,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      rotationTurns: rotationTurns ?? this.rotationTurns,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScanAdjustments &&
      other.filter == filter &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.rotationTurns == rotationTurns;

  @override
  int get hashCode => Object.hash(filter, brightness, contrast, rotationTurns);
}

class ImageProcessor {
  /// Applies [adjustments] to encoded [imageBytes] and returns encoded JPEG.
  ///
  /// This decodes and re-encodes, so it costs seconds on a full-resolution
  /// camera frame. The crop screen uses it only when saving; interactive
  /// preview goes through [ScanPreview] instead.
  Future<Uint8List> applyFilter({
    required List<int> imageBytes,
    required ScanFilter filter,
    double brightness = 0,
    double contrast = 0,
  }) async {
    final bytes = imageBytes is Uint8List
        ? imageBytes
        : Uint8List.fromList(imageBytes);
    final adjustments = ScanAdjustments(
      filter: filter,
      brightness: brightness,
      contrast: contrast,
    );
    if (adjustments.isNoOp) return bytes;

    return compute(
      _applyFilterIsolate,
      _FilterRequest(bytes: bytes, adjustments: adjustments),
    );
  }

  static String labelFor(ScanFilter filter) {
    switch (filter) {
      case ScanFilter.original:
        return 'Original';
      case ScanFilter.magic:
        return 'Auto';
      case ScanFilter.grayscale:
        return 'Grayscale';
      case ScanFilter.bw:
        return 'B&W';
      case ScanFilter.enhance:
        return 'Sharpness';
    }
  }
}

class _FilterRequest {
  const _FilterRequest({required this.bytes, required this.adjustments});

  final Uint8List bytes;
  final ScanAdjustments adjustments;
}

Uint8List _applyFilterIsolate(_FilterRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return request.bytes;

  final raster = Raster.fromImage(img.bakeOrientation(decoded));
  final out = applyAdjustments(raster, request.adjustments);
  return Uint8List.fromList(img.encodeJpg(out.toImage(), quality: 92));
}

// ---------------------------------------------------------------------------
// Filter kernels — pure raster math so the preview and the saved page run the
// exact same code, only at different resolutions.
// ---------------------------------------------------------------------------

/// Applies tone then the selected filter, returning a new raster.
Raster applyAdjustments(Raster src, ScanAdjustments adjustments) {
  var out = adjustments.isNeutralTone
      ? src.clone()
      : _applyTone(src, adjustments.brightness, adjustments.contrast);

  switch (adjustments.filter) {
    case ScanFilter.original:
      break;
    case ScanFilter.grayscale:
      out = _grayscale(out);
    case ScanFilter.bw:
      out = _adaptiveBlackAndWhite(out);
    case ScanFilter.magic:
      out = _autoEnhance(out);
    case ScanFilter.enhance:
      out = _sharpen(out, amount: 1.1);
  }
  return out;
}

/// Brightness/contrast as a single 256-entry lookup table.
Raster _applyTone(Raster src, double brightness, double contrast) {
  final lut = Uint8List(256);
  // Contrast pivots around mid-grey; brightness is an additive offset.
  final c = 1.0 + contrast * 0.85;
  final b = brightness * 90.0;
  for (var i = 0; i < 256; i++) {
    lut[i] = (((i - 128) * c) + 128 + b).round().clamp(0, 255);
  }

  final out = Raster(src.width, src.height);
  for (var i = 0; i < src.pixels.length; i++) {
    out.pixels[i] = lut[src.pixels[i]];
  }
  return out;
}

Raster _grayscale(Raster src) {
  final luma = src.toLuma();
  final out = Raster(src.width, src.height);
  var i = 0;
  for (var p = 0; p < luma.length; p++) {
    final v = luma[p];
    out.pixels[i++] = v;
    out.pixels[i++] = v;
    out.pixels[i++] = v;
  }
  return out;
}

/// Radius proportional to the image so results look the same at preview and
/// full resolution — a fixed pixel radius would sharpen a thumbnail far more
/// aggressively than the page it previews.
int _relativeRadius(Raster src, double fraction, {int min = 1, int max = 400}) {
  final base = math.min(src.width, src.height) * fraction;
  return base.round().clamp(min, max);
}

/// Unsharp mask driven by the luma channel, so colour stays intact.
Raster _sharpen(Raster src, {required double amount}) {
  final luma = src.toLuma();
  final radius = _relativeRadius(src, 0.004, min: 1, max: 24);
  final blurred = blurLuma(luma, src.width, src.height, radius);

  // Fixed-point amount: the inner loop runs once per pixel on images up to
  // 12MP, where a double multiply and .round() per channel is measurable.
  final amountQ8 = (amount * 256).round();

  final out = Raster(src.width, src.height);
  final dst = out.pixels;
  final srcPixels = src.pixels;
  var i = 0;
  for (var p = 0; p < luma.length; p++) {
    final delta = ((luma[p] - blurred[p]) * amountQ8) >> 8;
    var r = srcPixels[i] + delta;
    var g = srcPixels[i + 1] + delta;
    var b = srcPixels[i + 2] + delta;
    dst[i] = r < 0 ? 0 : (r > 255 ? 255 : r);
    dst[i + 1] = g < 0 ? 0 : (g > 255 ? 255 : g);
    dst[i + 2] = b < 0 ? 0 : (b > 255 ? 255 : b);
    i += 3;
  }
  return out;
}

/// Bradley-style adaptive threshold: compare each pixel against the local
/// mean rather than one global cutoff, so a page lit unevenly (a shadow from
/// the phone itself, most of the time) still binarises cleanly.
Raster _adaptiveBlackAndWhite(Raster src) {
  final luma = src.toLuma();
  final radius = _relativeRadius(src, 0.045, min: 4, max: 160);
  final localMean = localMeanLuma(luma, src.width, src.height, radius);

  final out = Raster(src.width, src.height);
  var i = 0;
  for (var p = 0; p < luma.length; p++) {
    // Ink is anything clearly below the local paper. 10% — rather than 12%
    // plus a further -2 — still holds paper white across a lighting
    // gradient, while keeping faint pencil and ruled lines that the older
    // cutoff bleached away entirely.
    final v = luma[p] < localMean[p] * 0.90 ? 0 : 255;
    out.pixels[i++] = v;
    out.pixels[i++] = v;
    out.pixels[i++] = v;
  }
  return out;
}

/// The "scanned page" look: neutralise the paper, flatten uneven lighting,
/// add gentle contrast on luma alone, then sharpen lightly.
///
/// Order matters, and getting it wrong is what made Auto stain a clean page.
/// The white balance runs *before* the lighting flatten: multiplying a cream
/// or warm-lit page by a single luma gain clips red at 255 and leaves blue
/// behind, which is precisely how a white notebook came back orange-brown.
/// The levels stretch is luma-only for the same reason — pushing R, G and B
/// independently reintroduces the tint the balance just removed.
Raster _autoEnhance(Raster src) {
  final balanced = _whiteBalancePaper(src);
  final flattened = _flattenLighting(
    balanced,
    targetPaper: 242,
    // 2.2x. Uncapped gain is the other half of the blotching: in a dark
    // corner the local background approaches zero, the gain runs away, and
    // sensor noise gets amplified into the grey-brown mottling.
    maxGainQ8: 563,
    radiusFraction: 0.08,
  );
  final contrasted = _stretchLuma(
    flattened,
    lowPct: 0.008,
    highPct: 0.995,
    // Not 0 and 255: crushing to pure black and blowing to pure white loses
    // the thin strokes at both ends of a pencil page.
    mapLow: 18,
    mapHigh: 246,
  );
  return _sharpen(contrasted, amount: 0.35);
}

/// Divides out a heavily blurred estimate of the page background, so a page
/// lit unevenly comes back flat.
Raster _flattenLighting(
  Raster src, {
  required int targetPaper,
  required int maxGainQ8,
  required double radiusFraction,
}) {
  final luma = src.toLuma();
  final radius = _relativeRadius(src, radiusFraction, min: 8, max: 220);
  final background = localMeanLuma(luma, src.width, src.height, radius);

  // The gain depends only on the background value, which is a byte — so all
  // 256 gains are precomputed once as fixed point rather than doing a
  // floating-point divide per pixel.
  final gainQ8 = Int32List(256);
  for (var v = 0; v < 256; v++) {
    final g = (targetPaper * 256) ~/ math.max(v, 8);
    gainQ8[v] = g.clamp(200, maxGainQ8);
  }

  final out = Raster(src.width, src.height);
  final dst = out.pixels;
  final srcPixels = src.pixels;
  var i = 0;
  for (var p = 0; p < luma.length; p++) {
    final gain = gainQ8[background[p]];
    final r = (srcPixels[i] * gain) >> 8;
    final g = (srcPixels[i + 1] * gain) >> 8;
    final b = (srcPixels[i + 2] * gain) >> 8;
    dst[i] = r > 255 ? 255 : r;
    dst[i + 1] = g > 255 ? 255 : g;
    dst[i + 2] = b > 255 ? 255 : b;
    i += 3;
  }
  return out;
}

/// Scales each channel so the brightest paper reads as near-neutral white.
///
/// The paper estimate is the mean of the top 30% of pixels by luma, which on
/// a document is the page itself rather than the ink.
Raster _whiteBalancePaper(Raster src, {double strength = 1}) {
  final luma = src.toLuma();
  final histogram = Int32List(256);
  for (final v in luma) {
    histogram[v]++;
  }
  final cutoff = _histogramPercentile(histogram, luma.length, 0.70);

  var sumR = 0;
  var sumG = 0;
  var sumB = 0;
  var n = 0;
  var i = 0;
  for (var p = 0; p < luma.length; p++) {
    if (luma[p] >= cutoff) {
      sumR += src.pixels[i];
      sumG += src.pixels[i + 1];
      sumB += src.pixels[i + 2];
      n++;
    }
    i += 3;
  }
  // Too small a sample to trust — leave the page alone rather than guess.
  if (n < 16) return src;

  final meanR = sumR / n;
  final meanG = sumG / n;
  final meanB = sumB / n;
  final paper = math.max(meanR, math.max(meanG, meanB));
  if (paper < 8) return src;

  // Bring each channel up to the strongest one, which neutralises the cast.
  // Clamped, so a genuinely coloured page (a pink form, a yellow legal pad)
  // is corrected toward neutral without being bleached white.
  var sR = 1 + ((paper / math.max(meanR, 1)) - 1) * strength;
  var sG = 1 + ((paper / math.max(meanG, 1)) - 1) * strength;
  var sB = 1 + ((paper / math.max(meanB, 1)) - 1) * strength;
  sR = sR.clamp(0.72, 1.55);
  sG = sG.clamp(0.72, 1.55);
  sB = sB.clamp(0.72, 1.55);

  final lift = (244 / paper).clamp(1.0, 1.12);
  sR *= lift;
  sG *= lift;
  sB *= lift;

  final out = Raster(src.width, src.height);
  i = 0;
  for (var p = 0; p < luma.length; p++) {
    out.pixels[i] = (src.pixels[i] * sR).round().clamp(0, 255);
    out.pixels[i + 1] = (src.pixels[i + 1] * sG).round().clamp(0, 255);
    out.pixels[i + 2] = (src.pixels[i + 2] * sB).round().clamp(0, 255);
    i += 3;
  }
  return out;
}

/// Percentile levels stretch computed on luma, then applied to R/G/B as one
/// shared delta so chroma — and any leftover paper tint — is not stretched
/// independently.
Raster _stretchLuma(
  Raster src, {
  required double lowPct,
  required double highPct,
  required int mapLow,
  required int mapHigh,
}) {
  final luma = src.toLuma();
  final histogram = Int32List(256);
  for (final v in luma) {
    histogram[v]++;
  }
  final low = _histogramPercentile(histogram, luma.length, lowPct);
  final high = _histogramPercentile(histogram, luma.length, highPct);
  // Already flat: stretching this hard would be amplifying noise.
  if (high - low < 24) return src;

  final lut = Uint8List(256);
  final span = (high - low).toDouble();
  final mapped = (mapHigh - mapLow).toDouble();
  for (var v = 0; v < 256; v++) {
    lut[v] = (mapLow + ((v - low) / span) * mapped).round().clamp(0, 255);
  }

  final out = Raster(src.width, src.height);
  var i = 0;
  for (var p = 0; p < luma.length; p++) {
    final delta = lut[luma[p]] - luma[p];
    final r = src.pixels[i] + delta;
    final g = src.pixels[i + 1] + delta;
    final b = src.pixels[i + 2] + delta;
    out.pixels[i] = r < 0 ? 0 : (r > 255 ? 255 : r);
    out.pixels[i + 1] = g < 0 ? 0 : (g > 255 ? 255 : g);
    out.pixels[i + 2] = b < 0 ? 0 : (b > 255 ? 255 : b);
    i += 3;
  }
  return out;
}

int _histogramPercentile(Int32List histogram, int total, double pct) {
  final target = (total * pct).round().clamp(1, total);
  var running = 0;
  for (var v = 0; v < 256; v++) {
    running += histogram[v];
    if (running >= target) return v;
  }
  return 255;
}
