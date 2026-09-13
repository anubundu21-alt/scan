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
}
