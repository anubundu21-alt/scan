import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/pro/data/iap_gateway.dart';
import 'package:scan2/features/pro/data/storekit_purchase.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('missing store products are explained without a Bad state prefix', () async {
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
  });

  test('Settings-style display drops USD store prices for a local country', () async {
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
  });

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
}
