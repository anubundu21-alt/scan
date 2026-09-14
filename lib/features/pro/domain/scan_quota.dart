import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Free-plan allowance on this device.
///
/// A new install gets [starterLimit] scans. After those are used, the
/// plan is [weeklyLimit] scans per week. The week starts when the last
/// free slot is used. After [resetAfter], the weekly count returns to
/// zero.
///
/// The count is the number of documents the user created (camera, photos,
/// PDF upload, ID card, Sign PDF upload). Merge, split, add-page, and
/// restore do not consume another slot. Pro does not consume slots, so a
/// leftover free allowance is still there if Pro lapses.
@immutable
class ScanQuota {
  const ScanQuota({
    this.used = 0,
    this.ready = false,
    this.periodStartedAt,
    this.starterDone = false,
  });

  /// One-time scans for a new install.
  static const starterLimit = 50;

  /// Free scans each week after the starter pack is used.
  static const weeklyLimit = 10;

  /// Weekly cap; kept so older call sites still compile.
  static const freeLimit = weeklyLimit;

  /// Scanning stops at the free-plan cap. Pro is unlimited.
  static const testingUnlockScans = false;

  static const resetAfter = Duration(days: 7);

  final int used;
  final bool ready;
  final DateTime? periodStartedAt;
  final bool starterDone;

  int get limit => starterDone ? weeklyLimit : starterLimit;

  bool get canCreate => used < limit;

  int get remaining => (limit - used).clamp(0, limit);

  DateTime? get resetsAt =>
      periodStartedAt == null ? null : periodStartedAt!.add(resetAfter);

  static String formatResetAt(DateTime at) {
    return DateFormat("EEEE, d MMMM y 'at' h:mm a").format(at.toLocal());
  }

  static String formatResetShort(DateTime at) {
    return DateFormat('d MMM y · h:mm a').format(at.toLocal());
  }

  /// Dialog title when the current free allowance is gone.
  String get usedUpTitle {
    if (!starterDone || used >= starterLimit) {
      return '$starterLimit free scans used';
    }
    return '$weeklyLimit free scans used';
  }

  String get usedUpMessage {
    final when = resetsAt;
    if (!starterDone || used >= starterLimit) {
      if (when == null) {
        return 'You get $weeklyLimit free scans each week after these '
            '$starterLimit. Scanella Pro lets you keep scanning now.';
      }
      return 'You get $weeklyLimit free scans on ${formatResetAt(when)}. '
          'Scanella Pro lets you keep scanning now.';
    }
    if (when == null) {
      return 'Your $weeklyLimit free scans reset next week. '
          'Scanella Pro lets you keep scanning now.';
    }
    return 'Your $weeklyLimit free scans reset on ${formatResetAt(when)}. '
        'Scanella Pro lets you keep scanning now.';
  }

  String get freePlanLabel {
    final when = resetsAt;
    if (remaining <= 0) {
      if (when == null) return 'All $limit free scans are used';
      return 'Resets ${formatResetShort(when)}';
    }
    return '$remaining of $limit free scans left';
  }
}

typedef QuotaNow = DateTime Function();

/// Where the used-count is stored. Tests inject [MemoryQuotaStore].
abstract class QuotaStore {
  Future<int> readUsed();
  Future<void> writeUsed(int used);
  Future<int> readPeriodStartMs();
  Future<void> writePeriodStartMs(int ms);
  Future<bool> readStarterDone();
  Future<void> writeStarterDone(bool done);
}

/// In-memory store for tests.
class MemoryQuotaStore implements QuotaStore {
  MemoryQuotaStore({
    int used = 0,
    int periodStartMs = 0,
    bool starterDone = false,
  }) : _used = used,
       _periodStartMs = periodStartMs,
       _starterDone = starterDone;

  int _used;
  int _periodStartMs;
  bool _starterDone;

  @override
  Future<int> readUsed() async => _used;

  @override
  Future<void> writeUsed(int used) async => _used = used;

  @override
  Future<int> readPeriodStartMs() async => _periodStartMs;

  @override
  Future<void> writePeriodStartMs(int ms) async => _periodStartMs = ms;

  @override
  Future<bool> readStarterDone() async => _starterDone;

  @override
  Future<void> writeStarterDone(bool done) async => _starterDone = done;
}

/// SharedPreferences plus the native Keychain / Android marker for the
/// used count. The week start and starter-pack flag live in prefs.
class DeviceQuotaStore implements QuotaStore {
  DeviceQuotaStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('scanella/quota');

  static const prefsKey = 'scanella.quota.used';
  static const periodKey = 'scanella.quota.period_start_ms';
  static const starterDoneKey = 'scanella.quota.starter_done';

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

  @override
  Future<bool> readStarterDone() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(starterDoneKey)) {
      return prefs.getBool(starterDoneKey) ?? false;
    }
    var native = 0;
    try {
      native = await _channel.invokeMethod<int>('readUsed') ?? 0;
    } catch (_) {}
    final existing =
        prefs.containsKey(prefsKey) ||
        prefs.containsKey(periodKey) ||
        native > 0;
    await prefs.setBool(starterDoneKey, existing);
    return existing;
  }

  @override
  Future<void> writeStarterDone(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(starterDoneKey, done);
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
      var starterDone = await _store.readStarterDone();
      var used = await _store.readUsed();
      if (!starterDone && used >= ScanQuota.starterLimit) {
        starterDone = true;
        await _store.writeStarterDone(true);
      }
      if (!starterDone) {
        used = used.clamp(0, ScanQuota.starterLimit);
      } else if (used > ScanQuota.starterLimit) {
        used = ScanQuota.weeklyLimit;
      } else {
        used = used.clamp(0, ScanQuota.starterLimit);
      }
      final startMs = await _store.readPeriodStartMs();
      final started = startMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(startMs)
          : null;
      state = ScanQuota(
        used: used,
        ready: true,
        periodStartedAt: started,
        starterDone: starterDone,
      );
      await _applyWindow();
    } catch (_) {
      state = const ScanQuota(used: 0, ready: true);
    }
  }

  Future<void> _applyWindow() async {
    final now = _now();
    var used = state.used;
    var started = state.periodStartedAt;
    var starterDone = state.starterDone;

    if (starterDone &&
        started != null &&
        !now.isBefore(started.add(ScanQuota.resetAfter))) {
      used = 0;
      started = null;
      await _store.writeUsed(0);
      await _store.writePeriodStartMs(0);
    }

    if (starterDone && used >= ScanQuota.weeklyLimit && started == null) {
      started = now;
      await _store.writePeriodStartMs(started.millisecondsSinceEpoch);
    }

    if (!starterDone && used >= ScanQuota.starterLimit && started == null) {
      starterDone = true;
      started = now;
      await _store.writeStarterDone(true);
      await _store.writePeriodStartMs(started.millisecondsSinceEpoch);
    }

    state = ScanQuota(
      used: used,
      ready: true,
      periodStartedAt: started,
      starterDone: starterDone,
    );
  }

  /// Call after a new library document is actually created.
  Future<void> recordCreated() async {
    await ensureLoaded();
    if (state.used >= state.limit) return;
    var next = state.used + 1;
    var starterDone = state.starterDone;
    var started = state.periodStartedAt;
    if (!starterDone && next >= ScanQuota.starterLimit) {
      starterDone = true;
      started = started ?? _now();
      await _store.writeStarterDone(true);
    } else if (starterDone && next >= ScanQuota.weeklyLimit) {
      started = started ?? _now();
    }
    state = ScanQuota(
      used: next,
      ready: true,
      periodStartedAt: started,
      starterDone: starterDone,
    );
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
