import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';

/// Yearly / monthly cards, subscribe, and restore — shared by the paywall
/// and Complete features.
class ProCheckout extends ConsumerStatefulWidget {
  const ProCheckout({super.key, this.onSubscribed});

  final VoidCallback? onSubscribed;

  @override
  ConsumerState<ProCheckout> createState() => _ProCheckoutState();
}

class _ProCheckoutState extends ConsumerState<ProCheckout> {
  ProPlan _plan = ProPlan.yearly;

  void _select(ProPlan plan) {
    ref.read(proProvider.notifier).clearError();
    setState(() => _plan = plan);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProPlanCard(
          selected: _plan == ProPlan.yearly,
          title: 'Yearly',
          price: offer.yearlyLabel,
          detail: '${offer.yearlyPerMonthLabel} / month · save '
              '${offer.yearlySavingsPercent}%',
          badge: 'Best value',
          onTap: () => _select(ProPlan.yearly),
        ),
        const SizedBox(height: 10),
        ProPlanCard(
          selected: _plan == ProPlan.monthly,
          title: 'Monthly',
          price: offer.monthlyLabel,
          detail: 'Cancel any time',
          onTap: () => _select(ProPlan.monthly),
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
        SizedBox(
          height: Brand.buttonHeight,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Brand.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Brand.accent.withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Brand.radiusButton),
              ),
            ),
            onPressed: pro.busy || pro.isPro
                ? null
                : () async {
                    AppHaptics.selection();
                    final ok = await ref
                        .read(proProvider.notifier)
                        .subscribe(_plan);
                    if (ok && context.mounted) widget.onSubscribed?.call();
                  },
            child: Text(
              pro.isPro ? 'You have Scanella Pro' : 'Upgrade Now',
            ),
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
              : () => ref.read(proProvider.notifier).restorePurchases(),
          child: Text(
            'Restore purchases',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Brand.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class ProPlanCard extends StatelessWidget {
  const ProPlanCard({
    super.key,
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
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
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
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
