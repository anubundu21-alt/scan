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

  test('a new install gets 50 starter scans before the weekly 10', () async {
    var now = DateTime(2026, 8, 30, 10, 15);
    final quota = ScanQuotaController(MemoryQuotaStore(), clock: () => now);
    await quota.ensureLoaded();

    expect(quota.state.limit, ScanQuota.starterLimit);
    expect(quota.state.remaining, 50);
    expect(quota.state.freePlanLabel, '50 of 50 free scans left');

    for (var i = 0; i < ScanQuota.starterLimit; i++) {
      expect(quota.state.canCreate, isTrue, reason: 'starter ${i + 1}');
      await quota.recordCreated();
    }

    expect(quota.state.used, ScanQuota.starterLimit);
    expect(quota.state.starterDone, isTrue);
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.remaining, 0);
    expect(quota.state.resetsAt, DateTime(2026, 9, 6, 10, 15));
    expect(quota.state.usedUpTitle, '50 free scans used');
    expect(
      quota.state.usedUpMessage,
      contains('You get ${ScanQuota.weeklyLimit} free scans on'),
    );
    expect(quota.state.usedUpMessage, isNot(contains('reinstall')));
    expect(
      quota.state.freePlanLabel,
      'Resets ${ScanQuota.formatResetShort(DateTime(2026, 9, 6, 10, 15))}',
    );

    await quota.recordCreated();
    expect(quota.state.used, ScanQuota.starterLimit);
  });

  test('after the starter pack, 10 free scans reset each week', () async {
    var now = DateTime(2026, 8, 30, 10, 15);
    final store = MemoryQuotaStore();
    final quota = ScanQuotaController(store, clock: () => now);
    await quota.ensureLoaded();
    for (var i = 0; i < ScanQuota.starterLimit; i++) {
      await quota.recordCreated();
    }
    expect(quota.state.canCreate, isFalse);

    now = DateTime(2026, 9, 6, 10, 14);
    await quota.ensureLoaded();
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.used, ScanQuota.starterLimit);

    now = DateTime(2026, 9, 6, 10, 15);
    await quota.ensureLoaded();
    expect(quota.state.used, 0);
    expect(quota.state.starterDone, isTrue);
    expect(quota.state.limit, ScanQuota.weeklyLimit);
    expect(quota.state.canCreate, isTrue);
    expect(quota.state.periodStartedAt, isNull);
    expect(quota.state.freePlanLabel, '10 of 10 free scans left');

    for (var i = 0; i < ScanQuota.weeklyLimit; i++) {
      expect(quota.state.canCreate, isTrue, reason: 'weekly ${i + 1}');
      await quota.recordCreated();
    }
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.usedUpTitle, '10 free scans used');
    expect(
      quota.state.usedUpMessage,
      contains('Your ${ScanQuota.weeklyLimit} free scans reset on'),
    );
    expect(quota.state.resetsAt, DateTime(2026, 9, 13, 10, 15));

    now = DateTime(2026, 9, 13, 10, 15);
    await quota.ensureLoaded();
    expect(quota.state.used, 0);
    expect(quota.state.canCreate, isTrue);
    expect(quota.state.limit, ScanQuota.weeklyLimit);
  });

  test('a used-up weekly count without a week start begins the week now', () async {
    var now = DateTime(2026, 8, 30, 18, 40);
    final quota = ScanQuotaController(
      MemoryQuotaStore(used: ScanQuota.weeklyLimit, starterDone: true),
      clock: () => now,
    );
    await quota.ensureLoaded();
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.periodStartedAt, now);
    expect(quota.state.usedUpTitle, '10 free scans used');
    expect(
      quota.state.usedUpMessage,
      contains(ScanQuota.formatResetAt(DateTime(2026, 9, 6, 18, 40))),
    );
  });

  test('native marker above the starter pack is treated as weekly used-up', () async {
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

  test('drawer label counts remaining starter scans', () async {
    final quota = ScanQuotaController(MemoryQuotaStore(used: 3));
    await quota.ensureLoaded();
    expect(quota.state.remaining, 47);
    expect(quota.state.limit, ScanQuota.starterLimit);
    expect(quota.state.freePlanLabel, '47 of 50 free scans left');
  });

  test('existing installs skip the 50-scan starter pack', () async {
    SharedPreferences.setMockInitialValues({
      DeviceQuotaStore.prefsKey: 2,
    });
    final store = DeviceQuotaStore();
    expect(await store.readStarterDone(), isTrue);

    final quota = ScanQuotaController(store);
    await quota.ensureLoaded();
    expect(quota.state.starterDone, isTrue);
    expect(quota.state.limit, ScanQuota.weeklyLimit);
    expect(quota.state.remaining, 8);
    expect(quota.state.freePlanLabel, '8 of 10 free scans left');
  });
}
