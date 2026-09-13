import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Finger / stylus drawing surface. Strokes are copied on every point so
/// [CustomPaint] actually repaints — mutating the live list in place is a
/// no-op to Flutter's shouldRepaint check, which is why drawing looked dead.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, this.onInkChanged});

  final ValueChanged<bool>? onInkChanged;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  var _strokes = <List<Offset>>[];
  var _generation = 0;

  bool get hasInk => _strokes.any((stroke) => stroke.length >= 2);

  void clear() {
    setState(() {
      _strokes = [];
      _generation++;
    });
    widget.onInkChanged?.call(false);
  }

  /// Ink only: a cropped PNG with a transparent background.
  ///
  /// Snapshotting the on-screen pad captured the white drawing sheet as well,
  /// so export pasted a white rectangle over the page. This paints the strokes
  /// onto a clear canvas and trims to the ink.
  Future<Uint8List?> capturePng({double pixelRatio = 3}) async {
    if (!hasInk) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return encodeSignaturePng(
      _strokes,
      logicalSize: box.size,
      pixelRatio: pixelRatio,
    );
  }

  void _start(Offset point) {
    setState(() {
      _strokes = [
        ..._strokes,
        [point],
      ];
      _generation++;
    });
  }

  void _extend(Offset point) {
    if (_strokes.isEmpty) {
      _start(point);
      return;
    }
    setState(() {
      final copy = [
        for (final stroke in _strokes) [...stroke],
      ];
      copy[copy.length - 1].add(point);
      _strokes = copy;
      _generation++;
    });
    widget.onInkChanged?.call(hasInk);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (!_accepts(event.kind)) return;
          _start(event.localPosition);
        },
        onPointerMove: (event) {
          if (!_accepts(event.kind)) return;
          _extend(event.localPosition);
        },
        child: CustomPaint(
          painter: _SignaturePainter(
            strokes: _strokes,
            generation: _generation,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  static bool _accepts(PointerDeviceKind kind) {
    return kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus ||
        kind == PointerDeviceKind.mouse;
  }
}

/// Renders [strokes] as a tight transparent PNG. Used by the pad and tests.
Future<Uint8List?> encodeSignaturePng(
  List<List<Offset>> strokes, {
  required Size logicalSize,
  double pixelRatio = 3,
  double padding = 16,
}) async {
  final bounds = signatureInkBounds(
    strokes,
    logicalSize: logicalSize,
    padding: padding,
  );
  if (bounds == null) return null;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  canvas.translate(-bounds.left, -bounds.top);
  paintSignatureStrokes(canvas, strokes);

  final picture = recorder.endRecording();
  final width = (bounds.width * pixelRatio).ceil().clamp(1, 2048);
  final height = (bounds.height * pixelRatio).ceil().clamp(1, 2048);
  final image = await picture.toImage(width, height);
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes?.buffer.asUint8List();
}

Rect? signatureInkBounds(
  List<List<Offset>> strokes, {
  required Size logicalSize,
  double padding = 16,
}) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = 0.0;
  var maxY = 0.0;
  var found = false;
  for (final stroke in strokes) {
    if (stroke.length < 2 && stroke.isEmpty) continue;
    for (final point in stroke) {
      found = true;
      minX = math.min(minX, point.dx);
      minY = math.min(minY, point.dy);
      maxX = math.max(maxX, point.dx);
      maxY = math.max(maxY, point.dy);
    }
  }
  if (!found) return null;
  return Rect.fromLTRB(
    (minX - padding).clamp(0, logicalSize.width),
    (minY - padding).clamp(0, logicalSize.height),
    (maxX + padding).clamp(0, logicalSize.width),
    (maxY + padding).clamp(0, logicalSize.height),
  );
}

void paintSignatureStrokes(Canvas canvas, List<List<Offset>> strokes) {
  final paint = Paint()
    ..color = const Color(0xFF111111)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  for (final stroke in strokes) {
    if (stroke.isEmpty) continue;
    if (stroke.length == 1) {
      canvas.drawCircle(
        stroke.first,
        2.2,
        Paint()
          ..color = paint.color
          ..style = PaintingStyle.fill,
      );
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, paint);
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes, required this.generation});

  final List<List<Offset>> strokes;
  final int generation;

  @override
  void paint(Canvas canvas, Size size) => paintSignatureStrokes(canvas, strokes);

  @override
  bool shouldRepaint(covariant _SignaturePainter old) =>
      old.generation != generation;
}
