import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';

/// A heads-up when the free allowance is nearly gone.
///
/// Shown once per batch of scans, and always dismissible: the scans that
/// are left still work, so this is a nudge, not a wall. The used-up screen
/// is the one that carries the full offer.
Future<bool> showLowScansLeft(BuildContext context, WidgetRef ref) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const LowScansScreen(),
    ),
  );
  return ref.read(proProvider).isPro;
}

class LowScansScreen extends ConsumerStatefulWidget {
  const LowScansScreen({super.key});

  @override
  ConsumerState<LowScansScreen> createState() => _LowScansScreenState();
}

class _LowScansScreenState extends ConsumerState<LowScansScreen> {
  Future<void> _upgrade() async {
    AppHaptics.selection();
    final ok = await ref.read(proProvider.notifier).subscribe(ProPlan.yearly);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(scanQuotaProvider);
    final pro = ref.watch(proProvider);
    final left = quota.remaining;

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
                    const _RunningLowMark(),
                    const SizedBox(height: 26),
                    Text(
                      left == 1
                          ? 'Just 1 scan left!'
                          : 'Just $left scans left!',
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
                      'You’ve used ${quota.used} of ${quota.limit} free '
                      'scans. Unlock Pro for unlimited scanning and all '
                      'premium features.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.45,
                        color: Brand.grey,
                      ),
                    ),
                    if (pro.error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        pro.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: SizedBox(
                  height: Brand.buttonHeight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Brand.accent.withValues(
                        alpha: 0.45,
                      ),
                      disabledForegroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontFamily: Brand.font,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Brand.radiusButton),
                      ),
                    ),
                    onPressed: pro.busy ? null : _upgrade,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspace_premium_rounded, size: 22),
                        SizedBox(width: 10),
                        Text('Upgrade to Pro'),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: Brand.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// A document with a warning pinned to it.
class _RunningLowMark extends StatelessWidget {
  const _RunningLowMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 230,
        height: 176,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The soft wash behind, off-centre like the drawing.
            Positioned(
              left: 18,
              top: 6,
              child: Container(
                width: 168,
                height: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF5F4),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(80),
                    topRight: Radius.circular(64),
                    bottomLeft: Radius.circular(58),
                    bottomRight: Radius.circular(80),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 44,
              top: 16,
              child: Container(
                width: 108,
                height: 134,
                decoration: BoxDecoration(
                  color: Brand.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDCE4EE)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Line(width: 46, color: Color(0xFF4A90E2)),
                    SizedBox(height: 12),
                    _Line(width: 74, color: Color(0xFFD9E1EC)),
                    SizedBox(height: 10),
                    _Line(width: 74, color: Color(0xFFD9E1EC)),
                    SizedBox(height: 10),
                    _Line(width: 48, color: Color(0xFFD9E1EC)),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 36,
              bottom: 16,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E8B63),
                  shape: BoxShape.circle,
                  border: Border.all(color: Brand.surface, width: 4),
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
