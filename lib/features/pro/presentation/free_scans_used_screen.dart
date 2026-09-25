import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';

/// Shown when the free allowance runs out.
///
/// Two versions of one screen. Someone Apple would still grant the
/// introductory month is offered it; everyone else is offered the yearly
/// plan instead, because a button promising a free month that bills on the
/// spot is a lie. [ProState.canStartTrial] decides which, and it is the
/// store's own answer wherever the store will give one.
Future<bool> showFreeScansUsed(BuildContext context, WidgetRef ref) async {
  await ref.read(scanQuotaProvider.notifier).ensureLoaded();
  if (!context.mounted) return false;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const FreeScansUsedScreen(),
    ),
  );
  return ref.read(proProvider).isPro;
}

class FreeScansUsedScreen extends ConsumerStatefulWidget {
  const FreeScansUsedScreen({super.key});

  @override
  ConsumerState<FreeScansUsedScreen> createState() =>
      _FreeScansUsedScreenState();
}

class _FreeScansUsedScreenState extends ConsumerState<FreeScansUsedScreen> {
  Future<void> _unlock() async {
    AppHaptics.selection();
    // Yearly either way: it is the plan the button names, and the
    // introductory month rides on it when Apple says the customer is owed
    // one.
    final ok = await ref
        .read(proProvider.notifier)
        .startOfferedTrialOrSubscribe(ProPlan.yearly);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(scanQuotaProvider);
    final pro = ref.watch(proProvider);
    final offer =
        pro.offer ??
        LocalizedPricing.formatOffer(
          currencyCode: 'USD',
          countryCode: 'US',
          countryName: 'United States',
          usdToLocal: 1,
          source: 'device',
        );
    final courtesy = pro.canStartCourtesyTrial;
    final firstTime = courtesy || pro.canStartTrial;

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: Brand.accent,
        body: Container(
          decoration: const BoxDecoration(
            color: Brand.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          margin: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          child: SafeArea(
            top: false,
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
                      const _EmptyMailMark(),
                      const SizedBox(height: 18),
                      Text(
                        'You’ve used all\n${quota.usedUpLimit} free scans!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: Brand.font,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.5,
                          color: Brand.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'You can continue using Scanella with '
                        '${ScanQuota.monthlyLimit} free scans every '
                        '${ScanQuota.resetDays} days, or unlock unlimited '
                        'scanning with Pro. Every PDF tool stays free, with '
                        'no scan limit.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Brand.grey,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _NextScansCard(quota: quota),
                      const SizedBox(height: 18),
                      _UnlockButton(
                        busy: pro.busy,
                        title: firstTime
                            ? 'Unlock Scanella Pro'
                            : 'Upgrade to Scanella Pro',
                        detail: courtesy
                            ? ProTrial.freeTitle
                            : firstTime
                            ? 'Get 1 month FREE'
                            : 'Best Value · ${offer.yearlyLabel} per year',
                        onPressed: _unlock,
                      ),
                      if (pro.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          pro.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An envelope with nothing left in it.
class _EmptyMailMark extends StatelessWidget {
  const _EmptyMailMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 146,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 130,
            decoration: const BoxDecoration(
              color: Color(0xFFFDE9EC),
              borderRadius: BorderRadius.all(Radius.circular(70)),
            ),
          ),
          const Icon(Icons.mail_rounded, size: 76, color: Color(0xFF2F6FED)),
          Positioned(
            right: 92,
            bottom: 22,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE8443A),
                shape: BoxShape.circle,
                border: Border.all(color: Brand.surface, width: 3),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// When the next free scans land, and how long that is from now.
class _NextScansCard extends StatelessWidget {
  const _NextScansCard({required this.quota});

  final ScanQuota quota;

  @override
  Widget build(BuildContext context) {
    final at = quota.resetsAt;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FD),
        borderRadius: BorderRadius.circular(Brand.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 32,
              color: Color(0xFF2F6FED),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next ${ScanQuota.monthlyLimit} free scans available'
                    '${at == null ? '' : ' on'}',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: Brand.grey,
                    ),
                  ),
                  if (at != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      ScanQuota.formatResetDate(at),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ScanQuota.formatCountdown(at.difference(DateTime.now())),
                      style: const TextStyle(fontSize: 13, color: Brand.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockButton extends StatelessWidget {
  const _UnlockButton({
    required this.busy,
    required this.title,
    required this.detail,
    required this.onPressed,
  });

  final bool busy;
  final String title;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: busy ? Brand.accent.withValues(alpha: 0.45) : Brand.accent,
      borderRadius: BorderRadius.circular(Brand.radiusButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(Brand.radiusButton),
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
