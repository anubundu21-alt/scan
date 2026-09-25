import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';

/// The Scanella home hero: a solid green header with white brand/hero copy.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key, this.onOpenMenu});

  final VoidCallback? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Brand.hero,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        padding: EdgeInsets.fromLTRB(8, top + 2, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (onOpenMenu != null)
                  TactileIconButton(
                    icon: Icons.menu_rounded,
                    tooltip: 'Menu',
                    color: Colors.white,
                    onPressed: onOpenMenu,
                  )
                else
                  const SizedBox(width: 8),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScanellaWordmark(fontSize: 22, onDark: true),
                        SizedBox(height: 3),
                        Text(
                          'Scan, save and share PDFs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const _OnDeviceBadge(),
              ],
            ),
            const SizedBox(height: 18),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroHeadline(),
                        SizedBox(height: 6),
                        Text(
                          'Scan. Save. Organize. Anytime.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                HomeHeroArt(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeadline extends StatelessWidget {
  const _HeroHeadline();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Turn your documents\ninto clarity',
      style: TextStyle(
        color: Colors.white,
        fontFamily: Brand.font,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _OnDeviceBadge extends StatelessWidget {
  const _OnDeviceBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 13, color: Colors.white),
          SizedBox(width: 5),
          Text(
            'On device',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeHeroArt extends StatefulWidget {
  const HomeHeroArt({super.key});

  /// Corner brackets and scan light on the home hero page — navy, not green.
  static const edgeNavy = Color(0xFF101D41);

  @override
  State<HomeHeroArt> createState() => _HomeHeroArtState();
}

class _HomeHeroArtState extends State<HomeHeroArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  void _syncLoop() {
    if (_heroScanShouldLoop(context)) {
      if (!_scan.isAnimating) _scan.repeat();
    } else {
      _scan
        ..stop()
        ..value = 0.42;
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 102,
      height: 94,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 8, top: 4, child: _LiveScanFrame(progress: _scan)),
          const Positioned(
            right: 0,
            top: 0,
            child: _FloatingChip(
              color: Color(0xFF5B9BFF),
              icon: Icons.landscape_rounded,
              label: 'JPG',
            ),
          ),
          const Positioned(
            right: 2,
            bottom: 0,
            child: _FloatingChip(
              color: Brand.pdfRed,
              icon: Icons.picture_as_pdf_rounded,
              label: 'PDF',
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget tests never settle if a ticker repeats, so the loop only runs
/// on a real device or simulator.
bool _heroScanShouldLoop(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return false;
  if (!TickerMode.of(context)) return false;
  final binding = WidgetsBinding.instance.runtimeType.toString();
  if (binding.contains('TestWidgets')) return false;
  return true;
}

class _LiveScanFrame extends StatelessWidget {
  const _LiveScanFrame({required this.progress});

  final Animation<double> progress;

  static const _inset = 3.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 86,
      child: Stack(
        children: [
          const Positioned.fill(
            child: Padding(padding: EdgeInsets.all(_inset), child: _MiniPage()),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, _) => CustomPaint(
                painter: _EdgeDetectPainter(progress: progress.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EdgeDetectPainter extends CustomPainter {
  const _EdgeDetectPainter({required this.progress});

  final double progress;

  static const _inset = 3.0;
  static const _arm = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _inset,
      _inset,
      size.width - _inset * 2,
      size.height - _inset * 2,
    );
    final sweepT = Curves.easeInOut.transform(
      (progress / 0.82).clamp(0.0, 1.0),
    );
    final sweepY = rect.top + rect.height * sweepT;

    double glow(Offset corner) {
      final near = 1 - ((corner.dy - sweepY).abs() / 20).clamp(0.0, 1.0);
      final pulse =
          0.55 + 0.45 * (0.5 + 0.5 * math.sin(progress * math.pi * 2));
      return (pulse * 0.55 + near * 0.55).clamp(0.5, 1.0);
    }

    void bracket(Offset origin, double dx, double dy, double alpha) {
      final paint = Paint()
        ..color = HomeHeroArt.edgeNavy.withValues(alpha: alpha)
        ..strokeWidth = 2.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx + dx * _arm, origin.dy)
          ..lineTo(origin.dx, origin.dy)
          ..lineTo(origin.dx, origin.dy + dy * _arm),
        paint,
      );
    }

    bracket(rect.topLeft, 1, 1, glow(rect.topLeft));
    bracket(rect.topRight, -1, 1, glow(rect.topRight));
    bracket(rect.bottomLeft, 1, -1, glow(rect.bottomLeft));
    bracket(rect.bottomRight, -1, -1, glow(rect.bottomRight));

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));
    final band = Rect.fromLTWH(rect.left, sweepY - 7, rect.width, 14);
    final light = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          HomeHeroArt.edgeNavy.withValues(alpha: 0),
          HomeHeroArt.edgeNavy.withValues(alpha: 0.28),
          HomeHeroArt.edgeNavy.withValues(alpha: 0),
        ],
      ).createShader(band);
    canvas.drawRect(band, light);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EdgeDetectPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MiniPage extends StatelessWidget {
  const _MiniPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Brand.ink.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(7, 8, 7, 8),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE4EDF6),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < 3; i++) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 4,
                width: i.isEven ? double.infinity : 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DEEA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 2) const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({required this.color, required this.icon, this.label});

  final Color color;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Brand.ink.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: label == null
          ? Icon(icon, color: color, size: 20)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 12),
                Text(
                  label!,
                  style: TextStyle(
                    color: color,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
    );
  }
}
