import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/pro_features.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/presentation/pro_checkout.dart';
import 'package:scan2/features/pro/presentation/pro_paywall.dart';

/// Drawer page: Free vs Pro, laid out as the choose-your-plan mock.
class CompleteFeaturesScreen extends ConsumerStatefulWidget {
  const CompleteFeaturesScreen({super.key});

  @override
  ConsumerState<CompleteFeaturesScreen> createState() =>
      _CompleteFeaturesScreenState();
}

class _CompleteFeaturesScreenState
    extends ConsumerState<CompleteFeaturesScreen> {
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
    final light = theme.brightness == Brightness.light;
    return Scaffold(
      backgroundColor: light
          ? const Color(0xFFF5F7FA)
          : theme.colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Choose your plan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Scan, organize and do more with Scanella',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FreePlanCard(),
            const SizedBox(height: 16),
            const _ProPlanCard(),
          ],
        ),
      ),
    );
  }
}

class _FreePlanCard extends StatelessWidget {
  const _FreePlanCard();

  @override
  Widget build(BuildContext context) =>
      // The card colours are fixed light washes, so its text must stay dark
      // in dark mode too.
      Theme(
        data: AppTheme.light,
        child: Builder(builder: _card),
      );

  Widget _card(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF3FF), Color(0xFFF4F8FF)],
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
                    const _PlanBadge(
                      label: 'Free plan',
                      color: Color(0xFF2C7BE5),
                      wash: Color(0xFFD6E7FF),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Get started for free',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All the essential tools to scan, organize and manage your documents.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _PlanPapersArt(
                back: Color(0xFFB9D6FF),
                accent: Brand.docBlue,
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final perk in freePlanPerks) _PerkRow(perk: perk),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free limitations',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final limit in freePlanLimits) _LimitLine(limit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProPlanCard extends StatelessWidget {
  const _ProPlanCard();

  @override
  Widget build(BuildContext context) =>
      // The card colours are fixed light washes, so its text must stay dark
      // in dark mode too.
      Theme(
        data: AppTheme.light,
        child: Builder(builder: _card),
      );

  Widget _card(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
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
                    const Row(
                      children: [
                        ProMark(size: 28),
                        SizedBox(width: 8),
                        _PlanBadge(
                          label: 'Pro plan',
                          color: Color(0xFF187A55),
                          wash: Color(0xFFE4F3ED),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unlock the full power',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scan without limits and get advanced features for maximum productivity.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _PlanPapersArt(
                back: Color(0xFF7FC9A3),
                accent: Brand.accent,
                crowned: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final perk in proPlanPerks) _PerkRow(perk: perk),
          const SizedBox(height: 8),
          const ProCheckout(),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.label,
    required this.color,
    required this.wash,
  });

  final String label;
  final Color color;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.perk});

  final PlanPerk perk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: perk.wash,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(perk.icon, color: perk.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perk.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(perk.detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitLine extends StatelessWidget {
  const _LimitLine(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: Brand.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _PlanPapersArt extends StatelessWidget {
  const _PlanPapersArt({
    required this.back,
    required this.accent,
    this.crowned = false,
  });

  final Color back;
  final Color accent;
  final bool crowned;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 16,
            child: Transform.rotate(
              angle: 0.22,
              child: _sheet(fill: back, width: 46, height: 60),
            ),
          ),
          Positioned(
            right: 14,
            top: 4,
            child: Transform.rotate(
              angle: -0.08,
              child: _sheet(
                fill: Colors.white,
                width: 50,
                height: 66,
                framed: true,
              ),
            ),
          ),
          if (crowned)
            const Positioned(right: 8, bottom: 6, child: ProMark(size: 28)),
        ],
      ),
    );
  }

  Widget _sheet({
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
                width: width * 0.58,
                height: height * 0.58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accent, width: 2),
                ),
              ),
            )
          : null,
    );
  }
}
