import 'package:flutter/material.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';

/// What the free plan gives, shown once after the intro pages.
///
/// Every number here comes from [ScanQuota], so the screen cannot promise an
/// allowance the app does not actually grant.
class FreeAccessScreen extends StatelessWidget {
  const FreeAccessScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: Brand.canvas,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Brand.ink),
                  onPressed: onContinue,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  children: [
                    const _CalendarBadge(),
                    const SizedBox(height: 14),
                    const _Headline(),
                    const SizedBox(height: 8),
                    const Text(
                      'Scanella gives you free scans and free access to PDF '
                      'tools, so you can get more done, always.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: Brand.grey,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AccessCard(
                      icon: Icons.card_giftcard_rounded,
                      wash: const Color(0xFFE9F7F0),
                      tint: Brand.accent,
                      title:
                          'Get ${ScanQuota.starterLimit} free scans when you '
                          'start',
                      detail: 'No payment required',
                    ),
                    _AccessCard(
                      icon: Icons.autorenew_rounded,
                      wash: const Color(0xFFEAF2FD),
                      tint: const Color(0xFF2F6FED),
                      title:
                          'After ${ScanQuota.starterLimit} scans, get '
                          '${ScanQuota.monthlyLimit} free scans every '
                          '${ScanQuota.resetDays} days',
                      detail: 'Unused scans don’t carry over',
                    ),
                    const _AccessCard(
                      icon: Icons.picture_as_pdf_rounded,
                      wash: Color(0xFFF2EDFD),
                      tint: Color(0xFF7C5CFF),
                      title: 'PDF tools are always free',
                      detail:
                          'Convert, merge, compress, split, edit and more — '
                          'no scan limit.',
                    ),
                    const _AccessCard(
                      icon: Icons.workspace_premium_rounded,
                      wash: Color(0xFFE9F7F0),
                      tint: Brand.accent,
                      title: 'Upgrade to Pro anytime',
                      detail:
                          'Get unlimited scans and all premium features.',
                      last: true,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: BrandButton(
                  label: 'Got it',
                  onPressed: onContinue,
                  showArrow: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: Brand.font,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.6,
      color: Brand.ink,
    );
    return const Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: 'How '),
          TextSpan(text: 'Free Access', style: TextStyle(color: Brand.accent)),
          TextSpan(text: ' Works?'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// The calendar mark, on its own soft disc.
class _CalendarBadge extends StatelessWidget {
  const _CalendarBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 92,
        height: 92,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE9F7F0),
        ),
        child: const Icon(
          Icons.calendar_month_rounded,
          size: 48,
          color: Brand.accent,
        ),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.icon,
    required this.wash,
    required this.tint,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final IconData icon;
  final Color wash;
  final Color tint;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: wash,
          borderRadius: BorderRadius.circular(Brand.radiusCard),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        color: Brand.grey,
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
