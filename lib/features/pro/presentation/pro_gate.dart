import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:scan2/features/pro/presentation/free_scans_refreshed_screen.dart';
import 'package:scan2/features/pro/presentation/free_scans_used_screen.dart';
import 'package:scan2/features/pro/presentation/low_scans_screen.dart';
import 'package:scan2/features/pro/presentation/pro_paywall.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// What the app has already said about the current batch of free scans.
const _refreshSeenKey = 'scanella.quota.refresh_seen_ms';
const _lowSeenKey = 'scanella.quota.low_seen_batch';

/// Shows the news about the free allowance, if there is any.
///
/// Two things are worth interrupting for: the scans coming back after the
/// reset period, and the allowance running low. Each is shown at most once
/// per batch of scans, and never both at once — a refill is not the moment
/// to warn about running out.
///
/// These markers live in SharedPreferences on purpose. Losing them to an
/// uninstall only means a returning customer sees a friendly message one
/// more time, which is harmless; the counts that decide what they may
/// actually do are stored where an uninstall cannot reach.
Future<void> showQuotaNotices(BuildContext context, WidgetRef ref) async {
  if (ScanQuota.testingUnlockScans) return;
  if (ref.read(proProvider).isPro) return;
  await ref.read(scanQuotaProvider.notifier).ensureLoaded();
  final quota = ref.read(scanQuotaProvider);
  if (!quota.ready) return;

  final prefs = await SharedPreferences.getInstance();

  // Only worth saying while the batch is still untouched. Someone who has
  // already scanned since the refill does not need to be told about it.
  final refreshedAt = quota.refreshedAt;
  if (refreshedAt != null && quota.used == 0) {
    final stamp = refreshedAt.millisecondsSinceEpoch;
    if ((prefs.getInt(_refreshSeenKey) ?? 0) != stamp) {
      await prefs.setInt(_refreshSeenKey, stamp);
      if (!context.mounted) return;
      await showFreeScansRefreshed(context, ref);
      return;
    }
  }

  if (!quota.nearlyOut) return;
  if (prefs.getString(_lowSeenKey) == quota.allowanceKey) return;
  await prefs.setString(_lowSeenKey, quota.allowanceKey);
  if (!context.mounted) return;
  await showLowScansLeft(context, ref);
}
