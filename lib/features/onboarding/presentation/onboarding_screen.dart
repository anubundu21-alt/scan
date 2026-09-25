import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/illustrations.dart';
import 'package:scan2/features/home/presentation/tool_art.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/shared/providers/onboarding_provider.dart';

/// Screens 2–3 — the three-page introduction.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    // On to the Pro offer, which also sums up the free plan. Someone who already
    // has Pro has neither a free allowance to explain nor an offer to see,
    // so they go straight in. There is still no account and no login: the
    // only wall in front of this scanner is one you can close.
    if (ref.read(proProvider).isPro && !ref.read(proProvider).testingBuild) {
      ref.read(onboardingCompletedProvider.notifier).complete();
      context.go('/library');
      return;
    }
    context.go('/pro-intro');
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pinned light. These screens are drawn straight from the design pack —
    // ink navy on a pale canvas, hardcoded — so under a dark theme their text
    // would be light-on-light. Committing to the light theme keeps the intro
    // looking like the mockups it came from, and legible either way.
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: Brand.canvas,
        body: Stack(
          children: [
            // A green wash behind the top of the page, from the design pack.
            // It sits outside the SafeArea so the colour carries up under the
            // status bar instead of stopping at a hard line below it.
            const Positioned.fill(child: _TopWash()),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 20, 0),
                      child: TextButton(
                        onPressed: _finish,
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Brand.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      onPageChanged: (index) => setState(() => _page = index),
                      itemBuilder: (context, index) =>
                          _OnboardingPage(page: _pages[index]),
                    ),
                  ),
                  // Room between the page's last line and the dots.
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 10 : 9,
                          height: i == _page ? 10 : 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _page ? Brand.accent : Brand.outline,
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
                    child: BrandButton(
                      label: _page == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The green fade across the top of the intro pages.
///
/// Drawn under the content rather than behind a card, so the badge and the
/// headline sit in the colour and it is gone by the time the illustration
/// starts. Ignores pointers so the PageView still takes every swipe.
class _TopWash extends StatelessWidget {
  const _TopWash();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Brand.accent.withValues(alpha: 0.95),
              Brand.accent.withValues(alpha: 0.87),
              Brand.accent.withValues(alpha: 0.71),
              Brand.accent.withValues(alpha: 0.45),
              Brand.accent.withValues(alpha: 0.21),
              Brand.accent.withValues(alpha: 0.03),
              Brand.accent.withValues(alpha: 0),
            ],
            stops: const [0, 0.05, 0.09, 0.13, 0.18, 0.22, 0.26],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page});

  final _PageData page;

  @override
  Widget build(BuildContext context) {
    final compact = page.compact;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            width: compact ? 52 : 76,
            height: compact ? 52 : 76,
            decoration: BoxDecoration(
              color: Brand.surface,
              borderRadius: BorderRadius.circular(compact ? 16 : 20),
              boxShadow: [
                BoxShadow(
                  color: Brand.ink.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              page.badge,
              size: compact ? 26 : 36,
              color: Brand.accent,
            ),
          ),
          SizedBox(height: compact ? 10 : 22),
          _SplitHeadline(
            lead: page.headlineLead,
            accent: page.headlineAccent,
            fontSize: compact ? 28 : 33,
          ),
          SizedBox(height: compact ? 8 : 14),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 15 : 16,
              color: Brand.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: page.illustration),
        ],
      ),
    );
  }
}

/// Headline where the last word or two carries the brand accent.
class _SplitHeadline extends StatelessWidget {
  const _SplitHeadline({
    required this.lead,
    required this.accent,
    this.fontSize = 33,
  });

  final String lead;
  final String accent;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: Brand.font,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.22,
      letterSpacing: -0.6,
    );
    return Text.rich(
      TextSpan(
        style: style.copyWith(color: Brand.ink),
        children: [
          TextSpan(text: lead),
          TextSpan(
            text: accent,
            style: style.copyWith(color: Brand.accent),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _PageData {
  const _PageData({
    required this.badge,
    required this.headlineLead,
    required this.headlineAccent,
    required this.body,
    required this.illustration,
    this.compact = false,
  });

  final IconData badge;
  final String headlineLead;
  final String headlineAccent;
  final String body;
  final Widget illustration;
  final bool compact;
}

class _ToolsShowcase extends StatelessWidget {
  const _ToolsShowcase();

  /// Label, tool id, card wash and ink — the same nine ids, colours and marks
  /// the All tools grid uses, so the promise here matches the screen.
  static const _tiles = <(String, String, Color, Color)>[
    ('Image to PDF', 'img-pdf', Color(0xFFE7F5FE), Color(0xFF0EA5E9)),
    ('Word to PDF', 'word-pdf', Color(0xFFEDF3FF), Color(0xFF2F6FED)),
    ('Compress', 'compress', Color(0xFFF1EDFF), Color(0xFF7C5CFF)),
    ('Merge PDF', 'merge', Color(0xFFF1EDFF), Color(0xFF7C5CFF)),
    ('PDF to Word', 'pdf-word', Color(0xFFEDF3FF), Color(0xFF2F6FED)),
    ('PDF to JPG', 'jpg', Color(0xFFE7F5FE), Color(0xFF0EA5E9)),
    ('Split PDF', 'split', Color(0xFFFFE9EE), Color(0xFFF43F5E)),
    ('Sign PDF', 'sign', Color(0xFFE2F5F2), Color(0xFF0D9488)),
    ('Extract', 'extract', Color(0xFFEDF3FF), Color(0xFF2F6FED)),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        Widget tile((String, String, Color, Color) item) {
          return Container(
            decoration: BoxDecoration(
              color: item.$3,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: item.$4.withValues(alpha: 0.14)),
            ),
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AllToolsMark(toolId: item.$2, ink: item.$4),
                    ),
                  ),
                ),
                Text(
                  item.$1,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    height: 1.15,
                    color: Color(0xFF101D41),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (var row = 0; row < 3; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0; col < 3; col++) ...[
                      if (col > 0) const SizedBox(width: gap),
                      Expanded(child: tile(_tiles[row * 3 + col])),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One scanned page, the sparkle, and the three enhance promises.
class _CleanPagesArt extends StatelessWidget {
  const _CleanPagesArt();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perkBlock = constraints.maxHeight < 280 ? 72.0 : 92.0;
        final artHeight = math.max(120.0, constraints.maxHeight - perkBlock);
        final cardWidth = math.min(
          constraints.maxWidth * 0.56,
          artHeight * 0.72,
        );
        final cardHeight = cardWidth * 1.16;
        return Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: constraints.maxWidth * 0.08,
                    top: artHeight * 0.08,
                    child: _SoftDisc(size: cardWidth * 0.72),
                  ),
                  Positioned(
                    right: constraints.maxWidth * 0.06,
                    bottom: artHeight * 0.06,
                    child: _SoftDisc(size: cardWidth * 0.55),
                  ),
                  Transform.rotate(
                    angle: -0.08,
                    child: _EnhanceCard(width: cardWidth, height: cardHeight),
                  ),
                  Positioned(
                    right: 0,
                    top: artHeight * 0.18,
                    child: const _SparkleMark(),
                  ),
                ],
              ),
            ),
            const _EnhancePerks(),
          ],
        );
      },
    );
  }
}

class _SoftDisc extends StatelessWidget {
  const _SoftDisc({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Brand.accent.withValues(alpha: 0.08),
      ),
    );
  }
}

class _EnhanceCard extends StatelessWidget {
  const _EnhanceCard({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = width * 0.07;
    return SizedBox(
      width: width + 36,
      height: height + 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(width + 28, height + 28),
            painter: _ScanCornersPainter(),
          ),
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: Brand.accent.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    width * 0.1,
                    height * 0.1,
                    width * 0.1,
                    height * 0.08,
                  ),
                  child: const _CleanPageCopy(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanPageCopy extends StatelessWidget {
  const _CleanPageCopy();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: math.max(constraints.maxWidth, 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meeting Notes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Brand.font,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Brand.docBlue,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < 4; i++) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width:
                          math.max(constraints.maxWidth, 1) *
                          (i.isEven ? 1 : 0.72),
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5DDEA),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                const SizedBox(height: 12),
                Container(
                  width: 54,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: Color(0xFFB7C0D0),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScanCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Brand.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const arm = 16.0;
    const inset = 2.0;
    final corners = <Offset>[
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ];
    final dirs = <List<Offset>>[
      [const Offset(arm, 0), const Offset(0, arm)],
      [const Offset(-arm, 0), const Offset(0, arm)],
      [const Offset(arm, 0), const Offset(0, -arm)],
      [const Offset(-arm, 0), const Offset(0, -arm)],
    ];
    for (var i = 0; i < corners.length; i++) {
      final path = Path()
        ..moveTo(corners[i].dx + dirs[i][0].dx, corners[i].dy + dirs[i][0].dy)
        ..lineTo(corners[i].dx, corners[i].dy)
        ..lineTo(corners[i].dx + dirs[i][1].dx, corners[i].dy + dirs[i][1].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparkleMark extends StatelessWidget {
  const _SparkleMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            bottom: 0,
            child: CustomPaint(
              size: Size(34, 26),
              painter: _HookArrowPainter(),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Brand.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Brand.accent.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HookArrowPainter extends CustomPainter {
  const _HookArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Brand.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(2, size.height - 2)
      ..quadraticBezierTo(
        size.width * 0.15,
        4,
        size.width - 2,
        size.height * 0.55,
      );
    canvas.drawPath(path, paint);
    final tip = Offset(size.width - 2, size.height * 0.55);
    final head = Path()
      ..moveTo(tip.dx - 7, tip.dy - 3)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 2, tip.dy + 7);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EnhancePerks extends StatelessWidget {
  const _EnhancePerks();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          _Perk(icon: Icons.crop_rounded, label: 'Auto Crop'),
          _Perk(icon: Icons.wb_sunny_outlined, label: 'Enhance Automatically'),
          _Perk(icon: Icons.description_outlined, label: 'Clear & Readable'),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Brand.accent.withValues(alpha: 0.45),
                width: 1.4,
              ),
            ),
            child: Icon(icon, color: Brand.accent, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontFamily: Brand.font,
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Brand.ink,
            ),
          ),
        ],
      ),
    );
  }
}

final _pages = <_PageData>[
  const _PageData(
    badge: Icons.document_scanner_rounded,
    headlineLead: 'Scan Anything\nin a ',
    headlineAccent: 'Snap',
    body:
        'Turn your phone into a powerful scanner.\n'
        'Fast, clear and easy.',
    illustration: HeroStage(
      centre: ScanningPhone(),
      chips: [
        HeroChip(
          x: 0.10,
          y: 0.36,
          icon: Icons.description_rounded,
          color: Brand.accent,
        ),
        HeroChip(
          x: 0.90,
          y: 0.32,
          icon: Icons.picture_as_pdf_rounded,
          color: Brand.pdfRed,
          label: 'PDF',
        ),
        HeroChip(
          x: 0.10,
          y: 0.72,
          icon: Icons.text_snippet_rounded,
          color: Brand.imageGreen,
          label: 'OCR',
        ),
        HeroChip(
          x: 0.90,
          y: 0.64,
          icon: Icons.lock_rounded,
          color: Brand.accent,
        ),
      ],
    ),
  ),
  const _PageData(
    badge: Icons.auto_fix_high_rounded,
    // No comma: at this size Plus Jakarta Sans leaves a visible gap before
    // it, and the sibling page sets no punctuation either.
    headlineLead: 'Clean Pages\n',
    headlineAccent: 'Every Time',
    body:
        'Edges are straightened and pages enhanced\n'
        'automatically. Export as PDF or images.',
    illustration: _CleanPagesArt(),
  ),
  const _PageData(
    badge: Icons.grid_view_rounded,
    headlineLead: 'PDF tools\nin one ',
    headlineAccent: 'place',
    body:
        'Convert Word and images, compress, merge, split and sign.\n'
        'Open All tools from home, next to your scans.',
    illustration: _ToolsShowcase(),
    compact: true,
  ),
];
