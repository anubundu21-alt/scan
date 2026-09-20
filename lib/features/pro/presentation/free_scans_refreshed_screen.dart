import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';

/// Shown once when the free allowance fills back up after the reset period.
///
/// Good news, so it says so and gets out of the way: one button, straight
/// back to scanning. Every number comes from [ScanQuota], so the screen
/// cannot promise scans the app will not grant.
Future<void> showFreeScansRefreshed(BuildContext context, WidgetRef ref) async {
  await ref.read(scanQuotaProvider.notifier).ensureLoaded();
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const FreeScansRefreshedScreen(),
    ),
  );
}

class FreeScansRefreshedScreen extends ConsumerWidget {
  const FreeScansRefreshedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(scanQuotaProvider);
    final count = quota.limit;

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: Brand.surface,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Brand.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  children: [
                    const SizedBox(height: 8),
                    const _GiftMark(),
                    const SizedBox(height: 24),
                    Text(
                      'You’ve got $count new\nfree scans!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: Brand.font,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                        color: Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your free scans have been refreshed. '
                      'Start scanning now.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.45,
                        color: Brand.grey,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _AvailableCard(count: count, quota: quota),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: SizedBox(
                  height: Brand.buttonHeight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.accent,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontFamily: Brand.font,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Brand.radiusButton,
                        ),
                      ),
                    ),
                    onPressed: () {
                      AppHaptics.selection();
                      Navigator.of(context).pop();
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Start Scanning'),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How many are waiting, and what happens to the ones left over.
class _AvailableCard extends StatelessWidget {
  const _AvailableCard({required this.count, required this.quota});

  final int count;
  final ScanQuota quota;

  @override
  Widget build(BuildContext context) {
    final at = quota.resetsAt;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FE),
        borderRadius: BorderRadius.circular(Brand.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              size: 28,
              color: Brand.accent,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count free scans available',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Brand.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    // Unused scans do not expire on a date of their own: the
                    // next period only starts once the last one is spent. So
                    // a date is only shown when there really is one.
                    at == null
                        ? 'Unused scans don’t carry over'
                        : 'Valid until ${ScanQuota.formatResetDate(at)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Brand.grey,
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

/// A wrapped gift, mid-celebration.
class _GiftMark extends StatelessWidget {
  const _GiftMark();

  static const _confetti = <_Fleck>[
    _Fleck(left: 30, top: 84, angle: 0.6, color: Color(0xFFF2B33D)),
    _Fleck(left: 14, top: 40, angle: -0.5, color: Color(0xFFE8574C)),
    _Fleck(left: 52, top: 16, angle: 0.9, color: Color(0xFF4A90E2)),
    _Fleck(left: 96, top: 2, angle: -0.2, color: Color(0xFFE8574C)),
    _Fleck(left: 8, top: 120, angle: 0.3, color: Color(0xFFF2B33D)),
    _Fleck(right: 34, top: 80, angle: -0.7, color: Color(0xFF4A90E2)),
    _Fleck(right: 16, top: 42, angle: 0.5, color: Color(0xFFE8574C)),
    _Fleck(right: 56, top: 14, angle: -0.9, color: Color(0xFFF2B33D)),
    _Fleck(right: 6, top: 116, angle: -0.3, color: Color(0xFF3BB888)),
    _Fleck(right: 44, top: 142, angle: 0.8, color: Color(0xFF4A90E2)),
    _Fleck(left: 40, top: 150, angle: -0.6, color: Color(0xFFE8574C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 250,
        height: 186,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final fleck in _confetti) fleck,
            const _GiftBox(),
          ],
        ),
      ),
    );
  }
}

/// One scrap of confetti.
class _Fleck extends StatelessWidget {
  const _Fleck({
    this.left,
    this.right,
    required this.top,
    required this.angle,
    required this.color,
  });

  final double? left;
  final double? right;
  final double top;
  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 7,
          height: 19,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _GiftBox extends StatelessWidget {
  const _GiftBox();

  static const _light = Brand.accentTint;
  static const _dark = Color(0xFF2E8B63);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The bow: two leaves tipped away from each other over a knot.
        SizedBox(
          height: 36,
          width: 120,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(left: 14, bottom: 2, child: _leaf(-0.5)),
              Positioned(right: 14, bottom: 2, child: _leaf(0.5, flip: true)),
              Container(
                width: 22,
                height: 20,
                decoration: const BoxDecoration(
                  color: _dark,
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 148,
          height: 30,
          decoration: const BoxDecoration(
            color: _dark,
            borderRadius: BorderRadius.all(Radius.circular(9)),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 128,
          height: 82,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: _light,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                ),
              ),
              Container(width: 22, color: _dark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _leaf(double angle, {bool flip = false}) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 44,
        height: 30,
        decoration: BoxDecoration(
          color: _dark,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(flip ? 6 : 24),
            bottomLeft: Radius.circular(flip ? 6 : 24),
            topRight: Radius.circular(flip ? 24 : 6),
            bottomRight: Radius.circular(flip ? 24 : 6),
          ),
        ),
      ),
    );
  }
}
