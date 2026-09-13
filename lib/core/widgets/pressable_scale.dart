import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/tactile.dart';

/// Instant down-state + snappy spring release for tappable controls.
///
/// Scale and overlay snap on pointer-down (not after [onPressed], and not
/// tweened in). Sliding off springs back and does not fire the action.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.haptic = AppHaptic.selection,
    this.longPressHaptic = AppHaptic.impactMedium,
    this.scale = Tactile.pressScaleCard,
    this.enabled = true,
    this.overlay = true,
    this.hapticOnDown = true,
    this.borderRadius,
    this.minSize = Tactile.minHitSize,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onPressed;

  /// The library enters multi-select on a long press, so the press language
  /// has to carry that too — otherwise the one gesture that changes mode is
  /// the one control in the app that does not answer your finger.
  final VoidCallback? onLongPress;

  final AppHaptic haptic;
  final AppHaptic longPressHaptic;
  final double scale;
  final bool enabled;
  final bool overlay;

  /// When false, haptic waits for a confirmed tap. Use inside scroll views
  /// that have competing child buttons.
  final bool hapticOnDown;
  final BorderRadius? borderRadius;
  final double minSize;
  final String? tooltip;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _held = false;
  bool _cancelled = false;
  bool _hapticPlayed = false;
  Offset? _downGlobal;

  bool get _canPress => widget.enabled && widget.onPressed != null;
  bool get _canLongPress => widget.enabled && widget.onLongPress != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _pressedScale(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Tactile.pressScaleReduce;
    }
    return widget.scale;
  }

  void _snapPressed() {
    _controller.stop();
    _controller.value = _pressedScale(context);
  }

  void _springBack() {
    _controller.stop();
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        Tactile.spring,
        _controller.value,
        1,
        _controller.velocity,
      ),
    );
  }

  void _playHaptic() {
    if (_hapticPlayed || widget.haptic == AppHaptic.none) return;
    _hapticPlayed = true;
    AppHaptics.play(widget.haptic);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_canPress) return;
    _held = true;
    _cancelled = false;
    _hapticPlayed = false;
    _downGlobal = event.position;
    _snapPressed();
    if (widget.hapticOnDown) _playHaptic();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_held || _cancelled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(event.position);
    final inside = (Offset.zero & box.size).inflate(4);
    final moved = _downGlobal == null
        ? 0.0
        : (event.position - _downGlobal!).distance;
    if (moved > Tactile.slideCancelSlop || !inside.contains(local)) {
      _cancelHold();
    }
  }

  void _cancelHold() {
    if (_cancelled && !_held) return;
    _cancelled = true;
    _held = false;
    _springBack();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_held) return;
    _held = false;
    _springBack();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _cancelHold();
  }

  void _onTap() {
    if (!_canPress || _cancelled) return;
    _playHaptic();
    widget.onPressed!();
  }

  void _onLongPress() {
    if (!_canLongPress || _cancelled) return;
    // A long press is a different event from a tap, so it gets its own
    // haptic even when the down-haptic already fired.
    if (widget.longPressHaptic != AppHaptic.none) {
      AppHaptics.play(widget.longPressHaptic);
    }
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = _controller.value;
        Widget painted = child!;
        if (widget.overlay) {
          final travel = (1 - widget.scale).clamp(0.001, 1.0);
          final t = ((1 - scale) / travel).clamp(0.0, 1.0);
          painted = Stack(
            fit: StackFit.passthrough,
            children: [
              painted,
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: widget.borderRadius ?? BorderRadius.zero,
                    child: ColoredBox(
                      color: Tactile.overlayColor(
                        opacity: Tactile.pressOverlay * t,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return Transform.scale(
          key: const ValueKey('scanella-press-scale'),
          scale: scale,
          filterQuality: FilterQuality.low,
          transformHitTests: false,
          child: painted,
        );
      },
      child: widget.child,
    );

    child = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minSize,
        minHeight: widget.minSize,
      ),
      child: child,
    );

    child = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _canPress ? _onTap : null,
        onLongPress: _canLongPress ? _onLongPress : null,
        child: child,
      ),
    );

    child = Semantics(
      button: true,
      enabled: _canPress || _canLongPress,
      child: child,
    );

    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}

/// 44×44 icon control with selection haptic and a pressed scale.
class TactileIconButton extends StatelessWidget {
  const TactileIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size = 24,
    this.haptic = AppHaptic.selection,
    this.scale = Tactile.pressScaleIcon,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;
  final AppHaptic haptic;
  final double scale;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onPressed: onPressed,
      enabled: enabled && onPressed != null,
      haptic: haptic,
      scale: scale,
      overlay: true,
      borderRadius: BorderRadius.circular(22),
      tooltip: tooltip,
      child: SizedBox(
        width: Tactile.minHitSize,
        height: Tactile.minHitSize,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

/// Text/link control (Done, View All, Change) with selection haptic.
class TactileTextButton extends StatelessWidget {
  const TactileTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style,
    this.haptic = AppHaptic.selection,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final String label;
  final VoidCallback? onPressed;
  final TextStyle? style;
  final AppHaptic haptic;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onPressed: onPressed,
      haptic: haptic,
      scale: Tactile.pressScaleIcon,
      overlay: true,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: padding,
        child: Text(label, style: style),
      ),
    );
  }
}

/// A primary or secondary action, built on [PressableScale] rather than on a
/// Material button.
///
/// Material's buttons answer a tap with an ink ripple: it starts where you
/// touched and spreads over about a quarter of a second, which is a report
/// that the tap happened rather than a reply to the finger making it. These
/// scale and dim the moment the pointer lands and spring back on release.
class TactileButton extends StatelessWidget {
  const TactileButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.haptic = AppHaptic.impactLight,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final AppHaptic haptic;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;

    final background = filled
        ? (enabled ? scheme.primary : scheme.primary.withValues(alpha: 0.4))
        : Colors.transparent;
    final foreground = filled
        ? scheme.onPrimary
        : (enabled ? scheme.onSurface : scheme.onSurfaceVariant);

    return PressableScale(
      onPressed: onPressed,
      enabled: enabled,
      haptic: haptic,
      scale: Tactile.pressScalePrimary,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: foreground),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontSize: 16.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
