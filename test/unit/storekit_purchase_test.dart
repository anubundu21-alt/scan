import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/pro/data/iap_gateway.dart';
import 'package:scan2/features/pro/data/storekit_purchase.dart';
import 'package:scan2/features/pro/domain/pro_purchase.dart';

void main() {
  const monthly = StoreProduct(
    id: ProProducts.monthly,
    price: '\$4.99',
    rawPrice: 4.99,
    currencyCode: 'USD',
  );
  const yearly = StoreProduct(
    id: ProProducts.yearly,
    price: '\$19.99',
    rawPrice: 19.99,
    currencyCode: 'USD',
  );

  test('buy unlocks when the App Store completes the purchase', () async {
    final store = StoreKitPurchase(
      gateway: MemoryIapGateway(products: [yearly]),
    );
    expect(await store.buy(ProPlan.yearly), isTrue);
  });

  test('buy fails when the customer cancels the Apple sheet', () async {
    final store = StoreKitPurchase(
      gateway: MemoryIapGateway(
        products: [yearly],
        emitOnBuy: IapStatus.canceled,
      ),
    );
    expect(await store.buy(ProPlan.yearly), isFalse);
  });

  test('buy explains when the subscription is not in the store', () async {
    final store = StoreKitPurchase(gateway: MemoryIapGateway(products: []));
    expect(
      () => store.buy(ProPlan.yearly),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains(ProProducts.yearly),
            contains('Ready to Submit'),
            contains('Reinstalling TestFlight will not fix this'),
            isNot(contains('Add auto-renewable')),
          ),
        ),
      ),
    );
  });

  test('buy surfaces the App Store query error', () async {
    final store = StoreKitPurchase(
      gateway: MemoryIapGateway(
        products: [yearly],
        queryError: StateError('Paid Apps Agreement is not Active'),
      ),
    );
    expect(
      () => store.buy(ProPlan.yearly),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Paid Apps Agreement'),
        ),
      ),
    );
  });

  test('store prices come from the App Store, not a location banner', () async {
    final store = StoreKitPurchase(
      gateway: MemoryIapGateway(products: [monthly, yearly]),
    );
    final offer = await store.storeOffer();
    expect(offer, isNotNull);
    expect(offer!.source, 'store');
    expect(offer.yearlyLabel, '\$19.99');
    expect(offer.monthlyLabel, '\$4.99');
    expect(offer.countryName, isEmpty);
  });

  test('restore finds an existing Apple ID purchase', () async {
    final store = StoreKitPurchase(
      gateway: MemoryIapGateway(
        products: [yearly],
        emitOnBuy: IapStatus.restored,
      ),
    );
    expect(await store.restore(), isTrue);
  });
}
