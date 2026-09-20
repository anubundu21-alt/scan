import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:scan2/features/pro/presentation/free_scans_used_screen.dart';
import 'package:scan2/features/pro/presentation/pro_paywall.dart';

/// Opens the paywall when the user is not on Pro. Returns whether they
/// may continue.
Future<bool> requirePro(BuildContext context, WidgetRef ref) async {
  if (ref.read(proProvider).isPro) return true;
  await showProPaywall(context);
  return ref.read(proProvider).isPro;
}

/// True when the user may create another document: they have Pro, or a
/// free-plan slot is left. At the limit they are shown what the free plan
/// still gives them and what Pro would add, and may close it either way —
/// a wall with no door is how an app gets deleted.
Future<bool> ensureFreeScanSlot(BuildContext context, WidgetRef ref) async {
  if (ScanQuota.testingUnlockScans) return true;
  if (ref.read(proProvider).isPro) return true;
  await ref.read(scanQuotaProvider.notifier).ensureLoaded();
  if (ref.read(scanQuotaProvider).canCreate) return true;
  if (!context.mounted) return false;
  return showFreeScansUsed(context, ref);
}

/// Counts one new document against the free allowance. Pro does not
/// consume a slot.
Future<void> recordNewScan(WidgetRef ref) async {
  if (ScanQuota.testingUnlockScans) return;
  if (ref.read(proProvider).isPro) return;
  await ref.read(scanQuotaProvider.notifier).recordCreated();
}
