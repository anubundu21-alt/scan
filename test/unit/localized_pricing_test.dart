import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';

void main() {
  test('US keeps dollar list prices', () async {
    final offer = await const LocalizedPricing(
      locate: _us,
      ratesFor: _identity,
    ).resolve(locale: const Locale('en', 'US'));

    expect(offer.currencyCode, 'USD');
    expect(offer.monthly, 2.99);
    expect(offer.yearly, 9.99);
    expect(offer.monthlyLabel, contains('2.99'));
    expect(offer.yearlyLabel, contains('9.99'));
    expect(offer.source, 'internet');
    expect(offer.yearlySavingsPercent, greaterThan(40));
  });

  test('big converted prices land on x9.99, small ones are left alone', () {
    // Poland: the yearly converts to about 38.5 zloty, which used to show
    // as 38.99. A shop would price that 39.99.
    expect(LocalizedPricing.charmPrice(38.46, 'PLN'), 39.99);
    expect(LocalizedPricing.charmPrice(39.10, 'PLN'), 39.99);

    // Only when the next one is close, so a real 24.99 is not pushed up.
    expect(LocalizedPricing.charmPrice(24.00, 'PLN'), 24.99);
    expect(LocalizedPricing.charmPrice(45.50, 'PLN'), 45.99);

    // Small prices keep their own ending.
    expect(LocalizedPricing.charmPrice(9.99, 'USD'), 9.99);
    expect(LocalizedPricing.charmPrice(7.39, 'GBP'), 7.99);
    expect(LocalizedPricing.charmPrice(2.50, 'USD'), 2.99);
  });

  test('UK converts to pounds from the connection', () async {
    final offer = await LocalizedPricing(
      locate: () async => const GeoCurrency(
        countryCode: 'GB',
        currencyCode: 'GBP',
        countryName: 'United Kingdom',
      ),
      ratesFor: (currency) async => currency == 'GBP' ? 0.74 : 1,
    ).resolve(locale: const Locale('en', 'US'));

    expect(offer.currencyCode, 'GBP');
    expect(offer.countryName, 'United Kingdom');
    expect(offer.monthly, 2.99);
    expect(offer.yearly, 7.99);
    expect(offer.monthlyLabel, contains('£'));
  });

  test('India converts to rupees', () async {
    final offer = await LocalizedPricing(
      locate: () async => const GeoCurrency(
        countryCode: 'IN',
        currencyCode: 'INR',
        countryName: 'India',
      ),
      ratesFor: (currency) async => currency == 'INR' ? 83.5 : 1,
    ).resolve();

    expect(offer.currencyCode, 'INR');
    expect(offer.monthly, 299);
    expect(offer.yearly, 834.99);
  });

  test('the App Store price wins, whatever currency it reports', () {
    final store = LocalizedPricing.formatOffer(
      currencyCode: 'PLN',
      countryCode: 'PL',
      countryName: 'Poland',
      usdToLocal: 1,
      source: 'store',
      monthly: 14.99,
      yearly: 39.99,
    );
    final located = LocalizedPricing.formatOffer(
      currencyCode: 'PLN',
      countryCode: 'PL',
      countryName: 'Poland',
      usdToLocal: 3.85,
      source: 'internet',
    );

    final shown = LocalizedPricing.forDisplay(located: located, store: store);
    expect(shown.source, 'store');
    expect(shown.yearly, 39.99);
  });

  test('the estimate is used only until the store answers', () {
    final located = LocalizedPricing.formatOffer(
      currencyCode: 'PLN',
      countryCode: 'PL',
      countryName: 'Poland',
      usdToLocal: 3.85,
      source: 'internet',
    );

    final shown = LocalizedPricing.forDisplay(located: located, store: null);
    expect(shown.source, 'internet');
    expect(identical(shown, located), isTrue);
  });

  test('store prices are kept when they already match the location', () {
    final store = LocalizedPricing.formatOffer(
      currencyCode: 'GBP',
      countryCode: 'GB',
      countryName: 'United Kingdom',
      usdToLocal: 0.74,
      source: 'store',
    );
    final located = LocalizedPricing.formatOffer(
      currencyCode: 'GBP',
      countryCode: 'GB',
      countryName: 'United Kingdom',
      usdToLocal: 0.74,
      source: 'internet',
    );

    final shown = LocalizedPricing.forDisplay(located: located, store: store);
    expect(shown.source, 'store');
    expect(shown.currencyCode, 'GBP');
  });

  test('device locale is used when the internet lookup fails', () async {
    final offer = await LocalizedPricing(
      locate: () async => null,
      ratesFor: (currency) async => currency == 'EUR' ? 0.86 : 1,
    ).resolve(locale: const Locale('de', 'DE'));

    expect(offer.currencyCode, 'EUR');
    expect(offer.source, 'device');
    expect(offer.monthly, 2.99);
    expect(offer.monthlyLabel, contains('€'));
  });

  test('Poland uses App Store monthly starting price', () {
    final offer = LocalizedPricing.formatOffer(
      currencyCode: 'PLN',
      countryCode: 'PL',
      countryName: 'Poland',
      usdToLocal: 3.71,
      source: 'internet',
    );

    expect(offer.monthly, 14.99);
    expect(offer.yearly, 74.99);
    expect(offer.monthlyLabel, contains('14.99'));
    expect(offer.yearlyLabel, contains('74.99'));
  });
}

Future<GeoCurrency?> _us() async => const GeoCurrency(
  countryCode: 'US',
  currencyCode: 'USD',
  countryName: 'United States',
);

Future<double?> _identity(String currency) async => 1;
