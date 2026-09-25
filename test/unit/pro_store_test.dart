import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/pro/data/iap_gateway.dart';
import 'package:scan2/features/pro/data/storekit_purchase.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'missing store products are explained without a Bad state prefix',
    () async {
      final controller = ProController(
        purchase: StoreKitPurchase(gateway: MemoryIapGateway(products: [])),
        pricing: LocalizedPricing(
          locate: () async => const GeoCurrency(
            countryCode: 'PL',
            currencyCode: 'PLN',
            countryName: 'Poland',
          ),
          ratesFor: (_) async => 3.71,
        ),
      );
      await controller.restore();

      expect(controller.state.storeProductsReady, isFalse);
      expect(controller.state.error, isNotNull);
      expect(controller.state.error, isNot(startsWith('Bad state')));
      expect(controller.state.error, contains('Ready to Submit'));
      expect(controller.state.offer?.source, isNot('store'));
      expect(controller.state.offer?.currencyCode, 'PLN');

      await controller.subscribe(ProPlan.monthly);
      expect(controller.state.error, isNot(startsWith('Bad state')));
      expect(controller.state.error, contains(ProProducts.monthly));
    },
  );

  test(
    'a reinstall after a cancelled trial does not re-offer the month',
    () async {
      // SharedPreferences is empty, as it is after an uninstall. The store
      // still remembers the trial, so the offer must stay hidden.
      final purchase = FakeProPurchase(entitled: false, trialUsed: true);
      final controller = ProController(
        purchase: purchase,
        pricing: LocalizedPricing(
          locate: () async => const GeoCurrency(
            countryCode: 'US',
            currencyCode: 'USD',
            countryName: 'United States',
          ),
          ratesFor: (_) async => 1,
        ),
      );
      await controller.restore();

      expect(controller.state.isPro, isFalse);
      expect(controller.state.trialUsed, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('scanella.pro.trial_used'), isTrue);
    },
  );

  test(
    'a first install with no purchase history is still offered the month',
    () async {
      final controller = ProController(
        purchase: FakeProPurchase(entitled: false, trialUsed: false),
        pricing: LocalizedPricing(
          locate: () async => const GeoCurrency(
            countryCode: 'US',
            currencyCode: 'USD',
            countryName: 'United States',
          ),
          ratesFor: (_) async => 1,
        ),
      );
      await controller.restore();

      expect(controller.state.trialUsed, isFalse);
    },
  );

  test(
    'subscribing records the trial where an uninstall cannot reach it',
    () async {
      final purchase = FakeProPurchase();
      final controller = ProController(
        purchase: purchase,
        pricing: LocalizedPricing(
          locate: () async => const GeoCurrency(
            countryCode: 'US',
            currencyCode: 'USD',
            countryName: 'United States',
          ),
          ratesFor: (_) async => 1,
        ),
      );
      await controller.restore();
      expect(await controller.subscribe(ProPlan.yearly), isTrue);

      expect(controller.state.isPro, isTrue);
      expect(controller.state.trialUsed, isTrue);
      expect(purchase.trialUsed, isTrue);
    },
  );

  test(
    'no introductory offer configured means no free month is promised',
    () async {
      // A brand new install, but App Store Connect has no offer set up.
      final controller = ProController(
        purchase: FakeProPurchase(trialUsed: false, introOffer: false),
        pricing: LocalizedPricing(
          locate: () async => const GeoCurrency(
            countryCode: 'US',
            currencyCode: 'USD',
            countryName: 'United States',
          ),
          ratesFor: (_) async => 1,
        ),
      );
      await controller.restore();

      expect(controller.state.trialUsed, isFalse);
      expect(controller.state.canStartTrial, isFalse);
      expect(controller.state.canStartCourtesyTrial, isTrue);
    },
  );

  test('the store can offer the month even when nothing is saved', () async {
    final controller = ProController(
      purchase: FakeProPurchase(trialUsed: false, introOffer: true),
      pricing: LocalizedPricing(
        locate: () async => const GeoCurrency(
          countryCode: 'US',
          currencyCode: 'USD',
          countryName: 'United States',
        ),
        ratesFor: (_) async => 1,
      ),
    );
    await controller.restore();

    expect(controller.state.canStartTrial, isFalse);
    expect(controller.state.canStartCourtesyTrial, isTrue);
  });

  test('a cancelled trial is not offered the month again', () async {
    // Apple remembers, so it says no even though prefs are empty.
    final controller = ProController(
      purchase: FakeProPurchase(trialUsed: true, introOffer: false),
      pricing: LocalizedPricing(
        locate: () async => const GeoCurrency(
          countryCode: 'US',
          currencyCode: 'USD',
          countryName: 'United States',
        ),
        ratesFor: (_) async => 1,
      ),
    );
    await controller.restore();

    expect(controller.state.canStartTrial, isFalse);
    expect(controller.state.canStartCourtesyTrial, isTrue);
  });

  test('with no answer from the store, the saved record decides', () async {
    final controller = ProController(
      purchase: FakeProPurchase(trialUsed: false),
      pricing: LocalizedPricing(
        locate: () async => const GeoCurrency(
          countryCode: 'US',
          currencyCode: 'USD',
          countryName: 'United States',
        ),
        ratesFor: (_) async => 1,
      ),
    );
    await controller.restore();

    expect(controller.state.canStartTrial, isFalse);
    expect(controller.state.canStartCourtesyTrial, isTrue);
  });

  test('Restore switches Pro off when the store says there is none', () async {
    SharedPreferences.setMockInitialValues({'scanella.pro.entitled': true});
    final purchase = FakeProPurchase(entitled: false);
    final controller = ProController(
      purchase: purchase,
      pricing: LocalizedPricing(
        locate: () async => const GeoCurrency(
          countryCode: 'US',
          currencyCode: 'USD',
          countryName: 'United States',
        ),
        ratesFor: (_) async => 1,
      ),
    );
    await controller.restore();
    expect(controller.state.isPro, isFalse);

    // Pretend the saved answer is stale and the store is reachable.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scanella.pro.entitled', true);
    expect(await controller.restorePurchases(), isFalse);

    expect(controller.state.isPro, isFalse);
    expect(prefs.getBool('scanella.pro.entitled'), isFalse);
  });

  test(
    'Settings-style display drops USD store prices for a local country',
    () async {
      final controller = ProController(
        purchase: FakeProPurchase(
          offer: LocalizedPricing.formatOffer(
            currencyCode: 'USD',
            countryCode: 'US',
            countryName: 'United States',
            usdToLocal: 1,
            source: 'store',
          ),
        ),
        pricing: LocalizedPricing(
          locate: () async => const GeoCurrency(
            countryCode: 'IN',
            currencyCode: 'INR',
            countryName: 'India',
          ),
          ratesFor: (currency) async => currency == 'INR' ? 83.5 : 1,
        ),
      );
      await controller.restore();

      expect(controller.state.storeProductsReady, isTrue);
      expect(controller.state.offer?.currencyCode, 'INR');
      expect(controller.state.offer?.source, 'internet');
      expect(controller.state.offer?.monthlyLabel, isNot(contains(r'$4.99')));
    },
  );

  test('duplicate product error is a short App Store message', () async {
    const monthly = StoreProduct(
      id: ProProducts.monthly,
      price: r'$4.99',
      rawPrice: 4.99,
      currencyCode: 'USD',
    );
    final controller = ProController(
      purchase: StoreKitPurchase(
        gateway: MemoryIapGateway(
          products: [monthly],
          buyError: PlatformException(
            code: 'storekit_duplicate_product_object',
            message:
                'There is a pending transaction for the same product identifier. '
                'Please either wait for it to be finished or finish it manually '
                'using `completePurchase` to avoid edge cases.',
            details: 'scanella_pro_monthly',
          ),
        ),
      ),
      pricing: LocalizedPricing(
        locate: () async => const GeoCurrency(
          countryCode: 'US',
          currencyCode: 'USD',
          countryName: 'United States',
        ),
        ratesFor: (_) async => 1,
      ),
    );
    await controller.subscribe(ProPlan.monthly);

    expect(controller.state.error, StoreKitPurchase.pendingSheetMessage);
    expect(controller.state.error, isNot(contains('PlatformException')));
    expect(controller.state.error, isNot(contains('scanella_pro_monthly')));

    controller.clearError();
    expect(controller.state.error, isNull);
  });

  LocalizedPricing _usPricing() {
    return LocalizedPricing(
      locate: () async => const GeoCurrency(
        countryCode: 'US',
        currencyCode: 'USD',
        countryName: 'United States',
      ),
      ratesFor: (_) async => 1,
    );
  }

  test('a testing build shows the trial without tapping anything', () async {
    final purchase = FakeProPurchase(
      entitled: true,
      trialUsed: true,
      introOffer: false,
    );
    final controller = ProController(
      purchase: purchase,
      pricing: _usPricing(),
      testingTools: true,
    );
    await controller.restore();

    expect(controller.state.isPro, isFalse);
    expect(controller.state.canStartTrial, isFalse);
    expect(controller.state.canStartCourtesyTrial, isTrue);
    expect(controller.state.testingBuild, isTrue);
    expect(purchase.entitlementChecks, 0);
  });

  test('testing tools can pin a subscribed device as free', () async {
    SharedPreferences.setMockInitialValues({
      ProController.testingForceFreeKey: true,
    });
    final controller = ProController(
      purchase: FakeProPurchase(entitled: true),
      pricing: _usPricing(),
      testingTools: true,
    );
    await controller.restore();
    expect(controller.state.isPro, isFalse);
  });

  test('Ask the store again uses a live subscription', () async {
    final controller = ProController(
      purchase: FakeProPurchase(
        entitled: true,
        testingUseStore: true,
        courtesyUsed: true,
      ),
      pricing: _usPricing(),
      testingTools: true,
    );
    await controller.restore();
    expect(controller.state.isPro, isTrue);
    expect(controller.state.canStartTrial, isFalse);
  });

  test('leftover store Pro does not skip the 7-day tap', () async {
    final purchase = FakeProPurchase(
      entitled: true,
      trialUsed: true,
      introOffer: false,
      testingUseStore: true,
    );
    final controller = ProController(
      purchase: purchase,
      pricing: _usPricing(),
      testingTools: true,
    );
    await controller.restore();

    expect(controller.state.isPro, isFalse);
    expect(controller.state.canStartCourtesyTrial, isTrue);

    expect(
      await controller.startOfferedTrialOrSubscribe(ProPlan.yearly),
      isTrue,
    );
    expect(purchase.buyCalls, 1);
    expect(purchase.courtesyStarts, 0);
    expect(controller.state.isPro, isTrue);
  });

  test('an App Store build ignores the testing pin', () async {
    SharedPreferences.setMockInitialValues({
      ProController.testingForceFreeKey: true,
    });
    final controller = ProController(
      purchase: FakeProPurchase(entitled: true),
      pricing: _usPricing(),
      testingTools: false,
    );
    await controller.restore();
    expect(controller.state.isPro, isTrue);
  });

  test('buying Pro drops the testing pin', () async {
    SharedPreferences.setMockInitialValues({
      ProController.testingForceFreeKey: true,
    });
    final controller = ProController(
      purchase: FakeProPurchase(entitled: false),
      pricing: _usPricing(),
      testingTools: true,
    );
    await controller.restore();
    expect(controller.state.isPro, isFalse);

    expect(await controller.subscribe(ProPlan.yearly), isTrue);
    expect(controller.state.isPro, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ProController.testingForceFreeKey), isNot(isTrue));
  });

  test(
    'a reinstall with testing pins stays free and shows the month',
    () async {
      // Prefs are empty, as after an uninstall. The store still says this
      // Apple ID is subscribed and has used the trial. The Keychain pins
      // are what must keep the unpaid first-run screens on offer.
      final purchase = FakeProPurchase(
        entitled: true,
        trialUsed: true,
        introOffer: false,
        testingForceFree: true,
        testingOfferTrial: true,
      );
      final controller = ProController(
        purchase: purchase,
        pricing: _usPricing(),
        testingTools: true,
      );
      await controller.restore();

      expect(controller.state.isPro, isFalse);
      expect(controller.state.trialUsed, isFalse);
      expect(controller.state.canStartCourtesyTrial, isTrue);
      expect(controller.state.canStartTrial, isFalse);
      expect(purchase.entitlementChecks, 0);
    },
  );

  test(
    'without testing tools, Keychain pins do not hide a subscription',
    () async {
      final purchase = FakeProPurchase(
        entitled: true,
        trialUsed: true,
        introOffer: false,
        testingForceFree: true,
        testingOfferTrial: true,
      );
      final controller = ProController(
        purchase: purchase,
        pricing: _usPricing(),
      );
      await controller.restore();

      expect(controller.state.isPro, isTrue);
      expect(controller.state.canStartTrial, isFalse);
      expect(purchase.entitlementChecks, greaterThan(0));
    },
  );

  test(
    'Start trial does not open Apple when this Apple ID already used it',
    () async {
      final purchase = FakeProPurchase(
        entitled: false,
        trialUsed: true,
        introOffer: false,
        courtesyUsed: true,
        testingOfferTrial: true,
      );
      final controller = ProController(
        purchase: purchase,
        pricing: _usPricing(),
        testingTools: true,
      );
      await controller.restore();
      expect(controller.state.canStartCourtesyTrial, isFalse);
      expect(controller.state.canStartTrial, isTrue);

      expect(await controller.subscribe(ProPlan.yearly), isFalse);
      expect(purchase.buyCalls, 0);
      expect(
        controller.state.error,
        ProController.trialWouldChargeTodayMessage,
      );
    },
  );

  test('Start trial still buys when Apple would grant the month', () async {
    final purchase = FakeProPurchase(
      entitled: false,
      introOffer: true,
      courtesyUsed: true,
    );
    final controller = ProController(purchase: purchase, pricing: _usPricing());
    await controller.restore();

    expect(await controller.subscribe(ProPlan.yearly), isTrue);
    expect(purchase.buyCalls, 1);
    expect(controller.state.isPro, isTrue);
  });

  test('a first install opens Apple’s sheet for the 1 month trial', () async {
    final purchase = FakeProPurchase(introOffer: false);
    final controller = ProController(purchase: purchase, pricing: _usPricing());
    await controller.restore();
    expect(controller.state.canStartCourtesyTrial, isTrue);

    expect(
      await controller.startOfferedTrialOrSubscribe(ProPlan.yearly),
      isTrue,
    );
    expect(purchase.buyCalls, 1);
    expect(purchase.courtesyStarts, 0);
    expect(controller.state.isPro, isTrue);
    expect(controller.state.canStartCourtesyTrial, isFalse);
  });

  test(
    'the 7-day trial stays on after an uninstall while it is running',
    () async {
      final until = DateTime(2026, 9, 29);
      final purchase = FakeProPurchase(
        entitled: false,
        courtesyUsed: true,
        courtesyUntil: until,
      );
      final controller = ProController(
        purchase: purchase,
        pricing: _usPricing(),
        clock: () => DateTime(2026, 9, 24),
      );
      await controller.restore();
      expect(controller.state.isPro, isTrue);
      expect(controller.state.canStartCourtesyTrial, isFalse);
    },
  );

  test('the 7-day trial is not offered again after it ends', () async {
    final purchase = FakeProPurchase(
      entitled: false,
      introOffer: false,
      courtesyUsed: true,
      courtesyUntil: DateTime(2026, 9, 20),
    );
    final controller = ProController(
      purchase: purchase,
      pricing: _usPricing(),
      clock: () => DateTime(2026, 9, 24),
    );
    await controller.restore();
    expect(controller.state.isPro, isFalse);
    expect(controller.state.canStartCourtesyTrial, isFalse);
    expect(await controller.startCourtesyTrial(), isFalse);
    expect(purchase.courtesyStarts, 0);
  });

  test(
    'Restore keeps the 7-day trial on when Apple has no subscription',
    () async {
      SharedPreferences.setMockInitialValues({'scanella.pro.entitled': true});
      final purchase = FakeProPurchase(
        entitled: false,
        courtesyUsed: true,
        courtesyUntil: DateTime(2026, 9, 29),
      );
      final controller = ProController(
        purchase: purchase,
        pricing: _usPricing(),
        clock: () => DateTime(2026, 9, 24),
      );
      await controller.restore();
      expect(controller.state.isPro, isTrue);

      expect(await controller.restorePurchases(), isFalse);
      expect(controller.state.isPro, isTrue);
    },
  );
}
