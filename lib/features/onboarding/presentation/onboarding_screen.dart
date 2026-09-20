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
    // On to the free-plan explainer, then the Pro offer. Someone who already
    // has Pro has neither a free allowance to explain nor an offer to see,
    // so they go straight in. There is still no account and no login: the
    // only wall in front of this scanner is one you can close.
    if (ref.read(proProvider).isPro) {
      ref.read(onboardingCompletedProvider.notifier).complete();
      context.go('/library');
      return;
    }
    context.go('/free-access');
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
          icon: Icons.qr_code_2_rounded,
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
  // Middle page: the design pack did not include this one, so it covers the
  // step between capturing and privacy — what the app does with a scan.
  const _PageData(
    badge: Icons.auto_fix_high_rounded,
    // No comma: at this size Plus Jakarta Sans leaves a visible gap before
    // it, and the sibling page sets no punctuation either.
    headlineLead: 'Clean Pages\n',
    headlineAccent: 'Every Time',
    body:
        'Edges are straightened and pages enhanced\n'
        'automatically. Export as PDF or images.',
    illustration: HeroStage(
      centre: ScannerDevice(),
      chips: [
        HeroChip(
          x: 0.10,
          y: 0.32,
          icon: Icons.crop_rounded,
          color: Brand.accent,
        ),
        HeroChip(x: 0.90, y: 0.36, icon: Icons.tune_rounded, color: Brand.accent),
        HeroChip(
          x: 0.11,
          y: 0.70,
          icon: Icons.picture_as_pdf_rounded,
          color: Brand.pdfRed,
          label: 'PDF',
        ),
        HeroChip(
          x: 0.89,
          y: 0.72,
          icon: Icons.ios_share_rounded,
          color: Brand.imageGreen,
        ),
      ],
    ),
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
