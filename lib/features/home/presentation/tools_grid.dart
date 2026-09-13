import 'package:flutter/material.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';

/// The ways into the app that are not the docked Scan button.
///
/// A two-column grid of pastel tiles: an illustration on top, the name
/// anchored at the bottom-left — the layout from the home mock.
class ToolsGrid extends StatelessWidget {
  /// Illustration band on each tile. Compact enough that the cards
  /// sit comfortably under the title on a phone.
  static const artHeight = 76.0;

  const ToolsGrid({
    super.key,
    required this.onFromPhotos,
    required this.onUploadPdf,
    required this.onExtractText,
    required this.onSignPdf,
    required this.onPdfToWord,
    required this.onWordToPdf,
    required this.onCompressPdf,
    required this.onMergePdf,
    required this.onSplitPdf,
    required this.onIdCard,
  });

  final VoidCallback onFromPhotos;
  final VoidCallback onUploadPdf;
  final VoidCallback onExtractText;
  final VoidCallback onSignPdf;
  final VoidCallback onPdfToWord;
  final VoidCallback onWordToPdf;
  final VoidCallback onCompressPdf;
  final VoidCallback onMergePdf;
  final VoidCallback onSplitPdf;
  final VoidCallback onIdCard;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    const columns = 2;
    final items = [
      _ToolSpec(
        label: 'From photos',
        tint: Brand.imageGreen,
        wash: const Color(0xFFE7F6EE),
        art: const _PhotosArt(),
        onPressed: onFromPhotos,
      ),
      _ToolSpec(
        label: 'Upload PDF',
        tint: Brand.pdfRed,
        wash: const Color(0xFFFBECEA),
        art: const _FilesArt(),
        onPressed: onUploadPdf,
      ),
      _ToolSpec(
        label: 'Extract text',
        tint: Brand.docBlue,
        wash: const Color(0xFFE7F1FB),
        art: const _TextArt(),
        onPressed: onExtractText,
      ),
      _ToolSpec(
        label: 'Sign PDF',
        tint: Brand.accent,
        wash: const Color(0xFFE4F5F0),
        art: const _SignArt(),
        onPressed: onSignPdf,
      ),
      _ToolSpec(
        label: 'PDF to Word',
        tint: Brand.docBlue,
        wash: const Color(0xFFE7F1FB),
        art: const _WordArt(),
        onPressed: onPdfToWord,
      ),
      _ToolSpec(
        label: 'Word to PDF',
        tint: Brand.pdfRed,
        wash: const Color(0xFFFBECEA),
        art: const _PdfArt(),
        onPressed: onWordToPdf,
      ),
      _ToolSpec(
        label: 'Compress PDF',
        tint: Brand.accent,
        wash: const Color(0xFFE4F5F0),
        art: const _CompressArt(),
        onPressed: onCompressPdf,
      ),
      _ToolSpec(
        label: 'Merge PDF',
        tint: Brand.docBlue,
        wash: const Color(0xFFE7F1FB),
        art: const _MergeArt(),
        onPressed: onMergePdf,
      ),
      _ToolSpec(
        label: 'Split PDF',
        tint: Brand.pdfRed,
        wash: const Color(0xFFFBECEA),
        art: const _SplitArt(),
        onPressed: onSplitPdf,
      ),
      _ToolSpec(
        label: 'ID card',
        tint: Brand.cloudBlue,
        wash: const Color(0xFFEEE8F8),
        art: const _IdArt(),
        onPressed: onIdCard,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: _ToolCard(
                    label: item.label,
                    tint: item.tint,
                    wash: item.wash,
                    art: item.art,
                    onPressed: item.onPressed,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolSpec {
  const _ToolSpec({
    required this.label,
    required this.tint,
    required this.wash,
    required this.art,
    required this.onPressed,
  });

  final String label;
  final Color tint;
  final Color wash;
  final Widget art;
  final VoidCallback onPressed;
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.label,
    required this.tint,
    required this.wash,
    required this.art,
    required this.onPressed,
  });

  final String label;
  final Color tint;
  final Color wash;
  final Widget art;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return PressableScale(
      onPressed: onPressed,
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(Brand.radiusCard),
      minSize: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 14, 13, 13),
        decoration: BoxDecoration(
          color: isLight ? wash : tint.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(Brand.radiusCard),
          boxShadow: isLight
              ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: ToolsGrid.artHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _ArtPainter(art: art, tint: tint, paper: isLight),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilesArt extends StatelessWidget {
  const _FilesArt();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _PhotosArt extends StatelessWidget {
  const _PhotosArt();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _TextArt extends StatelessWidget {
  const _TextArt();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SignArt extends StatelessWidget {
  const _SignArt();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _WordArt extends StatelessWidget {
  const _WordArt();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _PdfArt extends StatelessWidget {
  const _PdfArt();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _CompressArt extends StatelessWidget {
  const _CompressArt();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _MergeArt extends StatelessWidget {
  const _MergeArt();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SplitArt extends StatelessWidget {
  const _SplitArt();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _IdArt extends StatelessWidget {
  const _IdArt();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ArtPainter extends CustomPainter {
  _ArtPainter({required this.art, required this.tint, required this.paper});

  final Widget art;
  final Color tint;
  final bool paper;

  Color get _sheet => paper ? Colors.white : const Color(0xFFE9ECF4);
  Color get _sheetEdge => paper
      ? const Color(0xFF0B1B3F).withValues(alpha: 0.12)
      : const Color(0xFF0B1B3F).withValues(alpha: 0.35);
  Color get _rule => const Color(0xFF6B7385).withValues(alpha: 0.32);

  void _sheetRect(Canvas canvas, Rect rect, {double rotation = 0}) {
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(rotation);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF0B1B3F).withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(rrect, Paint()..color = _sheet);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _sheetEdge,
    );
    canvas.restore();
  }

  void _lines(Canvas canvas, Rect within, int count, {Color? color}) {
    final paint = Paint()..color = color ?? _rule;
    final gap = within.height / (count + 1);
    for (var i = 0; i < count; i++) {
      final y = within.top + gap * (i + 1);
      final w = within.width * (i.isEven ? 0.84 : 0.62);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(within.left, y, w, 2.4),
          const Radius.circular(1.2),
        ),
        paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final cx = size.width / 2;

    if (art is _PhotosArt) {
      final back = Rect.fromCenter(
        center: Offset(cx + 14, h * 0.54),
        width: 46,
        height: h * 0.70,
      );
      _sheetRect(canvas, back, rotation: 0.10);
      final photo = Rect.fromCenter(
        center: Offset(cx - 6, h * 0.50),
        width: 52,
        height: h * 0.68,
      );
      final frame = RRect.fromRectAndRadius(photo, const Radius.circular(8));
      canvas.drawRRect(
        frame,
        Paint()
          ..color = const Color(0xFF0B1B3F).withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawRRect(frame, Paint()..color = const Color(0xFFD8EFE3));
      canvas.drawRRect(
        frame.deflate(5),
        Paint()..color = const Color(0xFFB7E0C8),
      );
      canvas.drawCircle(
        Offset(photo.left + 18, photo.top + 18),
        5.5,
        Paint()..color = const Color(0xFFF5A524),
      );
      final hill = Path()
        ..moveTo(photo.left + 7, photo.bottom - 8)
        ..lineTo(photo.left + 22, photo.bottom - 28)
        ..lineTo(photo.left + 34, photo.bottom - 16)
        ..lineTo(photo.left + 42, photo.bottom - 24)
        ..lineTo(photo.right - 7, photo.bottom - 8)
        ..close();
      canvas.drawPath(hill, Paint()..color = tint);
      canvas.drawRRect(
        frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = tint.withValues(alpha: 0.45),
      );
    } else if (art is _FilesArt) {
      _sheetRect(
        canvas,
        Rect.fromCenter(
          center: Offset(cx - 10, h * 0.54),
          width: 42,
          height: h * 0.70,
        ),
        rotation: -0.08,
      );
      final front = Rect.fromCenter(
        center: Offset(cx + 8, h * 0.50),
        width: 46,
        height: h * 0.72,
      );
      _sheetRect(canvas, front);
      _lines(canvas, front.deflate(9).translate(0, -6), 4);
      final badge = RRect.fromRectAndRadius(
        Rect.fromLTWH(front.right - 30, front.bottom - 22, 28, 15),
        const Radius.circular(4),
      );
      canvas.drawRRect(badge, Paint()..color = tint);
      final label = TextPainter(
        text: const TextSpan(
          text: 'PDF',
          style: TextStyle(
            fontFamily: Brand.font,
            fontSize: 8.5,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(
          badge.outerRect.center.dx - label.width / 2,
          badge.outerRect.center.dy - label.height / 2,
        ),
      );
    } else if (art is _SignArt) {
      final sheet = Rect.fromCenter(
        center: Offset(cx, h * 0.48),
        width: 50,
        height: h * 0.78,
      );
      _sheetRect(canvas, sheet);
      _lines(canvas, sheet.deflate(9).translate(0, -10), 3);
      final squiggle = Path()
        ..moveTo(sheet.left + 10, sheet.bottom - 22)
        ..cubicTo(
          sheet.left + 20,
          sheet.bottom - 38,
          sheet.left + 28,
          sheet.bottom - 10,
          sheet.right - 10,
          sheet.bottom - 28,
        )
        ..cubicTo(
          sheet.right - 6,
          sheet.bottom - 34,
          sheet.right - 8,
          sheet.bottom - 14,
          sheet.right - 16,
          sheet.bottom - 18,
        );
      canvas.drawPath(
        squiggle,
        Paint()
          ..color = tint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    } else if (art is _WordArt || art is _PdfArt) {
      // Same pair of sheets both ways round; the badge says which direction
      // the conversion goes.
      _sheetRect(
        canvas,
        Rect.fromCenter(
          center: Offset(cx - 8, h * 0.54),
          width: 42,
          height: h * 0.70,
        ),
        rotation: -0.06,
      );
      final front = Rect.fromCenter(
        center: Offset(cx + 8, h * 0.50),
        width: 46,
        height: h * 0.72,
      );
      _sheetRect(canvas, front);
      _lines(canvas, front.deflate(9).translate(0, -6), 4, color: tint);
      final badge = RRect.fromRectAndRadius(
        Rect.fromLTWH(front.right - 32, front.bottom - 22, 30, 15),
        const Radius.circular(4),
      );
      canvas.drawRRect(badge, Paint()..color = tint);
      final label = TextPainter(
        text: TextSpan(
          text: art is _WordArt ? 'DOC' : 'PDF',
          style: const TextStyle(
            fontFamily: Brand.font,
            fontSize: 8,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(
          badge.outerRect.center.dx - label.width / 2,
          badge.outerRect.center.dy - label.height / 2,
        ),
      );
    } else if (art is _CompressArt) {
      _sheetRect(
        canvas,
        Rect.fromCenter(
          center: Offset(cx + 10, h * 0.54),
          width: 48,
          height: h * 0.74,
        ),
        rotation: 0.08,
      );
      final front = Rect.fromCenter(
        center: Offset(cx - 6, h * 0.50),
        width: 38,
        height: h * 0.56,
      );
      _sheetRect(canvas, front);
      _lines(canvas, front.deflate(7).translate(0, -4), 3, color: tint);
      final shaft = Paint()
        ..color = tint
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(cx + 18, h * 0.22),
        Offset(cx + 18, h * 0.46),
        shaft,
      );
      final head = Path()
        ..moveTo(cx + 11, h * 0.38)
        ..lineTo(cx + 18, h * 0.48)
        ..lineTo(cx + 25, h * 0.38);
      canvas.drawPath(head, shaft);
    } else if (art is _MergeArt) {
      _sheetRect(
        canvas,
        Rect.fromCenter(
          center: Offset(cx - 16, h * 0.54),
          width: 34,
          height: h * 0.62,
        ),
        rotation: -0.12,
      );
      _sheetRect(
        canvas,
        Rect.fromCenter(
          center: Offset(cx + 16, h * 0.54),
          width: 34,
          height: h * 0.62,
        ),
        rotation: 0.12,
      );
      final front = Rect.fromCenter(
        center: Offset(cx, h * 0.48),
        width: 42,
        height: h * 0.70,
      );
      _sheetRect(canvas, front);
      _lines(canvas, front.deflate(8).translate(0, -6), 4, color: tint);
    } else if (art is _SplitArt) {
      final left = Rect.fromCenter(
        center: Offset(cx - 16, h * 0.50),
        width: 32,
        height: h * 0.70,
      );
      final right = Rect.fromCenter(
        center: Offset(cx + 16, h * 0.50),
        width: 32,
        height: h * 0.70,
      );
      _sheetRect(canvas, left, rotation: -0.08);
      _sheetRect(canvas, right, rotation: 0.08);
      _lines(canvas, left.deflate(6).translate(0, -4), 3, color: tint);
      _lines(canvas, right.deflate(6).translate(0, -4), 3, color: tint);
      canvas.drawLine(
        Offset(cx, h * 0.18),
        Offset(cx, h * 0.82),
        Paint()
          ..color = tint
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    } else if (art is _IdArt) {
      final back = Rect.fromCenter(
        center: Offset(cx + 12, h * 0.46),
        width: 58,
        height: h * 0.52,
      );
      final front = Rect.fromCenter(
        center: Offset(cx - 4, h * 0.54),
        width: 60,
        height: h * 0.54,
      );
      _sheetRect(canvas, back, rotation: 0.10);
      _sheetRect(canvas, front);
      canvas.drawCircle(
        Offset(front.left + 16, front.center.dy - 2),
        8,
        Paint()..color = tint.withValues(alpha: 0.90),
      );
      canvas.drawCircle(
        Offset(front.left + 16, front.center.dy - 6),
        3.4,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      _lines(
        canvas,
        Rect.fromLTWH(front.left + 28, front.top + 12, 22, 28),
        3,
        color: tint,
      );
    } else {
      final sheet = Rect.fromCenter(
        center: Offset(cx - 8, h * 0.50),
        width: 46,
        height: h * 0.74,
      );
      _sheetRect(canvas, sheet);
      _lines(canvas, sheet.deflate(8), 5);
      final chip = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + 16, h * 0.52),
          width: 40,
          height: h * 0.48,
        ),
        const Radius.circular(7),
      );
      canvas.drawRRect(
        chip,
        Paint()
          ..color = const Color(0xFF0B1B3F).withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawRRect(chip, Paint()..color = tint.withValues(alpha: 0.22));
      canvas.drawRRect(
        chip,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = tint.withValues(alpha: 0.7),
      );
      _lines(canvas, chip.outerRect.deflate(6), 3, color: tint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) =>
      old.tint != tint ||
      old.paper != paper ||
      old.art.runtimeType != art.runtimeType;
}
