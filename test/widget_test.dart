import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to a Material app', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});
    await tester.pumpWidget(const Scan2Root());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('brand splash holds for two seconds', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});
    await tester.pumpWidget(const Scan2Root());
    await tester.pump();
    expect(find.byType(LaunchHold), findsOneWidget);
    expect(find.byType(ScanellaWordmark), findsWidgets);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byType(ScanellaWordmark), findsWidgets);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
  });
}
