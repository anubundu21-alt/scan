import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';

Future<void> showProPaywall(
  BuildContext context, {
  bool requireChoice = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: !requireChoice,
    enableDrag: !requireChoice,
    showDragHandle: !requireChoice,
    builder: (context) => const ProPaywall(),
  );
}

class ProPaywall extends ConsumerStatefulWidget {
  const ProPaywall({super.key});

  @override
  ConsumerState<ProPaywall> createState() => _ProPaywallState();
}

class _ProPaywallState extends ConsumerState<ProPaywall> {
  ProPlan _plan = ProPlan.yearly;

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
    final quota = ref.watch(scanQuotaProvider);
    final height = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: SizedBox(
        height: height * 0.92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Expanded(child: ScanellaWordmark(fontSize: 22)),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  Row(
                    children: [
                      const ProMark(size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Scanella Pro',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Scans stay on this device. Pro adds the extras below.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (!quota.canCreate) ...[
                    const SizedBox(height: 10),
                    Text(
                      quota.usedUpMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _PlanCard(
                    selected: _plan == ProPlan.yearly,
                    title: 'Yearly',
                    price: offer.yearlyLabel,
                    detail: pro.storeProductsReady
                        ? '${offer.yearlyPerMonthLabel} / month · save '
                              '${offer.yearlySavingsPercent}%'
                        : 'Estimated · ${offer.yearlyPerMonthLabel} / month',
                    badge: 'Best value',
                    onTap: () => setState(() => _plan = ProPlan.yearly),
                  ),
                  const SizedBox(height: 10),
                  _PlanCard(
                    selected: _plan == ProPlan.monthly,
                    title: 'Monthly',
                    price: offer.monthlyLabel,
                    detail: pro.storeProductsReady
                        ? 'Cancel any time'
                        : 'Estimated · Cancel any time',
                    onTap: () => setState(() => _plan = ProPlan.monthly),
                  ),
                  if (pro.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      pro.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: pro.busy || pro.isPro
                        ? null
                        : () async {
                            AppHaptics.selection();
                            final ok = await ref
                                .read(proProvider.notifier)
                                .subscribe(_plan);
                            if (ok && context.mounted) Navigator.pop(context);
                          },
                    child: Text(
                      pro.isPro
                          ? 'You have Scanella Pro'
                          : !pro.storeProductsReady
                          ? 'Try App Store'
                          : _plan == ProPlan.yearly
                          ? 'Subscribe yearly · ${offer.yearlyLabel}'
                          : 'Subscribe monthly · ${offer.monthlyLabel}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Payment uses your Apple ID. Scanella never sees your card.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: pro.busy
                        ? null
                        : () =>
                              ref.read(proProvider.notifier).restorePurchases(),
                    child: const Text('Restore purchases'),
                  ),
                  const SizedBox(height: 20),
                  Text('Included with Pro', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  for (final feature in _features)
                    _FeatureBullet(feature: feature),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProFeature {
  const _ProFeature(this.title, [this.detail]);

  final String title;
  final String? detail;
}

const _features = [
  _ProFeature('Unlimited scans'),
  _ProFeature('All tools'),
  _ProFeature(
    'Auto-save by document type',
    'Passports go to Private. ID cards get a second copy in IDs.',
  ),
  _ProFeature('Searchable PDFs and extra OCR languages'),
  _ProFeature('Smart folders, tags and favorites'),
  _ProFeature('Private documents, Face ID to open'),
  _ProFeature('PNG, print, selected pages and batch export'),
];

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.feature});

  final _ProFeature feature;

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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.price,
    required this.detail,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final String title;
  final String price;
  final String detail;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onPressed: onTap,
      haptic: AppHaptic.selection,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(Brand.radiusCard),
      minSize: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : (theme.brightness == Brightness.light
                    ? Colors.white
                    : scheme.surface),
          borderRadius: BorderRadius.circular(Brand.radiusCard),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Brand.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            Text(price, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
