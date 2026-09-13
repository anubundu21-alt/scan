import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/features/legal/legal_copy.dart';
import 'package:scan2/features/legal/legal_screen.dart';
import 'package:scan2/features/onboarding/presentation/welcome_screen.dart';

void main() {
  testWidgets('welcome has no login and opens real legal pages', (tester) async {
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('ONBOARDING')),
        ),
        GoRoute(
          path: '/legal/terms',
          builder: (_, __) =>
              const LegalScreen(document: LegalDocument.terms),
        ),
        GoRoute(
          path: '/legal/privacy',
          builder: (_, __) =>
              const LegalScreen(document: LegalDocument.privacy),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsNothing);
    expect(find.text('Sign Up'), findsNothing);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Privacy Policy'),
      find.byType(Scrollable),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Privacy Policy'), findsOneWidget);
    expect(find.textContaining('does not have a server'), findsOneWidget);
    expect(find.textContaining('Nothing is uploaded'), findsOneWidget);
  });

  testWidgets('Terms of Use page has real sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalScreen(document: LegalDocument.terms),
      ),
    );
    expect(find.widgetWithText(AppBar, 'Terms of Use'), findsOneWidget);
    expect(find.text('Your scans'), findsOneWidget);
    expect(find.textContaining('belong to you'), findsOneWidget);
  });
}
