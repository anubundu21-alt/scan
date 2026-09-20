import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:scan2/features/pro/domain/monthly_starting_prices.dart';

/// Scanella Pro list prices in US dollars. StoreKit replaces these when
/// products are live; until then we convert from this base using the
/// user's country (IP, then the device locale).
@immutable
class LocalizedOffer {
  const LocalizedOffer({
    required this.currencyCode,
    required this.countryCode,
    required this.countryName,
    required this.monthly,
    required this.yearly,
    required this.monthlyLabel,
    required this.yearlyLabel,
    required this.source,
  });

  static const monthlyUsd = 2.99;
  static const yearlyUsd = 9.99;

  final String currencyCode;
  final String countryCode;
  final String countryName;
  final double monthly;
  final double yearly;
  final String monthlyLabel;
  final String yearlyLabel;

  /// `store`, `internet`, or `device`.
  final String source;

  String get yearlyPerMonthLabel {
    final each = yearly / 12;
    return LocalizedPricing.formatMoney(each, currencyCode);
  }

  int get yearlySavingsPercent {
    final full = monthly * 12;
    if (full <= 0) return 0;
    return (((full - yearly) / full) * 100).round();
  }
}

@immutable
class GeoCurrency {
  const GeoCurrency({
    required this.countryCode,
    required this.currencyCode,
    this.countryName,
  });

  final String countryCode;
  final String currencyCode;
  final String? countryName;
}

/// Resolves Pro prices for the current country without sending any scan.
class LocalizedPricing {
  const LocalizedPricing({this.locate, this.ratesFor});

  /// Injected in tests. Production talks to ip-api / ipapi.
  final Future<GeoCurrency?> Function()? locate;

  /// Injected FX lookup. Production uses Frankfurter, then a static table.
  final Future<double?> Function(String currency)? ratesFor;

  Future<LocalizedOffer> resolve({Locale? locale}) async {
    final device = _fromLocale(locale);
    GeoCurrency? geo;
    try {
      geo = locate != null ? await locate!() : await lookupLocation();
    } catch (_) {
      geo = null;
    }

    final chosen = geo ?? device;
    final list = StorefrontPrice.monthly(chosen.countryCode);
    final currency = list?.currencyCode ?? chosen.currencyCode;
    var rate = _staticRate(currency);
    if (ratesFor != null) {
      try {
        rate = await ratesFor!(currency) ?? rate;
      } catch (_) {}
    } else if (currency != 'USD') {
      try {
        rate = await lookupUsdRate(currency) ?? rate;
      } catch (_) {}
    }

    return formatOffer(
      currencyCode: currency,
      countryCode: chosen.countryCode,
      countryName: chosen.countryName ?? _countryName(chosen.countryCode),
      usdToLocal: rate,
      source: geo != null ? 'internet' : 'device',
      monthly: list?.amount,
    );
  }

  /// Prices for Settings and the paywall.
  ///
  /// StoreKit often reports the USD catalogue price while the purchase
  /// sheet is already in the customer's currency. When that happens, show
  /// the location price so Settings matches checkout.
  static LocalizedOffer forDisplay({
    required LocalizedOffer located,
    LocalizedOffer? store,
  }) {
    if (store == null) return located;
    final storeCode = store.currencyCode.toUpperCase();
    final localCode = located.currencyCode.toUpperCase();
    if (storeCode == localCode) return store;
    if (storeCode == 'USD' && localCode != 'USD') return located;
    return store;
  }

  static LocalizedOffer formatOffer({
    required String currencyCode,
    required String countryCode,
    required String countryName,
    required double usdToLocal,
    required String source,
    double? monthly,
    double? yearly,
  }) {
    final list = StorefrontPrice.monthly(countryCode);
    final currency = monthly == null && list != null
        ? list.currencyCode
        : currencyCode;
    final month =
        monthly ??
        list?.amount ??
        charmPrice(LocalizedOffer.monthlyUsd * usdToLocal, currency);
    final year =
        yearly ??
        charmPrice(LocalizedOffer.yearlyUsd * usdToLocal, currency);
    return LocalizedOffer(
      currencyCode: currency,
      countryCode: countryCode,
      countryName: countryName,
      monthly: month,
      yearly: year,
      monthlyLabel: formatMoney(month, currency),
      yearlyLabel: formatMoney(year, currency),
      source: source,
    );
  }

  static GeoCurrency _fromLocale(Locale? locale) {
    final code = (locale?.countryCode ?? _deviceCountry()).toUpperCase();
    return GeoCurrency(
      countryCode: code,
      currencyCode: currencyForCountry(code),
      countryName: _countryName(code),
    );
  }

  static String _deviceCountry() {
    try {
      final name = Platform.localeName; // en_GB, en-US
      final parts = name.split(RegExp(r'[_-]'));
      if (parts.length >= 2 && parts.last.length == 2) {
        return parts.last.toUpperCase();
      }
    } catch (_) {}
    return 'US';
  }

  /// Country from a public IP. Only country and currency — no documents.
  static Future<GeoCurrency?> lookupLocation() async {
    if (kIsWeb) return null;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final ipapi = await _getJson(client, Uri.parse('https://ipapi.co/json/'));
      final country = (ipapi?['country_code'] as String? ?? '').toUpperCase();
      final currency = (ipapi?['currency'] as String? ?? '').toUpperCase();
      if (country.length == 2) {
        return GeoCurrency(
          countryCode: country,
          currencyCode: currency.length == 3
              ? currency
              : currencyForCountry(country),
          countryName:
              ipapi?['country_name'] as String? ?? _countryName(country),
        );
      }
    } catch (_) {}
    try {
      final fallback = await _getJson(
        client,
        Uri.parse('http://ip-api.com/json/?fields=status,country,countryCode'),
      );
      if (fallback?['status'] == 'success') {
        final country = (fallback?['countryCode'] as String? ?? '')
            .toUpperCase();
        if (country.length == 2) {
          return GeoCurrency(
            countryCode: country,
            currencyCode: currencyForCountry(country),
            countryName:
                fallback?['country'] as String? ?? _countryName(country),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<double?> lookupUsdRate(String currency) async {
    if (currency == 'USD') return 1;
    if (kIsWeb) return _staticRate(currency);
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return _staticRate(currency);
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final json = await _getJson(
        client,
        Uri.parse('https://api.frankfurter.app/latest?from=USD&to=$currency'),
      );
      final rates = json?['rates'];
      if (rates is Map && rates[currency] is num) {
        return (rates[currency] as num).toDouble();
      }
    } catch (_) {}
    return _staticRate(currency);
  }

  static Future<Map<String, dynamic>?> _getJson(
    HttpClient client,
    Uri uri,
  ) async {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  static String currencyForCountry(String country) {
    return _countryCurrency[country.toUpperCase()] ?? 'USD';
  }

  static double _staticRate(String currency) => _usdRates[currency] ?? 1;

  /// App Store-style charm prices: 4.99, 18.99, 74.99 — not 18.62.
  static double charmPrice(double value, String currency) {
    if (value <= 0) {
      return _zeroDecimalCurrencies.contains(currency.toUpperCase())
          ? 1
          : 0.99;
    }
    if (_zeroDecimalCurrencies.contains(currency.toUpperCase())) {
      if (value >= 1000) {
        return (((value.ceil() + 99) ~/ 100) * 100 - 1).toDouble();
      }
      if (value >= 100) {
        return (((value.ceil() + 9) ~/ 10) * 10 - 1).toDouble();
      }
      return value.roundToDouble();
    }
    final whole = value.floor();
    var charm = whole + 0.99;
    if (value > charm + 1e-9) charm = whole + 1.99;
    // Past a couple of tens, shops step in x9.99: 39.99 reads like a price,
    // 38.99 reads like a conversion. Only snap when the next one is close,
    // so a genuine 24.99 is not pushed to 29.99.
    if (charm >= 20) {
      final nextNine = ((charm / 10).ceil() * 10) - 0.01;
      if (nextNine - charm <= 2) charm = nextNine;
    }
    return (charm * 100).round() / 100;
  }

  static const _zeroDecimalCurrencies = {
    'BIF',
    'CLP',
    'DJF',
    'GNF',
    'ISK',
    'JPY',
    'KMF',
    'KRW',
    'PYG',
    'RWF',
    'UGX',
    'VND',
    'VUV',
    'XAF',
    'XOF',
    'XPF',
    'HUF',
    'IDR',
    'TWD',
    'COP',
  };

  static String formatMoney(double amount, String currency) {
    try {
      return NumberFormat.simpleCurrency(name: currency).format(amount);
    } catch (_) {
      return '$currency ${amount.toStringAsFixed(2)}';
    }
  }

  static String _countryName(String code) => _countryNames[code] ?? code;
}

/// ISO 3166-1 alpha-2 → ISO 4217. Enough to cover typical App Store locales.
const _countryCurrency = <String, String>{
  'US': 'USD',
  'CA': 'CAD',
  'MX': 'MXN',
  'GB': 'GBP',
  'IE': 'EUR',
  'FR': 'EUR',
  'DE': 'EUR',
  'ES': 'EUR',
  'IT': 'EUR',
  'NL': 'EUR',
  'BE': 'EUR',
  'AT': 'EUR',
  'PT': 'EUR',
  'FI': 'EUR',
  'GR': 'EUR',
  'LU': 'EUR',
  'SK': 'EUR',
  'SI': 'EUR',
  'EE': 'EUR',
  'LV': 'EUR',
  'LT': 'EUR',
  'CY': 'EUR',
  'MT': 'EUR',
  'HR': 'EUR',
  'CH': 'CHF',
  'NO': 'NOK',
  'SE': 'SEK',
  'DK': 'DKK',
  'PL': 'PLN',
  'CZ': 'CZK',
  'HU': 'HUF',
  'RO': 'RON',
  'BG': 'BGN',
  'AU': 'AUD',
  'NZ': 'NZD',
  'JP': 'JPY',
  'KR': 'KRW',
  'CN': 'CNY',
  'HK': 'HKD',
  'TW': 'TWD',
  'SG': 'SGD',
  'IN': 'INR',
  'ID': 'IDR',
  'MY': 'MYR',
  'TH': 'THB',
  'PH': 'PHP',
  'VN': 'VND',
  'AE': 'AED',
  'SA': 'SAR',
  'IL': 'ILS',
  'TR': 'TRY',
  'ZA': 'ZAR',
  'NG': 'NGN',
  'EG': 'EGP',
  'KE': 'KES',
  'BR': 'BRL',
  'AR': 'ARS',
  'CL': 'CLP',
  'CO': 'COP',
  'PE': 'PEN',
  'RU': 'RUB',
  'UA': 'UAH',
  'PK': 'PKR',
  'BD': 'BDT',
};

const _countryNames = <String, String>{
  'US': 'United States',
  'GB': 'United Kingdom',
  'CA': 'Canada',
  'AU': 'Australia',
  'IN': 'India',
  'DE': 'Germany',
  'FR': 'France',
  'JP': 'Japan',
  'BR': 'Brazil',
  'AE': 'United Arab Emirates',
  'SG': 'Singapore',
  'IE': 'Ireland',
  'NL': 'Netherlands',
  'ES': 'Spain',
  'IT': 'Italy',
  'MX': 'Mexico',
  'NZ': 'New Zealand',
  'KR': 'South Korea',
  'ZA': 'South Africa',
};

/// Offline USD → local, used when the rate API is unreachable.
const _usdRates = <String, double>{
  'USD': 1,
  'EUR': 0.86,
  'GBP': 0.74,
  'CAD': 1.38,
  'AUD': 1.53,
  'NZD': 1.67,
  'CHF': 0.80,
  'JPY': 147,
  'CNY': 7.15,
  'HKD': 7.80,
  'SGD': 1.29,
  'INR': 83.5,
  'KRW': 1350,
  'TWD': 32.2,
  'MXN': 18.6,
  'BRL': 5.45,
  'SEK': 9.55,
  'NOK': 10.1,
  'DKK': 6.42,
  'PLN': 3.65,
  'CZK': 21.4,
  'HUF': 340,
  'RON': 4.28,
  'BGN': 1.68,
  'TRY': 34.2,
  'AED': 3.67,
  'SAR': 3.75,
  'ILS': 3.72,
  'ZAR': 18.2,
  'THB': 34.0,
  'MYR': 4.45,
  'PHP': 56.5,
  'IDR': 15500,
  'VND': 25000,
  'PKR': 278,
  'BDT': 119,
  'NGN': 1600,
  'EGP': 48.5,
  'KES': 129,
  'ARS': 960,
  'CLP': 940,
  'COP': 4100,
  'PEN': 3.75,
  'RUB': 92,
  'UAH': 41,
};
