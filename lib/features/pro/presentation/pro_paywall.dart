import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/pro_features.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:scan2/features/pro/presentation/pro_checkout.dart';

Future<void> showProPaywall(
  BuildContext context, {
  bool requireChoice = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: !requireChoice,
    enableDrag: !requireChoice,
    backgroundColor: const Color(0xFFF5F7FA),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    // The sheet is always light, so its text must be too.
    builder: (context) =>
        Theme(data: AppTheme.light, child: const ProPaywall()),
  );
}

class ProPaywall extends ConsumerStatefulWidget {
  const ProPaywall({super.key});

  @override
  ConsumerState<ProPaywall> createState() => _ProPaywallState();
}

class _ProPaywallState extends ConsumerState<ProPaywall> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(proProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quota = ref.watch(scanQuotaProvider);
    final isPro = ref.watch(proProvider).isPro;
    final height = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: SizedBox(
        height: height * 0.94,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                children: [
                  const _GoProBanner(),
                  if (!isPro && !quota.canCreate) ...[
                    const SizedBox(height: 12),
                    Text(
                      quota.usedUpMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const ProMark(size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Pro features',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pay with your Apple ID. Cancel any time from iOS Settings.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  const _ProBenefitTile(
                    icon: Icons.all_inclusive_rounded,
                    color: Color(0xFF1F9A6B),
                    wash: Color(0xFFE4F3ED),
                    title: 'Unlimited scans',
                    detail: 'Scan as many documents as you need.',
                  ),
                  const _ProBenefitTile(
                    icon: Icons.schedule_rounded,
                    color: Color(0xFF7B61FF),
                    wash: Color(0xFFF0ECFF),
                    title: 'No ${ScanQuota.resetDays}-day wait',
                    detail: 'Keep scanning after the free scans run out.',
                  ),
                  const _ProBenefitTile(
                    icon: Icons.check_circle_outline_rounded,
                    color: Color(0xFF2C7BE5),
                    wash: Color(0xFFE6F0FF),
                    title: 'Everything else stays free',
                    detail: 'Text extraction, PDF tools, export and folders.',
                  ),
                  const SizedBox(height: 8),
                  ProCheckout(
                    onSubscribed: () {
                      if (context.mounted) Navigator.pop(context);
                    },
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

class _GoProBanner extends StatelessWidget {
  const _GoProBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB6E4CE), Color(0xFFD4F0E2)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const ProMark(size: 28),
                        const SizedBox(width: 8),
                        Text(
                          'Go Pro',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock the full power of Scanella and scan without limits.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _ScanPapersArt(),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _HeroChip(
                  icon: Icons.all_inclusive_rounded,
                  color: Color(0xFF1F9A6B),
                  wash: Color(0xFFF4FBF7),
                  label: 'Unlimited scans',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _HeroChip(
                  icon: Icons.schedule_rounded,
                  color: Color(0xFF7B61FF),
                  wash: Color(0xFFF7F4FF),
                  label: 'No ${ScanQuota.resetDays}-day wait',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _HeroChip(
                  icon: Icons.check_circle_outline_rounded,
                  color: Color(0xFF2C7BE5),
                  wash: Color(0xFFF1F6FF),
                  label: 'Rest is free',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.color,
    required this.wash,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final Color wash;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: wash,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: Brand.ink,
          ),
        ),
      ],
    );
  }
}

class _ScanPapersArt extends StatelessWidget {
  const _ScanPapersArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 14,
            child: Transform.rotate(
              angle: 0.22,
              child: _paper(
                fill: const Color(0xFF7FC9A3),
                width: 52,
                height: 66,
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 2,
            child: Transform.rotate(
              angle: -0.08,
              child: _paper(
                fill: Colors.white,
                width: 56,
                height: 72,
                framed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paper({
    required Color fill,
    required double width,
    required double height,
    bool framed = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E6DE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: framed
          ? Center(
              child: Container(
                width: width * 0.62,
                height: height * 0.62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Brand.accent, width: 2),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: Brand.accent,
                  size: 18,
                ),
              ),
            )
          : null,
    );
  }
}

class _ProBenefitTile extends StatelessWidget {
  const _ProBenefitTile({
    required this.icon,
    required this.color,
    required this.wash,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final Color wash;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: wash,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureBullet extends StatelessWidget {
  const FeatureBullet({super.key, required this.feature});

  final ProFeatureLine feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Brand.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (feature.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(feature.detail!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold crown used next to Scanella Pro, the way other apps mark a paid plan.
class ProMark extends StatelessWidget {
  const ProMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF3C4),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.workspace_premium_rounded,
        size: size * 0.62,
        color: Brand.amber,
      ),
    );
  }
}
