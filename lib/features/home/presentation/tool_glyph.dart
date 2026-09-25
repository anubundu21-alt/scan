import 'package:flutter/material.dart';

/// Bright, flat icon for one All tools tile: a solid-colour mark on a soft
/// rounded square of the same hue.
class ToolGlyph extends StatelessWidget {
  const ToolGlyph({
    super.key,
    required this.toolId,
    required this.color,
    this.size = 62,
  });

  final String toolId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isLight
            ? Color.lerp(Colors.white, color, 0.16)
            : color.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: SizedBox.square(dimension: size * 0.68, child: _mark()),
    );
  }

  Widget _mark() {
    switch (toolId) {
      case 'img-pdf':
        return _ImageMark(color: color);
      case 'word-pdf':
        return _DocMark(letter: 'W', color: color);
      case 'pdf-word':
        return _WithArrow(
          color: color,
          child: _DocMark(letter: 'W', color: color),
        );
      case 'compress':
        return _Icon(Icons.close_fullscreen_rounded, color);
      case 'merge':
        return _MergeMark(color: color);
      case 'jpg':
        return _WithArrow(
          color: color,
          child: _ImageMark(color: color),
        );
      case 'split':
        return _SplitMark(color: color);
      case 'pages':
        return _PagesMark(color: color);
      case 'watermark':
        return _Icon(Icons.approval_rounded, color);
      case 'rotate':
        return _Icon(Icons.rotate_right_rounded, color);
      case 'unlock':
        return _Icon(Icons.lock_open_rounded, color);
      case 'sign':
        return _Icon(Icons.draw_rounded, color);
      case 'extract':
        return _DocMark(letter: 'T', color: color);
      default:
        return _Icon(Icons.picture_as_pdf_rounded, color);
    }
  }
}

class _Icon extends StatelessWidget {
  const _Icon(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Icon(icon, color: color, size: c.maxWidth),
  );
}

/// A solid document with a folded corner and one bold letter.
class _DocMark extends StatelessWidget {
  const _DocMark({required this.letter, required this.color});

  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final h = c.maxHeight;
      final w = h * 0.8;
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(h * 0.1),
                      topRight: Radius.circular(h * 0.3),
                      bottomLeft: Radius.circular(h * 0.1),
                      bottomRight: Radius.circular(h * 0.1),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: h * 0.46,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A picture: sun and hills, in the tool colour with an amber sun.
class _ImageMark extends StatelessWidget {
  const _ImageMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final s = c.maxWidth;
      return Stack(
        children: [
          Positioned(
            left: s * 0.06,
            top: s * 0.1,
            child: Container(
              width: s * 0.26,
              height: s * 0.26,
              decoration: const BoxDecoration(
                color: Color(0xFFFFC107),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: s * 0.08,
            height: s * 0.62,
            child: CustomPaint(painter: _HillsPainter(color)),
          ),
        ],
      );
    },
  );
}

class _HillsPainter extends CustomPainter {
  const _HillsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final back = Path()
      ..moveTo(w * 0.38, h)
      ..lineTo(w * 0.7, h * 0.05)
      ..lineTo(w, h)
      ..close();
    final front = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.32, h * 0.3)
      ..lineTo(w * 0.66, h)
      ..close();
    canvas.drawPath(back, Paint()..color = color.withValues(alpha: 0.75));
    canvas.drawPath(front, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HillsPainter old) => old.color != color;
}

/// Adds a small "convert" arrow in the top-left corner of [child].
class _WithArrow extends StatelessWidget {
  const _WithArrow({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final s = c.maxWidth;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: s * 0.18,
            top: s * 0.14,
            right: 0,
            bottom: 0,
            child: child,
          ),
          Positioned(
            left: -s * 0.08,
            top: -s * 0.08,
            child: Icon(Icons.south_east_rounded, size: s * 0.42, color: color),
          ),
        ],
      );
    },
  );
}

/// Two overlapping rounded squares.
class _MergeMark extends StatelessWidget {
  const _MergeMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final s = c.maxWidth;
      final box = s * 0.64;
      BoxDecoration deco(Color c) => BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(box * 0.22),
      );
      return Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: box,
              height: box,
              decoration: deco(Color.lerp(color, Colors.white, 0.25)!),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(width: box, height: box, decoration: deco(color)),
          ),
        ],
      );
    },
  );
}

/// A bar with arrows pulling away from it on both sides.
class _SplitMark extends StatelessWidget {
  const _SplitMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final s = c.maxWidth;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_back_rounded, color: color, size: s * 0.42),
          Container(
            width: s * 0.12,
            height: s * 0.9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(s),
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: color, size: s * 0.42),
        ],
      );
    },
  );
}

/// A 2x2 grid of numbered tiles.
class _PagesMark extends StatelessWidget {
  const _PagesMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final s = c.maxWidth;
      final cell = s * 0.46;
      Widget tile(String n) => Container(
        width: cell,
        height: cell,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(cell * 0.24),
        ),
        child: Text(
          n,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: cell * 0.58,
            height: 1,
          ),
        ),
      );
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [tile('1'), tile('2')],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [tile('3'), tile('4')],
          ),
        ],
      );
    },
  );
}
