import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:scan2/features/pro/presentation/pro_paywall.dart';

/// Opens the paywall when the user is not on Pro. Returns whether they
/// may continue.
Future<bool> requirePro(BuildContext context, WidgetRef ref) async {
  if (ref.read(proProvider).isPro) return true;
  await showProPaywall(context);
  return ref.read(proProvider).isPro;
}

/// Explains that the free allowance is gone and when it comes back.
/// The user must continue to Scanella Pro — they cannot dismiss this.
Future<bool> showFreeScansUsedDialog(
  BuildContext context,
  ScanQuota quota,
) async {
  final goPro = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(ScanQuota.usedUpTitle),
          content: Text(quota.usedUpMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('See Scanella Pro'),
            ),
          ],
        ),
      );
    },
  );
  return goPro == true;
}

/// True when the user may create another document: they have Pro, or a
/// free-plan slot is left. At the limit, they must see Pro.
Future<bool> ensureFreeScanSlot(BuildContext context, WidgetRef ref) async {
  if (ScanQuota.testingUnlockScans) return true;
  if (ref.read(proProvider).isPro) return true;
  await ref.read(scanQuotaProvider.notifier).ensureLoaded();
  if (ref.read(scanQuotaProvider).canCreate) return true;
  if (!context.mounted) return false;
  final goPro = await showFreeScansUsedDialog(
    context,
    ref.read(scanQuotaProvider),
  );
  if (!goPro || !context.mounted) return false;
  await showProPaywall(context, requireChoice: true);
  return ref.read(proProvider).isPro;
}

/// Counts one new document against the free allowance. Pro does not
/// consume a slot.
Future<void> recordNewScan(WidgetRef ref) async {
  if (ScanQuota.testingUnlockScans) return;
  if (ref.read(proProvider).isPro) return;
  await ref.read(scanQuotaProvider.notifier).recordCreated();
}
