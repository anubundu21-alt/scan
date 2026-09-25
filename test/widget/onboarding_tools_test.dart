import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpOnboarding(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(path: '/library', builder: (_, __) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goToToolsPage(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  testWidgets('onboarding has a tools page after the scan pages', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    expect(find.textContaining('Scan Anything'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Clean Pages'), findsOneWidget);
    expect(find.text('Meeting Notes'), findsOneWidget);
    expect(find.text('Auto Crop'), findsOneWidget);
    expect(find.text('Enhance Automatically'), findsOneWidget);
    expect(find.text('Clear & Readable'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PDF tools'), findsOneWidget);
    expect(find.textContaining('one'), findsWidgets);
    expect(find.textContaining('place'), findsOneWidget);
    expect(find.text('Image to PDF'), findsOneWidget);
    expect(find.text('PDF to JPG'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('tools page grid sits fully above Get Started on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpOnboarding(tester);
    await goToToolsPage(tester);

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Split PDF'), findsOneWidget);
    expect(find.text('Sign PDF'), findsOneWidget);
    expect(find.text('Extract'), findsOneWidget);

    final cta = tester.getRect(find.text('Get Started'));
    for (final label in ['Split PDF', 'Sign PDF', 'Extract', 'PDF to JPG']) {
      final tile = tester.getRect(find.text(label));
      expect(
        tile.bottom,
        lessThanOrEqualTo(cta.top),
        reason: '$label was clipped under Get Started',
      );
      expect(tile.top, greaterThan(0), reason: '$label is off the top');
    }
    expect(tester.takeException(), isNull);
  });
}
