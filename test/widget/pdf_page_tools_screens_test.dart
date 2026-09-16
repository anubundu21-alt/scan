import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/features/pro/presentation/pdf_page_tool_screens.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void main() {
  testWidgets('Rotate PDF offers 90 180 270 and a file pick', (tester) async {
    await tester.pumpWidget(_app(const PdfRotateScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Rotate PDF'), findsOneWidget);
    expect(find.text('90°'), findsOneWidget);
    expect(find.text('180°'), findsOneWidget);
    expect(find.text('270°'), findsOneWidget);
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.textContaining('nothing is uploaded'), findsOneWidget);
    expect(find.textContaining('not in this version of Scanella yet'), findsNothing);

    await tester.tap(find.text('180°'));
    await tester.pump();
  });

  testWidgets('Page numbers explains 1 / n and a file pick', (tester) async {
    await tester.pumpWidget(_app(const PdfPageNumbersScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Page numbers'), findsOneWidget);
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.textContaining('1 / n'), findsOneWidget);
    expect(find.textContaining('not in this version of Scanella yet'), findsNothing);
  });

  testWidgets('Watermark starts with CONFIDENTIAL and a file pick', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PdfWatermarkScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Watermark'), findsOneWidget);
    expect(find.text('CONFIDENTIAL'), findsWidgets);
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.textContaining('not in this version of Scanella yet'), findsNothing);
  });

  testWidgets('Unlock PDF asks for a password and a file pick', (tester) async {
    await tester.pumpWidget(_app(const PdfUnlockScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Unlock PDF'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.textContaining('not in this version of Scanella yet'), findsNothing);
  });
}
