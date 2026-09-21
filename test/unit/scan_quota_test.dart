import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('scanella/quota'), null);
  });

  test('a new install gets the starter pack before the period cap', () async {
    var now = DateTime(2026, 8, 30, 10, 15);
    final quota = ScanQuotaController(MemoryQuotaStore(), clock: () => now);
    await quota.ensureLoaded();

    expect(quota.state.limit, ScanQuota.starterLimit);
    expect(quota.state.remaining, ScanQuota.starterLimit);
    expect(
      quota.state.freePlanLabel,
      '${ScanQuota.starterLimit} of ${ScanQuota.starterLimit} free scans left',
    );

    for (var i = 0; i < ScanQuota.starterLimit; i++) {
      expect(quota.state.canCreate, isTrue, reason: 'starter ${i + 1}');
      await quota.recordCreated();
    }

    expect(quota.state.used, ScanQuota.starterLimit);
    expect(quota.state.starterDone, isTrue);
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.remaining, 0);
    final reset = DateTime(2026, 8, 30, 10, 15).add(ScanQuota.resetAfter);
    expect(quota.state.resetsAt, reset);
    expect(
      quota.state.usedUpTitle,
      '${ScanQuota.starterLimit} free scans used',
    );
    expect(
      quota.state.usedUpMessage,
      contains('You get ${ScanQuota.monthlyLimit} free scans on'),
    );
    expect(quota.state.usedUpMessage, isNot(contains('reinstall')));
    expect(
      quota.state.freePlanLabel,
      'Resets ${ScanQuota.formatResetShort(reset)}',
    );

    await quota.recordCreated();
    expect(quota.state.used, ScanQuota.starterLimit);
  });

  test('after the starter pack, the period cap resets each period', () async {
    var now = DateTime(2026, 8, 30, 10, 15);
    final store = MemoryQuotaStore();
    final quota = ScanQuotaController(store, clock: () => now);
    await quota.ensureLoaded();
    for (var i = 0; i < ScanQuota.starterLimit; i++) {
      await quota.recordCreated();
    }
    expect(quota.state.canCreate, isFalse);

    final firstReset = DateTime(2026, 8, 30, 10, 15).add(ScanQuota.resetAfter);
    now = firstReset.subtract(const Duration(minutes: 1));
    await quota.ensureLoaded();
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.used, ScanQuota.starterLimit);

    now = firstReset;
    await quota.ensureLoaded();
    expect(quota.state.used, 0);
    expect(quota.state.starterDone, isTrue);
    expect(quota.state.limit, ScanQuota.monthlyLimit);
    expect(quota.state.canCreate, isTrue);
    expect(quota.state.periodStartedAt, isNull);
    expect(
      quota.state.freePlanLabel,
      '${ScanQuota.monthlyLimit} of ${ScanQuota.monthlyLimit} free scans left',
    );

    for (var i = 0; i < ScanQuota.monthlyLimit; i++) {
      expect(quota.state.canCreate, isTrue, reason: 'period ${i + 1}');
      await quota.recordCreated();
    }
    expect(quota.state.canCreate, isFalse);
    expect(
      quota.state.usedUpTitle,
      '${ScanQuota.monthlyLimit} free scans used',
    );
    expect(
      quota.state.usedUpMessage,
      contains('Your ${ScanQuota.monthlyLimit} free scans reset on'),
    );
    final secondReset = firstReset.add(ScanQuota.resetAfter);
    expect(quota.state.resetsAt, secondReset);

    now = secondReset;
    await quota.ensureLoaded();
    expect(quota.state.used, 0);
    expect(quota.state.canCreate, isTrue);
    expect(quota.state.limit, ScanQuota.monthlyLimit);
  });

  test('the refill is stamped so the app can announce it once', () async {
    var now = DateTime(2026, 8, 30, 10, 15);
    final quota = ScanQuotaController(MemoryQuotaStore(), clock: () => now);
    await quota.ensureLoaded();

    // Nothing has refilled yet, so there is nothing to announce.
    expect(quota.state.refreshedAt, isNull);
    expect(quota.state.allowanceKey, 'starter');

    for (var i = 0; i < ScanQuota.starterLimit; i++) {
      await quota.recordCreated();
    }
    final firstReset = quota.state.resetsAt!;
    final starterBatch = quota.state.allowanceKey;

    now = firstReset;
    await quota.ensureLoaded();

    expect(quota.state.used, 0);
    expect(quota.state.refreshedAt, firstReset);
    // A different batch of scans, so a message shown for the last one does
    // not count as shown for this one.
    expect(quota.state.allowanceKey, isNot(starterBatch));
  });

  test('running low is flagged before the allowance is gone', () async {
    var now = DateTime(2026, 8, 30, 10, 15);
    final quota = ScanQuotaController(MemoryQuotaStore(), clock: () => now);
    await quota.ensureLoaded();

    final upToWarning = ScanQuota.starterLimit - ScanQuota.lowWarningAt;
    for (var i = 0; i < upToWarning; i++) {
      expect(quota.state.nearlyOut, isFalse, reason: 'scan ${i + 1}');
      await quota.recordCreated();
    }

    expect(quota.state.remaining, ScanQuota.lowWarningAt);
    expect(quota.state.nearlyOut, isTrue);

    // Out is not the same as nearly out: that screen is the used-up one.
    for (var i = 0; i < ScanQuota.lowWarningAt; i++) {
      await quota.recordCreated();
    }
    expect(quota.state.remaining, 0);
    expect(quota.state.nearlyOut, isFalse);
  });

  test('a used-up count with no period start begins the period now', () async {
    var now = DateTime(2026, 8, 30, 18, 40);
    final quota = ScanQuotaController(
      MemoryQuotaStore(used: ScanQuota.weeklyLimit, starterDone: true),
      clock: () => now,
    );
    await quota.ensureLoaded();
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.periodStartedAt, now);
    expect(
      quota.state.usedUpTitle,
      '${ScanQuota.monthlyLimit} free scans used',
    );
    expect(
      quota.state.usedUpMessage,
      contains(
        ScanQuota.formatResetAt(
          DateTime(2026, 8, 30, 18, 40).add(ScanQuota.resetAfter),
        ),
      ),
    );
  });

  test('native marker above the starter pack is treated as used-up', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('scanella/quota'), (
          call,
        ) async {
          if (call.method == 'readUsed') return 100;
          return null;
        });

    final store = DeviceQuotaStore();
    expect(await store.readUsed(), 100);
    expect(await store.readStarterDone(), isTrue);

    final quota = ScanQuotaController(store);
    await quota.ensureLoaded();
    expect(quota.state.starterDone, isTrue);
    expect(quota.state.used, ScanQuota.weeklyLimit);
    expect(quota.state.canCreate, isFalse);
  });

  test('the countdown names only the units that still matter', () {
    expect(
      ScanQuota.formatCountdown(
        const Duration(days: 14, hours: 3, minutes: 25),
      ),
      '14 days · 3 hours · 25 minutes',
    );
    expect(ScanQuota.formatCountdown(const Duration(days: 1)), '1 day');
    expect(
      ScanQuota.formatCountdown(const Duration(hours: 1, minutes: 1)),
      '1 hour · 1 minute',
    );
    expect(
      ScanQuota.formatCountdown(const Duration(minutes: 30)),
      '30 minutes',
    );
    expect(ScanQuota.formatCountdown(Duration.zero), 'any moment now');
    expect(
      ScanQuota.formatCountdown(const Duration(days: -2)),
      'any moment now',
    );
  });

  test('the reset date reads as a date', () {
    expect(
      ScanQuota.formatResetDate(DateTime(2026, 10, 20, 8, 28)),
      'Oct 20, 2026',
    );
  });

  test('drawer label counts remaining starter scans', () async {
    final quota = ScanQuotaController(MemoryQuotaStore(used: 3));
    await quota.ensureLoaded();
    expect(quota.state.remaining, ScanQuota.starterLimit - 3);
    expect(quota.state.limit, ScanQuota.starterLimit);
    expect(
      quota.state.freePlanLabel,
      '${ScanQuota.starterLimit - 3} of ${ScanQuota.starterLimit} '
      'free scans left',
    );
  });

  test('existing installs skip the starter pack', () async {
    SharedPreferences.setMockInitialValues({
      DeviceQuotaStore.prefsKey: 2,
    });
    final store = DeviceQuotaStore();
    expect(await store.readStarterDone(), isTrue);

    final quota = ScanQuotaController(store);
    await quota.ensureLoaded();
    expect(quota.state.starterDone, isTrue);
    expect(quota.state.limit, ScanQuota.monthlyLimit);
    expect(quota.state.remaining, ScanQuota.monthlyLimit - 2);
    expect(
      quota.state.freePlanLabel,
      '${ScanQuota.monthlyLimit - 2} of ${ScanQuota.monthlyLimit} '
      'free scans left',
    );
  });

  test('setUsedForTesting jumps to a spent starter pack', () async {
    final quota = ScanQuotaController(MemoryQuotaStore());
    await quota.ensureLoaded();
    await quota.setUsedForTesting(ScanQuota.starterLimit);
    expect(quota.state.used, ScanQuota.starterLimit);
    expect(quota.state.starterDone, isTrue);
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.remaining, 0);
  });

  test('setUsedForTesting can leave two scans', () async {
    final quota = ScanQuotaController(MemoryQuotaStore());
    await quota.ensureLoaded();
    await quota.setUsedForTesting(ScanQuota.starterLimit - 2);
    expect(quota.state.used, ScanQuota.starterLimit - 2);
    expect(quota.state.remaining, 2);
    expect(quota.state.nearlyOut, isTrue);
    expect(quota.state.canCreate, isTrue);
  });

  test('setUsedForTesting can give the allowance back', () async {
    final store = MemoryQuotaStore(used: ScanQuota.starterLimit, starterDone: true);
    final quota = ScanQuotaController(store);
    await quota.ensureLoaded();
    await quota.setUsedForTesting(0);
    expect(quota.state.used, 0);
    expect(quota.state.canCreate, isTrue);
  });

  test('resetForNewInstall restores the starter pack', () async {
    final store = MemoryQuotaStore(
      used: ScanQuota.starterLimit,
      starterDone: true,
      periodStartMs: DateTime(2026, 9, 1).millisecondsSinceEpoch,
    );
    final quota = ScanQuotaController(store);
    await quota.ensureLoaded();
    await quota.resetForNewInstall();
    expect(quota.state.used, 0);
    expect(quota.state.starterDone, isFalse);
    expect(quota.state.limit, ScanQuota.starterLimit);
    expect(quota.state.canCreate, isTrue);
    expect(quota.state.periodStartedAt, isNull);
  });
}
