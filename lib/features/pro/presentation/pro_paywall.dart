import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                  ProCheckout(
                    onSubscribed: () {
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('Included with Pro', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  for (final feature in proFeatureLines)
                    FeatureBullet(feature: feature),
                ],
              ),
            ),
          ],
        ),
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
