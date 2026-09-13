import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Settings Pro row uses location currency, not USD list prices', (
    tester,
  ) async {
    final usd = LocalizedPricing.formatOffer(
      currencyCode: 'USD',
      countryCode: 'US',
      countryName: 'United States',
      usdToLocal: 1,
      source: 'store',
    );
    final inr = LocalizedPricing.formatOffer(
      currencyCode: 'INR',
      countryCode: 'IN',
      countryName: 'India',
      usdToLocal: 83.5,
      source: 'internet',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proProvider.overrideWith(
            (ref) => ProController(
              purchase: FakeProPurchase(offer: usd),
              pricing: LocalizedPricing(
                locate: () async => const GeoCurrency(
                  countryCode: 'IN',
                  currencyCode: 'INR',
                  countryName: 'India',
                ),
                ratesFor: (currency) async => currency == 'INR' ? 83.5 : 1,
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to Pro'), findsOneWidget);
    expect(find.textContaining(inr.monthlyLabel), findsOneWidget);
    expect(find.textContaining(inr.yearlyLabel), findsOneWidget);
    expect(find.textContaining(r'$4.99'), findsNothing);
    expect(find.textContaining('USD'), findsNothing);
    expect(find.textContaining(usd.monthlyLabel), findsNothing);
  });
}
