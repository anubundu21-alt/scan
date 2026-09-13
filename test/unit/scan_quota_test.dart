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

  test('free-plan slots are allowed and the next one is not', () async {
    var now = DateTime(2026, 8, 30, 10, 15);
    final quota = ScanQuotaController(MemoryQuotaStore(), clock: () => now);
    await quota.ensureLoaded();

    for (var i = 0; i < ScanQuota.freeLimit; i++) {
      expect(quota.state.canCreate, isTrue, reason: 'slot ${i + 1}');
      await quota.recordCreated();
    }

    expect(quota.state.used, ScanQuota.freeLimit);
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.remaining, 0);
    expect(quota.state.resetsAt, DateTime(2026, 9, 6, 10, 15));
    expect(
      quota.state.usedUpMessage,
      contains('Your ${ScanQuota.freeLimit} free scans reset on'),
    );
    expect(quota.state.usedUpMessage, isNot(contains('reinstall')));
    expect(
      quota.state.freePlanLabel,
      'Resets ${ScanQuota.formatResetShort(DateTime(2026, 9, 6, 10, 15))}',
    );
    expect(ScanQuota.usedUpTitle, '${ScanQuota.freeLimit} free scans used');

    await quota.recordCreated();
    expect(quota.state.used, ScanQuota.freeLimit);
  });

  test('used-up free scans reset after a week', () async {
    var now = DateTime(2026, 8, 30, 10, 15);
    final store = MemoryQuotaStore();
    final quota = ScanQuotaController(store, clock: () => now);
    await quota.ensureLoaded();
    for (var i = 0; i < ScanQuota.freeLimit; i++) {
      await quota.recordCreated();
    }
    expect(quota.state.canCreate, isFalse);

    now = DateTime(2026, 9, 6, 10, 14);
    await quota.ensureLoaded();
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.used, ScanQuota.freeLimit);

    now = DateTime(2026, 9, 6, 10, 15);
    await quota.ensureLoaded();
    expect(quota.state.used, 0);
    expect(quota.state.canCreate, isTrue);
    expect(quota.state.periodStartedAt, isNull);
  });

  test('a used-up count without a week start begins the week now', () async {
    var now = DateTime(2026, 8, 30, 18, 40);
    final quota = ScanQuotaController(
      MemoryQuotaStore(used: ScanQuota.freeLimit),
      clock: () => now,
    );
    await quota.ensureLoaded();
    expect(quota.state.canCreate, isFalse);
    expect(quota.state.periodStartedAt, now);
    expect(
      quota.state.usedUpMessage,
      contains(ScanQuota.formatResetAt(DateTime(2026, 9, 6, 18, 40))),
    );
  });

  test('native marker is clamped to the free limit', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('scanella/quota'), (
          call,
        ) async {
          if (call.method == 'readUsed') return 100;
          return null;
        });

    final store = DeviceQuotaStore();
    expect(await store.readUsed(), 100);

    final quota = ScanQuotaController(store);
    await quota.ensureLoaded();
    expect(quota.state.used, ScanQuota.freeLimit);
    expect(quota.state.canCreate, isFalse);
  });

  test('drawer label counts remaining free scans', () async {
    final used = (ScanQuota.freeLimit / 3).floor().clamp(
      1,
      ScanQuota.freeLimit - 1,
    );
    final quota = ScanQuotaController(MemoryQuotaStore(used: used));
    await quota.ensureLoaded();
    expect(quota.state.remaining, ScanQuota.freeLimit - used);
    expect(
      quota.state.freePlanLabel,
      '${ScanQuota.freeLimit - used} of ${ScanQuota.freeLimit} free scans left',
    );
  });
}
