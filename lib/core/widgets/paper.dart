import 'dart:async';

import 'package:flutter/material.dart';

/// A scan, drawn as a sheet of paper.
///
/// The library used to render each scan as an image in a bordered box. That is
/// fine until the scan is what scans usually are — a white page — at which
/// point the page, the card and the background are all near-white and the
/// thumbnail has no edge at all. A grid of them reads as empty rectangles.
///
/// So a page here is given the two things that make paper look like paper: a
/// hairline drawn *over* the image, so the edge survives whatever is inside
/// it, and a layered shadow — one tight and dark to seat it, one wide and soft
/// to lift it. In dark mode the shadow does nothing useful, so the edge takes
/// over and the sheet sits on a lighter surface instead.
class PaperSheet extends StatelessWidget {
  const PaperSheet({
    super.key,
    required this.child,
    this.radius = 16,
    this.selected = false,
    this.stacked = false,
    this.lift = 1,
  });

  final Widget child;
  final double radius;
  final bool selected;

  /// Draws two sheets peeking out behind this one. A page count in a badge
  /// tells you it is a multi-page document; this lets you see it.
  final bool stacked;

  /// Scales the shadow. Small thumbnails need less of it than a hero.
  final double lift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    final sheet = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isLight ? Colors.white : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.10 * lift),
                  blurRadius: 3 * lift,
                  offset: Offset(0, 1 * lift),
                ),
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.10 * lift),
                  blurRadius: 18 * lift,
                  offset: Offset(0, 8 * lift),
                ),
              ]
            : const [],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected
              ? scheme.primary
              : (isLight
                    ? scheme.shadow.withValues(alpha: 0.14)
                    : scheme.outlineVariant),
          width: selected ? 2.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );

    if (!stacked) return sheet;

    // The pages underneath, fanned up and to the right. Every offset stays
    // inside the tile's own box — a stack that bled outside it would collide
    // with its neighbours in the grid.
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 9,
          top: 0,
          right: 0,
          bottom: 11,
          child: _GhostSheet(radius: radius, opacity: 0.45),
        ),
        Positioned(
          left: 5,
          top: 5,
          right: 4,
          bottom: 6,
          child: _GhostSheet(radius: radius, opacity: 0.75),
        ),
        Positioned(left: 0, top: 11, right: 9, bottom: 0, child: sheet),
      ],
    );
  }
}

class _GhostSheet extends StatelessWidget {
  const _GhostSheet({required this.radius, required this.opacity});

  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (isLight ? Colors.white : scheme.surfaceContainerHigh).withValues(
          alpha: opacity,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

/// Fades and lifts its child into place, staggered by [index].
///
/// The library used to appear fully formed between one frame and the next.
/// Content that arrives with a beat of movement is most of what separates an
/// app that feels built from one that feels generated — and it costs one
/// animation controller per tile.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.index,
    required this.child,
    this.offset = 18,
  });

  final int index;
  final Widget child;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  // Built once, not per frame: a CurvedAnimation holds a listener on its
  // parent, so making a fresh one inside build leaks one per rebuild.
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Capped: past the first screenful the stagger stops being a rhythm and
    // starts being a wait.
    final delay = 40 * (widget.index.clamp(0, 8));
    _timer = Timer(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
