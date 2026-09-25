import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:scan2/features/library/domain/page_stamp.dart';

/// Page-level PDF edits that never go through the camera or crop pipeline.
///
/// Rotate and signature compositing both work on the finished page JPEG the
/// library already stores.
class PageEditor {
  const PageEditor();

  /// 90° clockwise. Returns null when [bytes] is not a readable image so the
  /// caller can still update metadata without inventing pixels.
  Uint8List? rotateClockwise(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final rotated = img.copyRotate(decoded, angle: 90);
      return Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
    } catch (_) {
      return null;
    }
  }

  /// Paints [stamps] onto [pageBytes] and returns a JPEG. Missing stamp files
  /// are skipped so a deleted signature cannot block export.
  Uint8List compositeStamps(Uint8List pageBytes, List<PageStamp> stamps) {
    if (stamps.isEmpty) return pageBytes;
    img.Image decoded;
    try {
      final parsed = img.decodeImage(pageBytes);
      if (parsed == null) return pageBytes;
      decoded = parsed;
    } catch (_) {
      return pageBytes;
    }

    final canvas = decoded.convert(numChannels: 4);
    for (final stamp in stamps) {
      final file = File(stamp.imagePath);
      if (!file.existsSync()) continue;
      img.Image? overlay;
      try {
        overlay = img.decodeImage(file.readAsBytesSync());
      } catch (_) {
        overlay = null;
      }
      if (overlay == null) continue;

      final destW = (stamp.nw * canvas.width).round().clamp(1, canvas.width);
      final hasCaption =
          stamp.caption != null && stamp.caption!.trim().isNotEmpty;
      final destH = (stamp.nh * canvas.height).round().clamp(1, canvas.height);
      final sigH = hasCaption ? (destH * 0.72).round().clamp(1, destH) : destH;
      final destX = (stamp.nx * canvas.width).round();
      final destY = (stamp.ny * canvas.height).round();

      final ink = prepareStampOverlay(overlay);
      final scale = destW / ink.width < sigH / ink.height
          ? destW / ink.width
          : sigH / ink.height;
      final drawW = (ink.width * scale).round().clamp(1, destW);
      final drawH = (ink.height * scale).round().clamp(1, sigH);
      final resized = img.copyResize(
        ink,
        width: drawW,
        height: drawH,
        interpolation: img.Interpolation.linear,
      );
      img.compositeImage(
        canvas,
        resized,
        dstX: destX,
        dstY: destY,
        blend: img.BlendMode.alpha,
      );

      if (hasCaption) {
        img.drawString(
          canvas,
          stamp.caption!.trim(),
          font: img.arial14,
          x: destX,
          y: destY + sigH + 2,
          color: img.ColorRgb8(22, 22, 22),
        );
      }
    }

    return Uint8List.fromList(
      img.encodeJpg(canvas.convert(numChannels: 3), quality: 92),
    );
  }
}

/// Drawn signatures already have a clear background. Punching luma→alpha
/// again thins anti-aliased strokes until JPEG export looks unsigned.
img.Image prepareStampOverlay(img.Image overlay) {
  if (overlayHasTransparency(overlay)) return overlay;
  return asSignatureInk(overlay);
}

bool overlayHasTransparency(img.Image overlay) {
  if (overlay.numChannels < 4) return false;
  final stepX = (overlay.width / 24).floor().clamp(1, 8);
  final stepY = (overlay.height / 24).floor().clamp(1, 8);
  for (var y = 0; y < overlay.height; y += stepY) {
    for (var x = 0; x < overlay.width; x += stepX) {
      if (overlay.getPixel(x, y).a.toInt() < 12) return true;
    }
  }
  return false;
}

/// Turns a signature image into dark ink on a transparent ground.
///
/// The drawing pad is white so you can see the stroke. Saving that sheet as
/// the stamp painted a white box over the document. Luma becomes alpha: paper
/// disappears, ink stays, and a PNG that already has a clear background is
/// unchanged (empty pixels have alpha 0).
img.Image asSignatureInk(img.Image src) {
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final pixel = src.getPixel(x, y);
      final luma = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      final srcA = src.numChannels >= 4 ? pixel.a.toInt() : 255;
      var alpha = ((255 - luma) * srcA / 255).round();
      if (alpha < 12) alpha = 0;
      out.setPixelRgba(x, y, 17, 17, 17, alpha);
    }
  }
  return out;
}
