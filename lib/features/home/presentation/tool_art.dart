import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:scan2/core/theme/brand.dart';

/// File-type graphics for All tools: a document shape, not a letter on a square.
class ToolFileGlyph extends StatelessWidget {
  const ToolFileGlyph({super.key, required this.kind, this.size = 58});

  final ToolFileKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.86,
      height: size,
      child: CustomPaint(painter: _FilePainter(kind: kind)),
    );
  }
}

enum ToolFileKind { pdf, word, excel, ppt, image }

class _FilePainter extends CustomPainter {
  const _FilePainter({required this.kind});

  final ToolFileKind kind;

  Color get _ink => switch (kind) {
    ToolFileKind.pdf => Brand.pdfRed,
    ToolFileKind.word => Brand.docBlue,
    ToolFileKind.excel => Brand.imageGreen,
    ToolFileKind.ppt => const Color(0xFFE67E22),
    ToolFileKind.image => const Color(0xFF3A8DFF),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fold = w * 0.30;
    final r = Radius.circular(w * 0.12);
    final body = Path()
      ..moveTo(r.x, 0)
      ..lineTo(w - fold, 0)
      ..lineTo(w, fold)
      ..lineTo(w, h - r.y)
      ..arcToPoint(Offset(w - r.x, h), radius: r)
      ..lineTo(r.x, h)
      ..arcToPoint(Offset(0, h - r.y), radius: r)
      ..lineTo(0, r.y)
      ..arcToPoint(Offset(r.x, 0), radius: r)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = _ink.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final header = Path()
      ..moveTo(r.x, 0)
      ..lineTo(w - fold, 0)
      ..lineTo(w - fold, h * 0.22)
      ..lineTo(0, h * 0.22)
      ..lineTo(0, r.y)
      ..arcToPoint(Offset(r.x, 0), radius: r)
      ..close();
    canvas.drawPath(header, Paint()..color = _ink);

    final foldPath = Path()
      ..moveTo(w - fold, 0)
      ..lineTo(w - fold, fold)
      ..lineTo(w, fold)
      ..close();
    canvas.drawPath(
      foldPath,
      Paint()..color = Color.lerp(_ink, Colors.white, 0.35) ?? _ink,
    );

    switch (kind) {
      case ToolFileKind.word:
        _lines(canvas, w, h);
      case ToolFileKind.excel:
        _grid(canvas, w, h);
      case ToolFileKind.ppt:
        _slide(canvas, w, h);
      case ToolFileKind.pdf:
        _pdfMark(canvas, w, h);
      case ToolFileKind.image:
        _photo(canvas, w, h);
    }
  }

  void _lines(Canvas canvas, double w, double h) {
    final paint = Paint()..color = _ink.withValues(alpha: 0.55);
    for (var i = 0; i < 4; i++) {
      final y = h * 0.36 + i * h * 0.12;
      final width = i == 3 ? w * 0.38 : w * 0.62;
      canvas.drawRRect(
        RRect.fromLTRBR(
          w * 0.14,
          y,
          w * 0.14 + width,
          y + 3.4,
          const Radius.circular(1.6),
        ),
        paint,
      );
    }
  }

  void _grid(Canvas canvas, double w, double h) {
    final left = w * 0.14;
    final top = h * 0.34;
    final right = w * 0.86;
    final bottom = h * 0.86;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromLTRBR(left, top, right, bottom, const Radius.circular(3)),
      stroke,
    );
    canvas.drawLine(Offset((left + right) / 2, top), Offset((left + right) / 2, bottom), stroke);
    final row = (bottom - top) / 3;
    canvas.drawLine(Offset(left, top + row), Offset(right, top + row), stroke);
    canvas.drawLine(Offset(left, top + row * 2), Offset(right, top + row * 2), stroke);
    canvas.drawRect(
      Rect.fromLTRB(left, top, (left + right) / 2, top + row),
      Paint()..color = _ink.withValues(alpha: 0.18),
    );
  }

  void _slide(Canvas canvas, double w, double h) {
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.14, h * 0.36, w * 0.86, h * 0.78, const Radius.circular(5)),
      Paint()..color = _ink.withValues(alpha: 0.16),
    );
    canvas.drawCircle(Offset(w * 0.36, h * 0.54), w * 0.09, Paint()..color = _ink);
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.50, h * 0.48, w * 0.78, h * 0.54, const Radius.circular(1.4)),
      Paint()..color = _ink.withValues(alpha: 0.7),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.50, h * 0.60, w * 0.72, h * 0.66, const Radius.circular(1.4)),
      Paint()..color = _ink.withValues(alpha: 0.4),
    );
  }

  void _pdfMark(Canvas canvas, double w, double h) {
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.16, h * 0.42, w * 0.84, h * 0.78, const Radius.circular(6)),
      Paint()..color = _ink,
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 9,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.54));
  }

  void _photo(Canvas canvas, double w, double h) {
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.14, h * 0.34, w * 0.86, h * 0.86, const Radius.circular(5)),
      Paint()..color = const Color(0xFFE8F1FF),
    );
    canvas.drawCircle(Offset(w * 0.32, h * 0.48), 3.4, Paint()..color = _ink);
    final mountain = Path()
      ..moveTo(w * 0.14, h * 0.86)
      ..lineTo(w * 0.38, h * 0.54)
      ..lineTo(w * 0.54, h * 0.68)
      ..lineTo(w * 0.70, h * 0.50)
      ..lineTo(w * 0.86, h * 0.86)
      ..close();
    canvas.drawPath(mountain, Paint()..color = _ink.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant _FilePainter oldDelegate) => oldDelegate.kind != kind;
}

/// Large action graphic on a pastel plate.
class ToolActionArt extends StatelessWidget {
  const ToolActionArt({super.key, required this.toolId});

  final String toolId;

  @override
  Widget build(BuildContext context) {
    return switch (toolId) {
      'merge' => const _Plate(
        wash: Color(0xFFFFD9D4),
        child: _MergeGraphic(color: Color(0xFFE8443A)),
      ),
      'split' => const _Plate(
        wash: Color(0xFFE6DCFF),
        child: _SplitGraphic(color: Color(0xFF7C5CFF)),
      ),
      'compress' => const _Plate(
        wash: Color(0xFFD3F3E0),
        child: _CompressGraphic(color: Color(0xFF1F9A6B)),
      ),
      'jpg' => const _Plate(
        wash: Color(0xFFD6E8FF),
        child: _PhotosGraphic(color: Color(0xFF3A8DFF)),
      ),
      'extract' => const _Plate(
        wash: Color(0xFFD6E8FF),
        child: Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF2F6FE4), size: 36),
      ),
      'sign' => const _Plate(
        wash: Color(0xFFD4F3EE),
        child: Icon(Icons.draw_rounded, color: Color(0xFF0D9488), size: 36),
      ),
      'id-card' => const _Plate(
        wash: Color(0xFFD6E8FF),
        child: Icon(Icons.badge_outlined, color: Color(0xFF3A8DFF), size: 36),
      ),
      _ => const _Plate(
        wash: Color(0xFFE8EBF1),
        child: Icon(Icons.apps_rounded, color: Brand.grey, size: 36),
      ),
    };
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.wash, required this.child});

  final Color wash;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(wash, Colors.white, 0.45) ?? wash, wash],
        ),
      ),
      child: Center(child: child),
    );
  }
}

class _MergeGraphic extends StatelessWidget {
  const _MergeGraphic({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 48,
      child: Stack(
        children: [
          Positioned(left: 14, top: 10, child: _PageSheet(color: color.withValues(alpha: 0.72))),
          Positioned(left: 7, top: 5, child: _PageSheet(color: color.withValues(alpha: 0.88))),
          Positioned(left: 0, top: 0, child: _PageSheet(color: color)),
        ],
      ),
    );
  }
}

class _PageSheet extends StatelessWidget {
  const _PageSheet({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.8),
      ),
      padding: const EdgeInsets.fromLTRB(5, 7, 5, 7),
      child: Column(
        children: [
          Container(height: 3, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          Container(height: 3, color: color.withValues(alpha: 0.35)),
          const SizedBox(height: 4),
          Container(height: 3, width: 12, color: color.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}

class _SplitGraphic extends StatelessWidget {
  const _SplitGraphic({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(56, 48),
            painter: _DashedCutPainter(color: color),
          ),
          Icon(Icons.content_cut_rounded, color: color, size: 30),
        ],
      ),
    );
  }
}

class _DashedCutPainter extends CustomPainter {
  const _DashedCutPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    var y = 2.0;
    final x = size.width / 2;
    while (y < size.height - 2) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + 4, size.height - 2)),
        paint,
      );
      y += 7;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCutPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CompressGraphic extends StatelessWidget {
  const _CompressGraphic({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(44, 44),
      painter: _CompressPainter(color: color),
    );
  }
}

class _CompressPainter extends CustomPainter {
  const _CompressPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final midY = size.height / 2;
    canvas.drawLine(Offset(6, midY), Offset(size.width - 6, midY), stroke);
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2, 4)
        ..lineTo(size.width / 2 - 9, 18)
        ..lineTo(size.width / 2 + 9, 18)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2, size.height - 4)
        ..lineTo(size.width / 2 - 9, size.height - 18)
        ..lineTo(size.width / 2 + 9, size.height - 18)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _CompressPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PhotosGraphic extends StatelessWidget {
  const _PhotosGraphic({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 44,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 0,
            child: _PhotoTile(color: color.withValues(alpha: 0.55)),
          ),
          Positioned(left: 0, top: 8, child: _PhotoTile(color: color)),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color, width: 1.8),
      ),
      child: Icon(Icons.landscape_rounded, color: color, size: 16),
    );
  }
}

/// The All tools icon set.
///
/// Every tool is drawn on the same 52 × 48 stage out of the same parts: a
/// sheet of paper with a folded corner, a format ribbon or letter on it, and a
/// corner chip naming the format a converter produces. One drawing language
/// across eighteen cards, so the grid reads as a designed set rather than a
/// tray of borrowed Material glyphs.
class AllToolsMark extends StatelessWidget {
  const AllToolsMark({
    super.key,
    required this.toolId,
    required this.ink,
    this.size = 54,
  });

  final String toolId;
  final Color ink;

  /// Width of the mark. Height follows the stage ratio.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * _stageHeight / _stageWidth,
      child: CustomPaint(painter: _ToolMarkPainter(toolId: toolId, ink: ink)),
    );
  }
}

const _stageWidth = 52.0;
const _stageHeight = 48.0;

/// Paper that carries a corner chip: pushed up and left so the chip has room.
const _chipPage = Rect.fromLTWH(9, 2, 28, 36);

/// Paper for a tool with no chip: centred on the stage.
const _soloPage = Rect.fromLTWH(11, 4, 30, 40);

class _ToolMarkPainter extends CustomPainter {
  const _ToolMarkPainter({required this.toolId, required this.ink});

  final String toolId;
  final Color ink;

  /// Acrobat red. A PDF is red in every tool grid a user has seen, so it stays
  /// red here even on a card tinted for the other half of the conversion.
  static const _pdfInk = Color(0xFFE8443A);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / _stageWidth, size.height / _stageHeight);
    switch (toolId) {
      case 'pdf-word':
        _fromPdf(canvas, 'W');
      case 'pdf-excel':
        _fromPdf(canvas, 'X');
      case 'pdf-ppt':
        _fromPdf(canvas, 'P');
      case 'jpg':
        _fromPdf(canvas, 'JPG');
      case 'word-pdf':
        _toPdf(canvas, 'W');
      case 'excel-pdf':
        _toPdf(canvas, 'X');
      case 'ppt-pdf':
        _toPdf(canvas, 'P');
      case 'img-pdf':
        _imageToPdf(canvas);
      case 'compress':
        _compress(canvas);
      case 'merge':
        _merge(canvas);
      case 'split':
        _split(canvas);
      case 'pages':
        _pageNumbers(canvas);
      case 'watermark':
        _watermark(canvas);
      case 'rotate':
        _rotate(canvas);
      case 'unlock':
        _unlock(canvas);
      case 'sign':
        _sign(canvas);
      case 'extract':
        _extract(canvas);
      case 'id-card':
        _idCard(canvas);
      default:
        _appGrid(canvas);
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- parts

  Path _sheetPath(Rect r, {double radius = 5, double fold = 10}) {
    final rad = Radius.circular(radius);
    return Path()
      ..moveTo(r.left + radius, r.top)
      ..lineTo(r.right - fold, r.top)
      ..lineTo(r.right, r.top + fold)
      ..lineTo(r.right, r.bottom - radius)
      ..arcToPoint(Offset(r.right - radius, r.bottom), radius: rad)
      ..lineTo(r.left + radius, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - radius), radius: rad)
      ..lineTo(r.left, r.top + radius)
      ..arcToPoint(Offset(r.left + radius, r.top), radius: rad)
      ..close();
  }

  /// A sheet of paper: white page, tinted outline, folded top corner and a
  /// soft shadow so it lifts off the pastel card behind it.
  void _sheet(
    Canvas canvas,
    Rect r, {
    Color? edge,
    double radius = 5,
    double fold = 10,
    bool shadow = true,
  }) {
    final line = edge ?? ink;
    final path = _sheetPath(r, radius: radius, fold: fold);
    if (shadow) {
      canvas.drawPath(
        path.shift(const Offset(0, 2)),
        Paint()
          ..color = line.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );
    }
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = line.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawPath(
      Path()
        ..moveTo(r.right - fold, r.top)
        ..lineTo(r.right - fold, r.top + fold)
        ..lineTo(r.right, r.top + fold)
        ..close(),
      Paint()..color = line.withValues(alpha: 0.30),
    );
  }

  /// Rows of "text" on a page.
  void _lines(
    Canvas canvas,
    Rect page,
    Color color, {
    required double top,
    int count = 3,
    double gap = 5.5,
    double thickness = 2.4,
    double inset = 5,
  }) {
    final left = page.left + inset;
    final full = page.width - inset * 2;
    for (var i = 0; i < count; i++) {
      final width = i == count - 1 && count > 1 ? full * 0.58 : full;
      final y = top + i * gap;
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          y,
          left + width,
          y + thickness,
          Radius.circular(thickness / 2),
        ),
        Paint()..color = color.withValues(alpha: i == 0 ? 0.52 : 0.30),
      );
    }
  }

  /// The corner chip naming what comes out of a converter.
  void _chip(Canvas canvas, Offset center, Color color, String label) {
    final wide = label.length > 1;
    final width = wide ? (label.length > 2 ? 24.0 : 21.0) : 18.0;
    final height = wide ? 15.0 : 18.0;
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(2),
        Radius.circular(height / 2 + 2),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(height / 2)),
      Paint()..color = color,
    );
    _label(
      canvas,
      label,
      center,
      color: Colors.white,
      fontSize: wide ? (label.length > 2 ? 8.0 : 9.0) : 11.5,
    );
  }

  void _label(
    Canvas canvas,
    String value,
    Offset center, {
    required Color color,
    required double fontSize,
    FontWeight weight = FontWeight.w800,
    double letterSpacing = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: Brand.font,
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  /// The red "PDF" ribbon that marks a page as a PDF.
  void _pdfRibbon(Canvas canvas, Rect page, double top) {
    final rect = Rect.fromLTRB(page.left + 3, top, page.right - 3, top + 11);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2.5)),
      Paint()..color = _pdfInk,
    );
    _label(
      canvas,
      'PDF',
      rect.center,
      color: Colors.white,
      fontSize: 7.5,
      letterSpacing: 0.2,
    );
  }

  Paint get _strokeInk => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // ------------------------------------------------------------ converters

  /// PDF in, something else out: red ribbon on the page, target on the chip.
  void _fromPdf(Canvas canvas, String target) {
    _sheet(canvas, _chipPage, edge: _pdfInk);
    _lines(canvas, _chipPage, _pdfInk, top: 7, count: 2, thickness: 2.2);
    _pdfRibbon(canvas, _chipPage, 17);
    _chip(canvas, const Offset(37, 36), ink, target);
  }

  /// Something else in, PDF out: the source letter fills the page.
  void _toPdf(Canvas canvas, String source) {
    _sheet(canvas, _chipPage);
    _label(
      canvas,
      source,
      Offset(_chipPage.center.dx, _chipPage.top + 15),
      color: ink,
      fontSize: 19,
    );
    _lines(canvas, _chipPage, ink, top: 27, count: 2, gap: 5, thickness: 2.2);
    _chip(canvas, const Offset(37, 36), _pdfInk, 'PDF');
  }

  void _imageToPdf(Canvas canvas) {
    const frame = Rect.fromLTWH(8, 4, 30, 27);
    final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(6));
    canvas.drawRRect(
      rrect.shift(const Offset(0, 2)),
      Paint()
        ..color = ink.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    final inner = RRect.fromRectAndRadius(
      frame.deflate(2.5),
      const Radius.circular(4),
    );
    canvas.save();
    canvas.clipRRect(inner);
    canvas.drawRRect(inner, Paint()..color = ink.withValues(alpha: 0.12));
    canvas.drawCircle(
      Offset(frame.right - 8, frame.top + 9),
      3.2,
      Paint()..color = const Color(0xFFF5B518),
    );
    canvas.drawPath(
      Path()
        ..moveTo(frame.left, frame.bottom)
        ..lineTo(frame.left + 9, frame.top + 15)
        ..lineTo(frame.left + 17, frame.bottom)
        ..close(),
      Paint()..color = ink.withValues(alpha: 0.45),
    );
    canvas.drawPath(
      Path()
        ..moveTo(frame.left + 11, frame.bottom)
        ..lineTo(frame.left + 20, frame.top + 10)
        ..lineTo(frame.right, frame.bottom)
        ..close(),
      Paint()..color = ink,
    );
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _chip(canvas, const Offset(37, 36), _pdfInk, 'PDF');
  }

  // --------------------------------------------------------------- actions

  void _compress(Canvas canvas) {
    _sheet(canvas, _soloPage);
    _lines(canvas, _soloPage, ink, top: 9, count: 1, thickness: 2.2);
    _lines(canvas, _soloPage, ink, top: 37, count: 1, thickness: 2.2);
    final centre = _soloPage.center.dx;
    // Two arrows pressing on a seam. Kept well apart: closer together they
    // meet in the middle and the pair reads as an hourglass.
    canvas.drawPath(
      Path()
        ..moveTo(centre, 14)
        ..lineTo(centre, 20)
        ..moveTo(centre - 5.5, 15)
        ..lineTo(centre, 20.5)
        ..lineTo(centre + 5.5, 15),
      _strokeInk,
    );
    canvas.drawPath(
      Path()
        ..moveTo(centre, 34)
        ..lineTo(centre, 28)
        ..moveTo(centre - 5.5, 33)
        ..lineTo(centre, 27.5)
        ..lineTo(centre + 5.5, 33),
      _strokeInk,
    );
    final seam = Paint()
      ..color = ink.withValues(alpha: 0.45)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var x = _soloPage.left + 4; x < _soloPage.right - 4; x += 5) {
      canvas.drawLine(Offset(x, 24), Offset(x + 2.6, 24), seam);
    }
  }

  void _merge(Canvas canvas) {
    const back = Rect.fromLTWH(5, 3, 23, 28);
    const front = Rect.fromLTWH(15, 12, 23, 28);
    _sheet(canvas, back, edge: ink, fold: 8, shadow: false);
    _lines(canvas, back, ink, top: 14, count: 2, gap: 5, thickness: 2.2, inset: 4);
    _sheet(canvas, front, fold: 8);
    _lines(canvas, front, ink, top: 23, count: 2, gap: 5, thickness: 2.2, inset: 4);
    const centre = Offset(40, 35);
    canvas.drawCircle(centre, 11, Paint()..color = Colors.white);
    canvas.drawCircle(centre, 9, Paint()..color = ink);
    final glyph = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      centre.translate(-4.5, 0),
      centre.translate(4.5, 0),
      glyph,
    );
    canvas.drawLine(
      centre.translate(0, -4.5),
      centre.translate(0, 4.5),
      glyph,
    );
  }

  void _split(Canvas canvas) {
    const left = Rect.fromLTWH(8, 7, 15, 34);
    const right = Rect.fromLTWH(29, 7, 15, 34);
    canvas.save();
    canvas.translate(left.center.dx, left.center.dy);
    canvas.rotate(-0.09);
    canvas.translate(-left.center.dx, -left.center.dy);
    _sheet(canvas, left, radius: 4, fold: 0);
    _lines(canvas, left, ink, top: 14, count: 3, gap: 5, thickness: 2, inset: 3.5);
    canvas.restore();
    canvas.save();
    canvas.translate(right.center.dx, right.center.dy);
    canvas.rotate(0.09);
    canvas.translate(-right.center.dx, -right.center.dy);
    _sheet(canvas, right, radius: 4, fold: 7);
    _lines(canvas, right, ink, top: 14, count: 3, gap: 5, thickness: 2, inset: 3.5);
    canvas.restore();
    final dash = Paint()
      ..color = ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var y = 6.0; y < 42; y += 6) {
      canvas.drawLine(Offset(26, y), Offset(26, y + 3), dash);
    }
  }

  void _pageNumbers(Canvas canvas) {
    _sheet(canvas, _soloPage);
    _lines(canvas, _soloPage, ink, top: 10, count: 4, gap: 5.5, thickness: 2.2);
    final chip = Rect.fromCenter(
      center: Offset(_soloPage.center.dx, _soloPage.bottom - 6),
      width: 17,
      height: 11,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chip, const Radius.circular(5.5)),
      Paint()..color = ink,
    );
    _label(
      canvas,
      '12',
      chip.center,
      color: Colors.white,
      fontSize: 7.5,
      letterSpacing: 0.2,
    );
  }

  void _watermark(Canvas canvas) {
    _sheet(canvas, _soloPage);
    _lines(canvas, _soloPage, ink, top: 11, count: 4, gap: 5.5, thickness: 2.2);
    // A mark laid over the page, water-drop shaped: at this size a stamped
    // ring of text turns to mush, a droplet still reads.
    const centre = Offset(31, 30);
    canvas.drawCircle(centre, 12.5, Paint()..color = Colors.white);
    final drop = Path()
      ..moveTo(centre.dx, centre.dy - 10)
      ..cubicTo(
        centre.dx + 7.5,
        centre.dy - 2.5,
        centre.dx + 8,
        centre.dy + 3,
        centre.dx + 5.2,
        centre.dy + 6.2,
      )
      ..cubicTo(
        centre.dx + 2.2,
        centre.dy + 9.6,
        centre.dx - 2.2,
        centre.dy + 9.6,
        centre.dx - 5.2,
        centre.dy + 6.2,
      )
      ..cubicTo(
        centre.dx - 8,
        centre.dy + 3,
        centre.dx - 7.5,
        centre.dy - 2.5,
        centre.dx,
        centre.dy - 10,
      )
      ..close();
    canvas.drawPath(drop, Paint()..color = ink.withValues(alpha: 0.22));
    canvas.drawPath(
      drop,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      centre.translate(-2.4, 2.6),
      2.2,
      Paint()..color = ink.withValues(alpha: 0.55),
    );
  }

  void _rotate(Canvas canvas) {
    const page = Rect.fromLTWH(14, 13, 24, 29);
    canvas.save();
    canvas.translate(page.center.dx, page.center.dy);
    canvas.rotate(0.2);
    canvas.translate(-page.center.dx, -page.center.dy);
    _sheet(canvas, page, fold: 8);
    _lines(canvas, page, ink, top: 21, count: 3, gap: 5, thickness: 2.2, inset: 4);
    canvas.restore();
    final centre = page.center;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: 19),
      math.pi * 1.12,
      math.pi * 0.74,
      false,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    final tip = Offset(
      centre.dx + 19 * math.cos(math.pi * 1.86),
      centre.dy + 19 * math.sin(math.pi * 1.86),
    );
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(math.pi * 1.86);
    canvas.drawPath(
      Path()
        ..moveTo(0, 4.5)
        ..lineTo(-4.2, -2.6)
        ..lineTo(4.2, -2.6)
        ..close(),
      Paint()..color = ink,
    );
    canvas.restore();
  }

  void _unlock(Canvas canvas) {
    _sheet(canvas, _soloPage);
    _lines(canvas, _soloPage, ink, top: 10, count: 3, gap: 5.5, thickness: 2.2);
    canvas.drawCircle(const Offset(32, 32), 14, Paint()..color = Colors.white);
    // The shackle sits off to the right of the body, hinged on its far leg:
    // a shackle centred over the body is just a locked padlock.
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(40, 24), radius: 5),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(45, 24),
      const Offset(45, 27.5),
      Paint()
        ..color = ink
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    const body = Rect.fromLTWH(22, 27, 20, 15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      Paint()..color = ink,
    );
    canvas.drawCircle(
      body.center.translate(0, -1),
      2.2,
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        body.center.dx - 1,
        body.center.dy + 0.4,
        body.center.dx + 1,
        body.center.dy + 4,
        const Radius.circular(1),
      ),
      Paint()..color = Colors.white,
    );
  }

  void _sign(Canvas canvas) {
    _sheet(canvas, _soloPage);
    _lines(canvas, _soloPage, ink, top: 10, count: 2, gap: 5.5, thickness: 2.2);
    canvas.drawPath(
      Path()
        ..moveTo(16, 33)
        ..cubicTo(19, 22, 23, 37, 26, 29)
        ..cubicTo(28.5, 22.5, 31, 33, 36, 25),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      Offset(_soloPage.left + 4, 37),
      Offset(_soloPage.right - 4, 37),
      Paint()
        ..color = ink.withValues(alpha: 0.28)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.save();
    canvas.translate(39, 22);
    canvas.rotate(0.62);
    canvas.drawRRect(
      RRect.fromLTRBR(-2.4, -11, 2.4, 1, const Radius.circular(1.2)),
      Paint()..color = ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-2.4, 1)
        ..lineTo(2.4, 1)
        ..lineTo(0, 6)
        ..close(),
      Paint()..color = ink,
    );
    canvas.restore();
  }

  void _extract(Canvas canvas) {
    _sheet(canvas, _chipPage);
    _lines(canvas, _chipPage, ink, top: 9, count: 4, gap: 5.5, thickness: 2.4);
    canvas.drawRRect(
      RRect.fromLTRBR(
        _chipPage.left + 5,
        9,
        _chipPage.left + 5 + (_chipPage.width - 10) * 0.62,
        11.4,
        const Radius.circular(1.2),
      ),
      Paint()..color = ink,
    );
    _chip(canvas, const Offset(37, 36), ink, 'Aa');
  }

  void _idCard(Canvas canvas) {
    const card = Rect.fromLTWH(5, 9, 42, 30);
    final rrect = RRect.fromRectAndRadius(card, const Radius.circular(6));
    canvas.drawRRect(
      rrect.shift(const Offset(0, 2)),
      Paint()
        ..color = ink.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Rect.fromLTWH(card.left, card.top, card.width, 7),
      Paint()..color = ink,
    );
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    const portrait = Rect.fromLTWH(10, 20, 14, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(portrait, const Radius.circular(4)),
      Paint()..color = ink.withValues(alpha: 0.14),
    );
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(portrait, const Radius.circular(4)),
    );
    canvas.drawCircle(
      Offset(portrait.center.dx, portrait.top + 5),
      3,
      Paint()..color = ink,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        portrait.center.dx - 5.4,
        portrait.top + 9,
        portrait.center.dx + 5.4,
        portrait.bottom + 3,
        const Radius.circular(5),
      ),
      Paint()..color = ink,
    );
    canvas.restore();
    for (var i = 0; i < 3; i++) {
      final y = 21.0 + i * 5.5;
      final width = i == 2 ? 9.0 : 15.0;
      canvas.drawRRect(
        RRect.fromLTRBR(28, y, 28 + width, y + 2.4, const Radius.circular(1.2)),
        Paint()..color = ink.withValues(alpha: i == 0 ? 0.5 : 0.28),
      );
    }
  }

  void _appGrid(Canvas canvas) {
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 2; col++) {
        final rect = Rect.fromLTWH(14 + col * 13.0, 12 + row * 13.0, 10, 10);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()
            ..color = ink.withValues(alpha: row == col ? 1.0 : 0.45),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ToolMarkPainter oldDelegate) =>
      oldDelegate.toolId != toolId || oldDelegate.ink != ink;
}
