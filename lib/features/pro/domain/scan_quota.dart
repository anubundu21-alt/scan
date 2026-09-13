import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Free-plan allowance: [freeLimit] new documents, then a week until
/// the count starts over.
///
/// The count is the number of documents the user created (camera, photos,
/// PDF upload, ID card, Sign PDF upload). Merge, split, add-page, and
/// restore do not consume another slot. Pro does not consume slots, so a
/// leftover free allowance is still there if Pro lapses.
///
/// The week starts when the last free slot is used. After [resetAfter],
/// the count returns to zero.
@immutable
class ScanQuota {
  const ScanQuota({this.used = 0, this.ready = false, this.periodStartedAt});

  /// Free scans per week on this device. Pro is unlimited.
  static const freeLimit = 10;

  /// Temporary TestFlight switch: scanning does not stop for Pro.
  static const testingUnlockScans = true;

  static const resetAfter = Duration(days: 7);

  final int used;
  final bool ready;
  final DateTime? periodStartedAt;

  bool get canCreate => used < freeLimit;

  int get remaining => (freeLimit - used).clamp(0, freeLimit);

  DateTime? get resetsAt =>
      periodStartedAt == null ? null : periodStartedAt!.add(resetAfter);

  static String formatResetAt(DateTime at) {
    return DateFormat("EEEE, d MMMM y 'at' h:mm a").format(at.toLocal());
  }

  static String formatResetShort(DateTime at) {
    return DateFormat('d MMM y · h:mm a').format(at.toLocal());
  }

  /// Dialog title when the free allowance is gone.
  static String get usedUpTitle => '$freeLimit free scans used';

  String get usedUpMessage {
    final when = resetsAt;
    if (when == null) {
      return 'Your $freeLimit free scans reset next week. '
          'Scanella Pro lets you keep scanning now.';
    }
    return 'Your $freeLimit free scans reset on ${formatResetAt(when)}. '
        'Scanella Pro lets you keep scanning now.';
  }

  String get freePlanLabel {
    final when = resetsAt;
    if (remaining <= 0) {
      if (when == null) return 'All $freeLimit free scans are used';
      return 'Resets ${formatResetShort(when)}';
    }
    return '$remaining of $freeLimit free scans left';
  }
}

typedef QuotaNow = DateTime Function();

/// Where the used-count is stored. Tests inject [MemoryQuotaStore].
abstract class QuotaStore {
  Future<int> readUsed();
  Future<void> writeUsed(int used);
  Future<int> readPeriodStartMs();
  Future<void> writePeriodStartMs(int ms);
}

/// In-memory store for tests.
class MemoryQuotaStore implements QuotaStore {
  MemoryQuotaStore({int used = 0, int periodStartMs = 0})
    : _used = used,
      _periodStartMs = periodStartMs;

  int _used;
  int _periodStartMs;

  @override
  Future<int> readUsed() async => _used;

  @override
  Future<void> writeUsed(int used) async => _used = used;

  @override
  Future<int> readPeriodStartMs() async => _periodStartMs;

  @override
  Future<void> writePeriodStartMs(int ms) async => _periodStartMs = ms;
}

/// SharedPreferences plus the native Keychain / Android marker for the
/// used count. The week start lives in prefs.
class DeviceQuotaStore implements QuotaStore {
  DeviceQuotaStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('scanella/quota');

  static const prefsKey = 'scanella.quota.used';
  static const periodKey = 'scanella.quota.period_start_ms';

  final MethodChannel _channel;

  @override
  Future<int> readUsed() async {
    var native = 0;
    try {
      native = await _channel.invokeMethod<int>('readUsed') ?? 0;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getInt(prefsKey) ?? 0;
    final used = native > local ? native : local;
    if (used != local) await prefs.setInt(prefsKey, used);
    if (used != native) {
      try {
        await _channel.invokeMethod<void>('writeUsed', used);
      } catch (_) {}
    }
    return used;
  }

  @override
  Future<void> writeUsed(int used) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsKey, used);
    try {
      await _channel.invokeMethod<void>('writeUsed', used);
    } catch (_) {}
  }

  @override
  Future<int> readPeriodStartMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(periodKey) ?? 0;
  }

  @override
  Future<void> writePeriodStartMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(periodKey, ms);
  }
}

class ScanQuotaController extends StateNotifier<ScanQuota> {
  ScanQuotaController(this._store, {QuotaNow? clock})
    : _now = clock ?? DateTime.now,
      super(const ScanQuota()) {
    load();
  }

  final QuotaStore _store;
  final QuotaNow _now;
  Future<void>? _loading;

  Future<void> load() {
    return _loading ??= _load();
  }

  Future<void> ensureLoaded() async {
    await load();
    await _applyWindow();
  }

  Future<void> _load() async {
    try {
      final used = (await _store.readUsed()).clamp(0, ScanQuota.freeLimit);
      final startMs = await _store.readPeriodStartMs();
      final started = startMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(startMs)
          : null;
      state = ScanQuota(used: used, ready: true, periodStartedAt: started);
      await _applyWindow();
    } catch (_) {
      state = const ScanQuota(used: 0, ready: true);
    }
  }

  Future<void> _applyWindow() async {
    final now = _now();
    var used = state.used;
    var started = state.periodStartedAt;

    if (started != null && !now.isBefore(started.add(ScanQuota.resetAfter))) {
      used = 0;
      started = null;
      await _store.writeUsed(0);
      await _store.writePeriodStartMs(0);
    }

    if (used >= ScanQuota.freeLimit && started == null) {
      started = now;
      await _store.writePeriodStartMs(started.millisecondsSinceEpoch);
    }

    state = ScanQuota(used: used, ready: true, periodStartedAt: started);
  }

  /// Call after a new library document is actually created.
  Future<void> recordCreated() async {
    await ensureLoaded();
    if (state.used >= ScanQuota.freeLimit) return;
    final next = state.used + 1;
    final started = next >= ScanQuota.freeLimit
        ? (state.periodStartedAt ?? _now())
        : state.periodStartedAt;
    state = ScanQuota(used: next, ready: true, periodStartedAt: started);
    await _store.writeUsed(next);
    if (started != null) {
      await _store.writePeriodStartMs(started.millisecondsSinceEpoch);
    }
  }
}

final quotaStoreProvider = Provider<QuotaStore>((ref) {
  if (kIsWeb) return MemoryQuotaStore();
  return DeviceQuotaStore();
});

final scanQuotaProvider = StateNotifierProvider<ScanQuotaController, ScanQuota>(
  (ref) {
    return ScanQuotaController(ref.watch(quotaStoreProvider));
  },
);
