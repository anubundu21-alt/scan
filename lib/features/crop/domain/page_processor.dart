import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/core/imaging/raster.dart';
import 'package:scan2/features/camera/domain/document_quad_detector.dart';
import 'package:scan2/features/camera/domain/quad_detector.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';
import 'package:scan2/features/crop/domain/perspective_transformer.dart';

/// The finished bytes for a page plus the settings that produced them.
@immutable
class ProcessedCapture {
  const ProcessedCapture({
    required this.bytes,
    required this.quad,
    required this.adjustments,
  });

  final Uint8List bytes;

  /// The crop that was applied, or null if the page was left uncropped.
  final Quad? quad;

  final ScanAdjustments adjustments;
}

/// Turns a raw capture into a finished page: detect edges, perspective-correct,
/// enhance, encode.
///
/// This runs once at capture time so a scan is already a proper scan by the
/// time it reaches the library, rather than a photo the user must remember to
/// go and crop. Everything happens in a single background pass over one decode.
class PageProcessor {
  const PageProcessor();

  /// [quad] forces a crop; leave it null to detect one.
  ///
  /// [fallbackQuad] is used only when detection on the still image finds
  /// nothing — normally the edges the live preview was tracking at the moment
  /// of capture. Without it, a still that fails to detect saves the whole
  /// frame uncropped, even though the user was looking at a locked-on outline
  /// a fraction of a second earlier.
  Future<ProcessedCapture> process({
    required String imagePath,
    Quad? quad,
    Quad? fallbackQuad,
    ScanAdjustments adjustments = const ScanAdjustments(),
    bool detectEdges = true,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    return compute(
      _processIsolate,
      _ProcessRequest(
        bytes: bytes,
        quad: quad == null ? null : _FlatQuad.from(quad),
        fallbackQuad: fallbackQuad == null
            ? null
            : _FlatQuad.from(fallbackQuad),
        adjustments: adjustments,
        detectEdges: detectEdges,
      ),
    );
  }

  /// Re-derives a page from its original using explicit settings, for saves
  /// out of the crop screen.
  Future<Uint8List> render({
    required Uint8List sourceBytes,
    Quad? quad,
    required ScanAdjustments adjustments,
  }) {
    return compute(
      _renderIsolate,
      _ProcessRequest(
        bytes: sourceBytes,
        quad: quad == null ? null : _FlatQuad.from(quad),
        fallbackQuad: null,
        adjustments: adjustments,
        detectEdges: false,
      ),
    );
  }
}

class _FlatQuad {
  const _FlatQuad(this.values);

  factory _FlatQuad.from(Quad q) => _FlatQuad([
    q.topLeft.dx,
    q.topLeft.dy,
    q.topRight.dx,
    q.topRight.dy,
    q.bottomRight.dx,
    q.bottomRight.dy,
    q.bottomLeft.dx,
    q.bottomLeft.dy,
  ]);

  final List<double> values;

  Quad toQuad() => Quad(
    topLeft: Offset(values[0], values[1]),
    topRight: Offset(values[2], values[3]),
    bottomRight: Offset(values[4], values[5]),
    bottomLeft: Offset(values[6], values[7]),
  );
}

class _ProcessRequest {
  const _ProcessRequest({
    required this.bytes,
    required this.quad,
    required this.fallbackQuad,
    required this.adjustments,
    required this.detectEdges,
  });

  final Uint8List bytes;
  final _FlatQuad? quad;
  final _FlatQuad? fallbackQuad;
  final ScanAdjustments adjustments;
  final bool detectEdges;
}

ProcessedCapture _processIsolate(_ProcessRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) {
    return ProcessedCapture(
      bytes: request.bytes,
      quad: null,
      adjustments: request.adjustments,
    );
  }

  final source = Raster.fromImage(img.bakeOrientation(decoded));

  var quad = request.quad?.toQuad();
  if (quad == null && request.detectEdges) {
    quad = detectQuadInRaster(source) ?? request.fallbackQuad?.toQuad();
  }

  return ProcessedCapture(
    bytes: _renderRaster(source, quad, request.adjustments),
    quad: quad,
    adjustments: request.adjustments,
  );
}

Uint8List _renderIsolate(_ProcessRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return request.bytes;
  final source = Raster.fromImage(img.bakeOrientation(decoded));
  return _renderRaster(source, request.quad?.toQuad(), request.adjustments);
}

Uint8List _renderRaster(
  Raster source,
  Quad? quad,
  ScanAdjustments adjustments,
) {
  // Quad corners are stored in rotated-image space, so rotate the capture
  // first, then warp.
  var raster = source.rotatedTurns(adjustments.rotationTurns);
  if (quad != null && !PerspectiveTransformer.isFullFrame(quad)) {
    raster = warpRaster(raster, quad) ?? raster;
    raster = trimDarkRim(raster);
  }
  final out = applyAdjustments(raster, adjustments);
  return Uint8List.fromList(img.encodeJpg(out.toImage(), quality: 92));
}

/// How far inside the detected border to crop, as a fraction of page size.
const _borderInset = 0.015;

/// Runs edge detection over a full-resolution raster by analysing a
/// downscaled luminance copy, matching the live preview's analysis size so a
/// still capture agrees with the guides the user just saw.
Quad? detectQuadInRaster(Raster source) {
  // Matches the live preview's analysis scale, so a still capture agrees
  // with the guides the user was just looking at.
  const analysisEdge = 320;
  final small = source.downscaledTo(analysisEdge);

  final detection = const DocumentQuadDetector().detect(
    small.toLuma(),
    small.width,
    small.height,
  );
  if (detection == null) return null;

  // Crop just inside the detected border so the page does not come out with
  // a dark rim of desk along its edges.
  return Quad.fromCorners(detection.corners).shrink(_borderInset);
}

/// Picks the crop to open on after a scan.
///
/// When the system scanner already cropped the page, [edgesAlreadyApplied] is
/// true and we keep that frame. Re-running detection on a finished scan
/// latches onto printed text or a photo on the sheet and saves only that
/// inner block — the page the user just captured is gone.
Quad resolveScanQuad(
  Raster source, {
  required bool edgesAlreadyApplied,
  Quad? initial,
}) {
  if (edgesAlreadyApplied) {
    return initial ?? const Quad.fullFrame();
  }
  return detectQuadInRaster(source) ?? initial ?? const Quad.centered();
}

/// Share of a row or column that must be dark for it to count as desk. Low,
/// because a slanted wedge covers only part of the row it sits in.
const _rimShare = 0.06;

/// Cuts away a strip of desk left along any edge of a straightened page.
///
/// Edge detection runs on a small copy, so a corner can land a little outside
/// the paper and bring a dark wedge into the PDF. Rows or columns at the edge
/// that are mostly much darker than the page are dropped, at most
/// [maxFraction] of the page per side, so a page that is genuinely dark at
/// the edge loses no more than a thin border.
Raster trimDarkRim(Raster src, {double maxFraction = 0.05}) {
  final w = src.width;
  final h = src.height;
  if (w < 40 || h < 40) return src;
  final luma = src.toLuma();

  // Page brightness: the median of a sample from the middle of the page.
  final samples = <int>[];
  for (var y = h ~/ 4; y < h * 3 ~/ 4; y += 4) {
    for (var x = w ~/ 4; x < w * 3 ~/ 4; x += 4) {
      samples.add(luma[y * w + x]);
    }
  }
  samples.sort();
  final paper = samples[samples.length ~/ 2];
  // A dark page has no bright paper to compare the rim against.
  if (paper < 120) return src;
  final dark = (paper * 0.6).round();

  bool rowIsRim(int y) {
    var d = 0;
    for (var x = 0; x < w; x += 2) {
      if (luma[y * w + x] < dark) d++;
    }
    return d > (w ~/ 2) * _rimShare;
  }

  bool colIsRim(int x) {
    var d = 0;
    for (var y = 0; y < h; y += 2) {
      if (luma[y * w + x] < dark) d++;
    }
    return d > (h ~/ 2) * _rimShare;
  }

  final maxRows = (h * maxFraction).floor();
  final maxCols = (w * maxFraction).floor();
  var top = 0;
  while (top < maxRows && rowIsRim(top)) {
    top++;
  }
  var bottom = 0;
  while (bottom < maxRows && rowIsRim(h - 1 - bottom)) {
    bottom++;
  }
  var left = 0;
  while (left < maxCols && colIsRim(left)) {
    left++;
  }
  var right = 0;
  while (right < maxCols && colIsRim(w - 1 - right)) {
    right++;
  }
  // A dark strip that runs all the way to the limit is not a sliver: it is a
  // dark page, dark artwork, or a crop the user drew wide on purpose.
  if (top >= maxRows) top = 0;
  if (bottom >= maxRows) bottom = 0;
  if (left >= maxCols) left = 0;
  if (right >= maxCols) right = 0;
  // A wedge thins toward one corner; a few more pixels clear its soft edge.
  final pad = math.max(2, (math.min(w, h) * 0.004).round());
  if (top > 0) top = math.min(top + pad, maxRows);
  if (bottom > 0) bottom = math.min(bottom + pad, maxRows);
  if (left > 0) left = math.min(left + pad, maxCols);
  if (right > 0) right = math.min(right + pad, maxCols);
  if (top + bottom + left + right == 0) return src;

  final outW = w - left - right;
  final outH = h - top - bottom;
  if (outW < 8 || outH < 8) return src;
  final out = Raster(outW, outH);
  for (var y = 0; y < outH; y++) {
    final from = ((y + top) * w + left) * 3;
    out.pixels.setRange(y * outW * 3, (y + 1) * outW * 3, src.pixels, from);
  }
  return out;
}
