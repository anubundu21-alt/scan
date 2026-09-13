import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/features/pro/domain/pro_features.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/presentation/pro_checkout.dart';
import 'package:scan2/features/pro/presentation/pro_paywall.dart';

/// Drawer page: everything Scanella can do, split into free and Pro.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Complete features')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What you can do in Scanella, on this device.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Text('Free features', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final feature in freeFeatureLines)
              FeatureBullet(feature: feature),
            const SizedBox(height: 16),
            Row(
              children: [
                const ProMark(size: 28),
                const SizedBox(width: 10),
                Text('Pro features', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Pay with your Apple ID. Cancel any time from iOS Settings.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            const ProCheckout(),
            const SizedBox(height: 20),
            Text('Included with Pro', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final feature in proFeatureLines)
              FeatureBullet(feature: feature),
          ],
        ),
      ),
    );
  }
}
