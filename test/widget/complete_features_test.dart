import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/presentation/complete_features_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Complete features splits free and Pro and shows prices', (
    tester,
  ) async {
    final offer = LocalizedPricing.formatOffer(
      currencyCode: 'GBP',
      countryCode: 'GB',
      countryName: 'United Kingdom',
      usdToLocal: 0.74,
      source: 'store',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proProvider.overrideWith(
            (ref) => ProController(
              purchase: FakeProPurchase(
                offer: offer,
                trialUsed: true,
                introOffer: false,
                courtesyUsed: true,
              ),
              pricing: LocalizedPricing(
                locate: () async => const GeoCurrency(
                  countryCode: 'GB',
                  currencyCode: 'GBP',
                  countryName: 'United Kingdom',
                ),
                ratesFor: (currency) async => 0.74,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CompleteFeaturesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Choose your plan'), findsOneWidget);
    expect(find.text('Scan, organize and do more with Scanella'), findsOneWidget);
    expect(find.text('Free plan'), findsOneWidget);
    expect(find.text('Pro plan'), findsOneWidget);
    expect(find.text('Get started for free'), findsOneWidget);
    expect(find.text('Unlock the full power'), findsOneWidget);
    expect(find.text('10 free scans for new users'), findsOneWidget);
    expect(find.text('Then 5 free scans every 30 days'), findsOneWidget);
    expect(find.text('Free limitations'), findsOneWidget);
    expect(find.text('Limited to 10 scans at start'), findsOneWidget);
    expect(find.text('After that, 5 scans every 30 days'), findsOneWidget);
    expect(find.text('All PDF tools'), findsNWidgets(2));
    expect(find.text('Unlimited scans'), findsOneWidget);
    expect(find.text('Advanced OCR'), findsOneWidget);
    expect(find.text('Extract text from scans'), findsOneWidget);
    expect(find.text('More export options'), findsOneWidget);
    expect(find.text('All tools'), findsNothing);
    await tester.ensureVisible(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text(offer.yearlyLabel), findsWidgets);
    expect(find.text(offer.monthlyLabel), findsOneWidget);

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text('Upgrade Now'), findsOneWidget);
  });
}
