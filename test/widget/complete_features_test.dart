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
              purchase: FakeProPurchase(offer: offer),
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

    expect(find.widgetWithText(AppBar, 'Complete features'), findsOneWidget);
    expect(find.text('Free features'), findsOneWidget);
    expect(find.text('Pro features'), findsOneWidget);
    expect(
      find.text('50 free scans for new users, then 10 every week'),
      findsOneWidget,
    );
    expect(find.text('All PDF tools'), findsNWidgets(2));
    expect(find.text('Unlimited scans'), findsOneWidget);
    expect(find.text('Advanced OCR'), findsOneWidget);
    expect(find.text('All tools'), findsNothing);
    await tester.ensureVisible(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text(offer.yearlyLabel), findsWidgets);
    expect(find.text(offer.monthlyLabel), findsOneWidget);

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Subscribe monthly'), findsOneWidget);
  });
}
