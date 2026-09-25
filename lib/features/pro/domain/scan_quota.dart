import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Free-plan allowance on this device.
///
/// A new install gets [starterLimit] scans. After those are used, the
/// plan is [monthlyLimit] scans per period. The period starts when the last
/// free slot is used. After [resetAfter], the count returns to zero.
/// Unused scans do not carry over.
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
    this.refreshedAt,
  });

  /// One-time scans for a new install.
  static const starterLimit = 10;

  /// Free scans each period after the starter pack is used.
  static const monthlyLimit = 10;

  /// Older names for the same cap, kept so existing call sites compile.
  static const weeklyLimit = monthlyLimit;
  static const freeLimit = monthlyLimit;

  /// Days in a free period, shown to the customer as "every 30 days".
  static const resetDays = 30;

  /// How few scans may be left before the app says something about it.
  static const lowWarningAt = 2;

  /// Scanning stops at the free-plan cap. Pro is unlimited.
  static const testingUnlockScans = false;

  static const resetAfter = Duration(days: resetDays);

  final int used;
  final bool ready;
  final DateTime? periodStartedAt;
  final bool starterDone;

  /// When the allowance last went back to full, so the app can say so once.
  final DateTime? refreshedAt;

  int get limit => starterDone ? monthlyLimit : starterLimit;

  bool get canCreate => used < limit;

  int get remaining => (limit - used).clamp(0, limit);

  DateTime? get resetsAt =>
      periodStartedAt == null ? null : periodStartedAt!.add(resetAfter);

  /// Running low, but not out yet.
  bool get nearlyOut => remaining > 0 && remaining <= lowWarningAt;

  /// Names the batch of scans currently being used up.
  ///
  /// It changes when the allowance refills, which is how a message that
  /// should appear once per batch knows it is looking at a new one.
  String get allowanceKey {
    if (!starterDone) return 'starter';
    return 'period:${refreshedAt?.millisecondsSinceEpoch ?? 0}';
  }

  static String formatResetAt(DateTime at) {
    return DateFormat("EEEE, d MMMM y 'at' h:mm a").format(at.toLocal());
  }

  static String formatResetShort(DateTime at) {
    return DateFormat('d MMM y · h:mm a').format(at.toLocal());
  }

  /// Just the day the allowance comes back: `Oct 20, 2026`.
  static String formatResetDate(DateTime at) {
    return DateFormat('MMM d, y').format(at.toLocal());
  }

  /// How long that is from now, in the units that still matter. Under a
  /// minute reads as "any moment now" rather than a row of zeroes, and a
  /// period that has already elapsed reads the same way.
  static String formatCountdown(Duration left) {
    if (left.inMinutes <= 0) return 'any moment now';
    final days = left.inDays;
    final hours = left.inHours % 24;
    final minutes = left.inMinutes % 60;
    final parts = <String>[
      if (days > 0) '$days ${days == 1 ? 'day' : 'days'}',
      if (hours > 0) '$hours ${hours == 1 ? 'hour' : 'hours'}',
      if (minutes > 0) '$minutes ${minutes == 1 ? 'minute' : 'minutes'}',
    ];
    return parts.join(' · ');
  }

  /// How many scans the allowance that just ran out actually held.
  ///
  /// [limit] is forward-looking: the moment the tenth starter scan lands,
  /// [starterDone] flips and it drops to [monthlyLimit]. Telling someone who
  /// has just used ten scans that they used five reads like a bug, so the
  /// screens that report a spent allowance use this instead.
  int get usedUpLimit {
    if (!starterDone || used >= starterLimit) return starterLimit;
    return monthlyLimit;
  }

  /// Dialog title when the current free allowance is gone.
  String get usedUpTitle => '$usedUpLimit free scans used';

  String get usedUpMessage {
    final when = resetsAt;
    if (!starterDone || used >= starterLimit) {
      if (when == null) {
        return 'You get $monthlyLimit free scans every $resetDays days after '
            'these $starterLimit. Scanella Pro lets you keep scanning now.';
      }
      return 'You get $monthlyLimit free scans on ${formatResetAt(when)}. '
          'Scanella Pro lets you keep scanning now.';
    }
    if (when == null) {
      return 'Your $monthlyLimit free scans reset in $resetDays days. '
          'Scanella Pro lets you keep scanning now.';
    }
    return 'Your $monthlyLimit free scans reset on ${formatResetAt(when)}. '
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
  Future<int> readRefreshedAtMs();
  Future<void> writeRefreshedAtMs(int ms);
}

/// In-memory store for tests.
class MemoryQuotaStore implements QuotaStore {
  MemoryQuotaStore({
    int used = 0,
    int periodStartMs = 0,
    bool starterDone = false,
    int refreshedAtMs = 0,
  }) : _used = used,
       _periodStartMs = periodStartMs,
       _starterDone = starterDone,
       _refreshedAtMs = refreshedAtMs;

  int _used;
  int _periodStartMs;
  bool _starterDone;
  int _refreshedAtMs;

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

  @override
  Future<int> readRefreshedAtMs() async => _refreshedAtMs;

  @override
  Future<void> writeRefreshedAtMs(int ms) async => _refreshedAtMs = ms;
}

/// SharedPreferences plus the native Keychain / Android marker for the
/// used count. The week start and starter-pack flag live in prefs.
class DeviceQuotaStore implements QuotaStore {
  DeviceQuotaStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('scanella/quota');

  static const prefsKey = 'scanella.quota.used';
  static const periodKey = 'scanella.quota.period_start_ms';
  static const starterDoneKey = 'scanella.quota.starter_done';
  static const refreshedAtKey = 'scanella.quota.refreshed_at_ms';

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

  @override
  Future<int> readRefreshedAtMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(refreshedAtKey) ?? 0;
  }

  @override
  Future<void> writeRefreshedAtMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(refreshedAtKey, ms);
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
      final refreshedMs = await _store.readRefreshedAtMs();
      state = ScanQuota(
        used: used,
        ready: true,
        periodStartedAt: started,
        starterDone: starterDone,
        refreshedAt: refreshedMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(refreshedMs)
            : null,
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
    var refreshedAt = state.refreshedAt;

    if (starterDone &&
        started != null &&
        !now.isBefore(started.add(ScanQuota.resetAfter))) {
      used = 0;
      started = null;
      // Stamped so the app can tell the customer their scans are back,
      // once, rather than every time this runs.
      refreshedAt = now;
      await _store.writeUsed(0);
      await _store.writePeriodStartMs(0);
      await _store.writeRefreshedAtMs(now.millisecondsSinceEpoch);
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
      refreshedAt: refreshedAt,
    );
  }

  /// Forces the used count, for the testing tools only.
  ///
  /// Nothing in the app calls this: it exists so a tester can reach the
  /// paywall or the running-low screen without making ten documents by
  /// hand. It goes through the same store as a real scan, so the Keychain
  /// copy moves with it and a reinstall behaves as it would for a customer.
  Future<void> setUsedForTesting(int used) async {
    await ensureLoaded();
    final capped = used.clamp(0, ScanQuota.starterLimit);
    await _store.writeUsed(capped);
    await _store.writePeriodStartMs(0);
    state = ScanQuota(
      used: capped,
      ready: true,
      starterDone: state.starterDone,
      refreshedAt: state.refreshedAt,
    );
    await _applyWindow();
  }

  /// Back to a brand-new install's allowance, for the testing tools only.
  Future<void> resetForNewInstall() async {
    await _store.writeUsed(0);
    await _store.writePeriodStartMs(0);
    await _store.writeStarterDone(false);
    await _store.writeRefreshedAtMs(0);
    state = const ScanQuota(used: 0, ready: true);
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
      refreshedAt: state.refreshedAt,
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
