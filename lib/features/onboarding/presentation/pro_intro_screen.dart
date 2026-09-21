import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/presentation/pro_paywall.dart' show ProMark;

/// The Pro offer, shown once at the end of the intro.
///
/// Buying goes through [ProController.subscribe], the same StoreKit path as
/// the rest of the app, so the Apple sheet is the real one. The free month is
/// an introductory offer configured in App Store Connect: StoreKit applies it
/// and bills the plan afterwards. Nothing here grants it.
///
/// Apple gives that month once per subscription group. Someone who has taken
/// it already — including a reinstall after a cancelled trial — is shown the
/// plan price instead, because a "1 month FREE" button would charge them on
/// the spot. [ProState.canStartTrial] decides, and it is the store's own
/// answer wherever the store will give one.
class ProIntroScreen extends ConsumerStatefulWidget {
  const ProIntroScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<ProIntroScreen> createState() => _ProIntroScreenState();
}

class _ProIntroScreenState extends ConsumerState<ProIntroScreen> {
  ProPlan _plan = ProPlan.yearly;

  Future<void> _subscribe() async {
    AppHaptics.selection();
    final ok = await ref.read(proProvider.notifier).subscribe(_plan);
    if (ok && mounted) widget.onDone();
  }

  Future<void> _restore() async {
    await ref.read(proProvider.notifier).restorePurchases();
    if (!mounted) return;
    if (ref.read(proProvider).isPro) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
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
    // The store's answer, not a guess: an introductory offer has to exist
    // and this Apple ID has to still be owed one.
    final firstTime = pro.canStartTrial;

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: Brand.surface,
        body: SafeArea(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, color: Brand.ink),
                    onPressed: widget.onDone,
                  ),
                  TextButton(
                    onPressed: pro.busy ? null : _restore,
                    child: const Text(
                      'Restore',
                      style: TextStyle(
                        color: Brand.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  children: [
                    Row(
                      children: [
                        const ProMark(size: 28),
                        const SizedBox(width: 10),
                        const _ProWordmark(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'More than a scanner.\n'
                      'Your complete document solution.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: Brand.grey,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _Tick('Unlimited scans'),
                    const _Tick('OCR – extract text'),
                    const _Tick('Advanced PDF tools'),
                    const _Tick('No ads'),
                    const SizedBox(height: 22),
                    _PlanCard(
                      selected: _plan == ProPlan.yearly,
                      title: firstTime ? '1 month FREE' : 'Yearly',
                      price: '${offer.yearlyLabel} per year',
                      badge: 'Best Value',
                      onTap: () => setState(() => _plan = ProPlan.yearly),
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      selected: _plan == ProPlan.monthly,
                      title: firstTime ? '1 month FREE' : 'Monthly',
                      price: '${offer.monthlyLabel} per month',
                      onTap: () => setState(() => _plan = ProPlan.monthly),
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
                    const SizedBox(height: 18),
                    SizedBox(
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
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Brand.radiusButton,
                            ),
                          ),
                        ),
                        onPressed: pro.busy ? null : _subscribe,
                        child: Text(
                          firstTime
                              ? 'Start 1 Month Free Trial'
                              : 'Continue',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: widget.onDone,
                        child: const Text(
                          'Maybe Later',
                          style: TextStyle(
                            color: Brand.accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstTime
                          ? 'Cancel anytime. Your subscription will '
                                'automatically renew at the end of the trial.'
                          : 'Cancel anytime. Your subscription renews '
                                'automatically until you cancel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Brand.grey,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FooterLinks(onRestore: pro.busy ? null : _restore),
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

class _ProWordmark extends StatelessWidget {
  const _ProWordmark();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: Brand.font,
          fontSize: 27,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: Brand.ink,
        ),
        children: [
          TextSpan(text: 'Scanella '),
          TextSpan(text: 'Pro', style: TextStyle(color: Brand.accent)),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Brand.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 15,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Brand.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// One plan. The heading is the introductory month where Apple still owes
/// one, and the plain plan name where it does not; the price underneath is
/// what gets billed either way.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.price,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final String title;
  final String price;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: selected ? const Color(0xFFEAF7F1) : Brand.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Brand.accent : Brand.outline,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 30,
                color: selected ? Brand.accent : Brand.grey,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Brand.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Brand.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (badge == null) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          right: 12,
          top: -10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Brand.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.onRestore});

  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 13,
      color: Color(0xFF2F6FED),
      fontWeight: FontWeight.w600,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () => context.push('/legal/terms'),
          child: const Text('Terms of Service', style: style),
        ),
        const Text('|', style: TextStyle(color: Brand.outline)),
        TextButton(
          onPressed: () => context.push('/legal/privacy'),
          child: const Text('Privacy Policy', style: style),
        ),
        const Text('|', style: TextStyle(color: Brand.outline)),
        TextButton(
          onPressed: onRestore,
          child: const Text('Restore Purchase', style: style),
        ),
      ],
    );
  }
}
