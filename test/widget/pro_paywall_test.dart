import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:scan2/features/pro/presentation/pro_paywall.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('paywall shows yearly and monthly prices in local currency', (
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
        child: MaterialApp(theme: AppTheme.light, home: const ProPaywall()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Go Pro'), findsOneWidget);
    expect(find.byType(ProMark), findsWidgets);
    expect(find.textContaining('United Kingdom'), findsNothing);
    expect(find.textContaining('Prices in'), findsNothing);
    expect(find.textContaining('Poland'), findsNothing);
    expect(find.textContaining('reinstall'), findsNothing);
    expect(find.textContaining('Apple ID'), findsWidgets);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text(offer.yearlyLabel), findsWidgets);
    expect(find.text(offer.monthlyLabel), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Upgrade Now'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Unlimited scans'), findsWidgets);
    expect(find.text('All PDF tools'), findsWidgets);
    expect(find.text('Advanced OCR'), findsWidgets);
    expect(find.text('All tools'), findsNothing);
  });

  testWidgets('subscribe unlocks Pro', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final offer = LocalizedPricing.formatOffer(
      currencyCode: 'USD',
      countryCode: 'US',
      countryName: 'United States',
      usdToLocal: 1,
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
                  countryCode: 'US',
                  currencyCode: 'USD',
                  countryName: 'United States',
                ),
                ratesFor: (_) async => 1,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProPaywall(context),
                child: const Text('Open pro'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open pro'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Upgrade Now'),
      80,
      scrollable: find.descendant(
        of: find.byType(ProPaywall),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Upgrade Now'));
    await tester.pumpAndSettle();

    expect(find.text('Scanella Pro'), findsNothing);
  });

  testWidgets('Close dismisses the paywall', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proProvider.overrideWith(
            (ref) => ProController(
              purchase: FakeProPurchase(),
              pricing: LocalizedPricing(
                locate: () async => const GeoCurrency(
                  countryCode: 'US',
                  currencyCode: 'USD',
                  countryName: 'United States',
                ),
                ratesFor: (_) async => 1,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProPaywall(context),
                child: const Text('Open pro'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open pro'));
    await tester.pumpAndSettle();

    expect(find.text('Go Pro'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Go Pro'), findsNothing);
    expect(find.text('Open pro'), findsOneWidget);
  });

  testWidgets('paywall explains StoreKit miss without asking to add product ids', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proProvider.overrideWith(
            (ref) => ProController(
              purchase: FakeProPurchase(
                trialUsed: true,
                introOffer: false,
                courtesyUsed: true,
              ),
              pricing: LocalizedPricing(
                locate: () async => const GeoCurrency(
                  countryCode: 'PL',
                  currencyCode: 'PLN',
                  countryName: 'Poland',
                ),
                ratesFor: (_) async => 3.71,
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ProPaywall()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upgrade Now'), findsOneWidget);
    expect(find.textContaining('Estimated'), findsNothing);
    expect(find.textContaining('Reinstalling TestFlight will not fix this'), findsOneWidget);
    expect(find.textContaining('Ready to Submit'), findsOneWidget);
    expect(find.textContaining('Add auto-renewable'), findsNothing);
    expect(find.textContaining('Bad state'), findsNothing);
  });

  testWidgets('paywall shows weekly reset only for free users', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quotaStoreProvider.overrideWithValue(
            MemoryQuotaStore(
              used: ScanQuota.weeklyLimit,
              starterDone: true,
              periodStartMs: DateTime(2026, 9, 12, 12, 31).millisecondsSinceEpoch,
            ),
          ),
          proProvider.overrideWith(
            (ref) => ProController(
              purchase: FakeProPurchase(),
              pricing: LocalizedPricing(
                locate: () async => const GeoCurrency(
                  countryCode: 'US',
                  currencyCode: 'USD',
                  countryName: 'United States',
                ),
                ratesFor: (_) async => 1,
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ProPaywall()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Your ${ScanQuota.weeklyLimit} free scans reset'),
      findsOneWidget,
    );
  });

  testWidgets('paywall hides weekly reset for Pro', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quotaStoreProvider.overrideWithValue(
            MemoryQuotaStore(
              used: ScanQuota.weeklyLimit,
              starterDone: true,
              periodStartMs: DateTime(2026, 9, 12, 12, 31).millisecondsSinceEpoch,
            ),
          ),
          proProvider.overrideWith(
            (ref) => ProController(
              purchase: FakeProPurchase(entitled: true),
              pricing: LocalizedPricing(
                locate: () async => const GeoCurrency(
                  countryCode: 'US',
                  currencyCode: 'USD',
                  countryName: 'United States',
                ),
                ratesFor: (_) async => 1,
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ProPaywall()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You have Scanella Pro'), findsOneWidget);
    expect(find.textContaining('free scans reset'), findsNothing);
    expect(find.textContaining('Scanella Pro lets you keep scanning'), findsNothing);
  });
}
