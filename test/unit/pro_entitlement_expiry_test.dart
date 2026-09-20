import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/pro/data/iap_gateway.dart';
import 'package:scan2/features/pro/data/storekit_purchase.dart';
import 'package:scan2/features/pro/domain/pro_purchase.dart';

/// Stands in for the Keychain, which is what the native side really writes.
/// Its contents deliberately outlive a "reinstall" in these tests, because
/// that is exactly what the Keychain does on a real iPhone.
class FakeKeychain {
  bool entitled = false;
  DateTime? until;
  DateTime? basis;
  bool trialUsed = false;

  /// True on iOS 15 and above, where StoreKit 2 answers silently. False
  /// stands in for iOS 13 and 14, which have no such API.
  bool storeKit2 = false;

  /// What StoreKit 2 would say, when it is available.
  bool liveEntitlement = false;

  int writes = 0;

  MethodChannel install(String name) {
    final channel = MethodChannel(name);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'currentEntitlement':
              if (!storeKit2) return null;
              return liveEntitlement;
            case 'trialConsumed':
              return trialUsed;
            case 'markTrialUsed':
              trialUsed = true;
              return null;
            case 'readPro':
              // The native readPro throws away a stamp that has passed.
              if (!entitled) return false;
              final at = until;
              if (at != null && !at.isAfter(DateTime.now())) {
                entitled = false;
                until = null;
                return false;
              }
              return true;
            case 'readProStamp':
              return <String, Object?>{
                'untilMs': until?.millisecondsSinceEpoch,
                'basisMs': basis?.millisecondsSinceEpoch,
              };
            case 'writePro':
              writes++;
              final args = call.arguments;
              if (args is bool) {
                entitled = args;
                if (!args) {
                  until = null;
                  basis = null;
                }
                return null;
              }
              final map = args as Map;
              entitled = map['entitled'] as bool;
              if (!entitled) {
                until = null;
                basis = null;
                return null;
              }
              final ms = map['untilMs'] as int?;
              if (ms == null) return null;
              until = DateTime.fromMillisecondsSinceEpoch(ms);
              final at = map['basisMs'] as int?;
              basis = at == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(at);
              return null;
          }
          return null;
        });
    return channel;
  }
}

const _monthly = StoreProduct(
  id: ProProducts.monthly,
  price: r'$2.99',
  rawPrice: 2.99,
  currencyCode: 'USD',
);
const _yearly = StoreProduct(
  id: ProProducts.yearly,
  price: r'$9.99',
  rawPrice: 9.99,
  currencyCode: 'USD',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeKeychain keychain;
  late MethodChannel channel;

  setUp(() {
    keychain = FakeKeychain();
    channel = keychain.install('scanella/pro_test');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  StoreKitPurchase buildPurchase(MemoryIapGateway gateway) {
    return StoreKitPurchase(gateway: gateway, channel: channel);
  }

  test('buying the trial stamps one month, not a whole year', () async {
    final gateway = MemoryIapGateway(
      products: const [_yearly],
      transactionDate: DateTime.now(),
    );
    final purchase = buildPurchase(gateway);

    expect(await purchase.buy(ProPlan.yearly), isTrue);

    expect(keychain.entitled, isTrue);
    expect(keychain.trialUsed, isTrue);
    // A month and change, nowhere near the yearly period.
    final days = keychain.until!.difference(DateTime.now()).inDays;
    expect(days, greaterThan(28));
    expect(days, lessThan(40));
    await purchase.dispose();
  });

  test('buying after the trial stamps the full plan period', () async {
    keychain.trialUsed = true;
    final gateway = MemoryIapGateway(
      products: const [_yearly],
      transactionDate: DateTime.now(),
    );
    final purchase = buildPurchase(gateway);

    expect(await purchase.buy(ProPlan.yearly), isTrue);

    final days = keychain.until!.difference(DateTime.now()).inDays;
    expect(days, greaterThan(300));
    await purchase.dispose();
  });

  test('a cancelled trial stops being Pro on old iOS once the month is up',
      () async {
    // iOS 13 or 14: no silent store answer at all.
    keychain.storeKit2 = false;
    final gateway = MemoryIapGateway(
      products: const [_yearly],
      transactionDate: DateTime.now(),
    );
    final purchase = buildPurchase(gateway);
    expect(await purchase.buy(ProPlan.yearly), isTrue);

    // Still inside the free month, cancelled or not: Apple keeps serving.
    expect(await purchase.hasActiveEntitlement(), isTrue);

    // The month runs out. The app was deleted and reinstalled in between,
    // so the only thing left is the Keychain.
    keychain.until = DateTime.now().subtract(const Duration(days: 1));

    expect(await purchase.hasActiveEntitlement(), isFalse);
    // And the stale yes is gone for good, not re-read on the next launch.
    expect(keychain.entitled, isFalse);
    // The free month is still spent, so it must not be offered again.
    expect(await purchase.trialConsumed(), isTrue);
    await purchase.dispose();
  });

  test('a paying subscriber keeps Pro across a reinstall on old iOS', () async {
    keychain.storeKit2 = false;
    keychain.trialUsed = true;
    final gateway = MemoryIapGateway(
      products: const [_monthly],
      transactionDate: DateTime.now(),
    );
    final purchase = buildPurchase(gateway);
    expect(await purchase.buy(ProPlan.monthly), isTrue);

    // Prefs are wiped by the uninstall; the Keychain is not.
    expect(await purchase.hasActiveEntitlement(), isTrue);
    await purchase.dispose();
  });

  test('a renewal pushes the end date forward without anyone asking',
      () async {
    keychain.storeKit2 = false;
    keychain.trialUsed = true;
    final gateway = MemoryIapGateway(
      products: const [_monthly],
      transactionDate: DateTime.now().subtract(const Duration(days: 20)),
    );
    final purchase = buildPurchase(gateway);
    expect(await purchase.buy(ProPlan.monthly), isTrue);
    // Most of the month has gone by.
    keychain.until = DateTime.now().add(const Duration(days: 11));
    final first = keychain.until!;

    // StoreKit puts the renewal on the queue by itself at the next launch.
    gateway.transactionDate = DateTime.now();
    await gateway.restore();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(keychain.until!.isAfter(first), isTrue);
    expect(await purchase.hasActiveEntitlement(), isTrue);
    await purchase.dispose();
  });

  test('restoring a lapsed subscription does not hand back Pro', () async {
    keychain.storeKit2 = false;
    final gateway = MemoryIapGateway(
      products: const [_yearly],
      // The only transaction is a trial started well over a year ago.
      transactionDate: DateTime.now().subtract(const Duration(days: 400)),
    );
    final purchase = buildPurchase(gateway);

    expect(await purchase.restore(), isFalse);
    expect(keychain.entitled, isFalse);
    // It still counts as the free month having been taken.
    expect(await purchase.trialConsumed(), isTrue);
    await purchase.dispose();
  });

  test('Restore does not resurrect a cancelled yearly trial', () async {
    keychain.storeKit2 = false;
    final startedAt = DateTime.now().subtract(const Duration(days: 40));
    final gateway = MemoryIapGateway(
      products: const [_yearly],
      transactionDate: startedAt,
    );
    final purchase = buildPurchase(gateway);

    // The month was bought here, so the stamp says one month, not a year.
    expect(await purchase.buy(ProPlan.yearly), isTrue);
    keychain.until = startedAt.add(const Duration(days: 34));
    keychain.basis = startedAt;

    // It was cancelled and the month has passed. Restore replays the same
    // transaction; taking it at face value would grant a whole year.
    expect(await purchase.restore(), isFalse);
    expect(keychain.entitled, isFalse);
    await purchase.dispose();
  });

  test('restoring a live subscription still works', () async {
    keychain.storeKit2 = false;
    final gateway = MemoryIapGateway(
      products: const [_yearly],
      transactionDate: DateTime.now().subtract(const Duration(days: 30)),
    );
    final purchase = buildPurchase(gateway);

    expect(await purchase.restore(), isTrue);
    expect(keychain.entitled, isTrue);
    await purchase.dispose();
  });

  test('StoreKit 2 overrules the cached answer on iOS 15', () async {
    keychain.storeKit2 = true;
    keychain.liveEntitlement = false;
    keychain.entitled = true;
    keychain.until = DateTime.now().add(const Duration(days: 300));

    final purchase = buildPurchase(MemoryIapGateway(products: const [_yearly]));

    expect(await purchase.hasActiveEntitlement(), isFalse);
    expect(keychain.entitled, isFalse);
    await purchase.dispose();
  });
}
