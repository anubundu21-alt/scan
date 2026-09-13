import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/features/library/domain/page_editor.dart';
import 'package:scan2/features/library/domain/page_stamp.dart';

/// Paints signatures the same way Flutter shows the page: decode with the
/// engine, draw on a canvas, then JPEG-encode.
///
/// `package:image` cannot read HEIC or some iPhone JPEGs. Baking with it
/// then clearing stamp metadata is how a signature vanished from the saved
/// PDF while still looking placed in the app.
class StampCompositor {
  const StampCompositor();

  Future<Uint8List> paint(Uint8List pageBytes, List<PageStamp> stamps) async {
    if (stamps.isEmpty) return pageBytes;
    final painted = await _paintWithEngine(pageBytes, stamps);
    if (painted != null) return painted;
    return const PageEditor().compositeStamps(pageBytes, stamps);
  }

  Future<Uint8List?> _paintWithEngine(
    Uint8List pageBytes,
    List<PageStamp> stamps,
  ) async {
    final page = await decodeUiImage(pageBytes);
    if (page == null) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(page, Offset.zero, Paint());

    for (final stamp in stamps) {
      await _drawStamp(canvas, page, stamp);
    }

    final picture = recorder.endRecording();
    final out = await picture.toImage(page.width, page.height);
    picture.dispose();
    page.dispose();
    final jpeg = await uiImageToJpeg(out);
    out.dispose();
    return jpeg;
  }

  Future<void> _drawStamp(
    Canvas canvas,
    ui.Image page,
    PageStamp stamp,
  ) async {
    final file = File(stamp.imagePath);
    if (!file.existsSync()) return;
    Uint8List overlayBytes;
    try {
      overlayBytes = file.readAsBytesSync();
    } catch (_) {
      return;
    }

    final raster = img.decodeImage(overlayBytes);
    if (raster != null) {
      overlayBytes = Uint8List.fromList(
        img.encodePng(prepareStampOverlay(raster)),
      );
    }

    final overlay = await decodeUiImage(overlayBytes);
    if (overlay == null) return;

    final destW = (stamp.nw * page.width).clamp(1, page.width.toDouble()).toDouble();
    final destH = (stamp.nh * page.height).clamp(1, page.height.toDouble()).toDouble();
    final hasCaption =
        stamp.caption != null && stamp.caption!.trim().isNotEmpty;
    final sigH = hasCaption ? destH * 0.72 : destH;
    final destX = stamp.nx * page.width;
    final destY = stamp.ny * page.height;
    final scale = destW / overlay.width < sigH / overlay.height
        ? destW / overlay.width
        : sigH / overlay.height;
    final drawW = (overlay.width * scale).clamp(1, destW).toDouble();
    final drawH = (overlay.height * scale).clamp(1, sigH).toDouble();

    canvas.drawImageRect(
      overlay,
      Rect.fromLTWH(0, 0, overlay.width.toDouble(), overlay.height.toDouble()),
      Rect.fromLTWH(destX, destY, drawW, drawH),
      Paint()..filterQuality = FilterQuality.medium,
    );
    overlay.dispose();

    if (!hasCaption) return;
    final painter = TextPainter(
      text: TextSpan(
        text: stamp.caption!.trim(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF161616),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: destW);
    painter.paint(canvas, Offset(destX, destY + sigH + 2));
  }
}

Future<ui.Image?> decodeUiImage(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> uiImageToJpeg(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return null;
  final raster = img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: byteData.buffer,
    bytesOffset: byteData.offsetInBytes,
    rowStride: image.width * 4,
    order: img.ChannelOrder.rgba,
    numChannels: 4,
  );
  return Uint8List.fromList(
    img.encodeJpg(raster.convert(numChannels: 3), quality: 92),
  );
}

/// True when [baked] actually darkened the stamp region versus [original].
bool stampInkLanded({
  required Uint8List original,
  required Uint8List baked,
  required PageStamp stamp,
}) {
  if (identical(original, baked)) return false;
  final before = img.decodeImage(original);
  final after = img.decodeImage(baked);
  if (before == null || after == null) return false;

  final x0 = (stamp.nx * after.width).round().clamp(0, after.width - 1);
  final y0 = (stamp.ny * after.height).round().clamp(0, after.height - 1);
  final x1 = ((stamp.nx + stamp.nw) * after.width).round().clamp(
    x0 + 1,
    after.width,
  );
  final y1 = ((stamp.ny + stamp.nh) * after.height).round().clamp(
    y0 + 1,
    after.height,
  );
  final stepX = ((x1 - x0) / 8).floor().clamp(1, 32);
  final stepY = ((y1 - y0) / 8).floor().clamp(1, 32);

  var darker = 0;
  for (var y = y0; y < y1; y += stepY) {
    for (var x = x0; x < x1; x += stepX) {
      final bx = (x / after.width * before.width).floor().clamp(
        0,
        before.width - 1,
      );
      final by = (y / after.height * before.height).floor().clamp(
        0,
        before.height - 1,
      );
      final a = after.getPixel(x, y);
      final b = before.getPixel(bx, by);
      final lumaAfter = 0.299 * a.r + 0.587 * a.g + 0.114 * a.b;
      final lumaBefore = 0.299 * b.r + 0.587 * b.g + 0.114 * b.b;
      if (lumaAfter < lumaBefore - 18) darker++;
    }
  }
  return darker >= 2;
}
