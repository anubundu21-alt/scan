import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/features/pro/presentation/pdf_page_tool_screens.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

Uint8List _jpeg({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    image.setPixelRgb(pixel.x, pixel.y, 210, 12, 18);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

void main() {
  testWidgets('Rotate PDF asks to pick a file before showing pages', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PdfRotateScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Rotate PDF'), findsOneWidget);
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
    expect(find.text('90°'), findsNothing);
    expect(find.textContaining('download when it looks right'), findsOneWidget);
    expect(find.textContaining('not in this version of Scanella yet'), findsNothing);
  });

  testWidgets('Rotate PDF shows the page, turns it live, and waits for Download', (
    tester,
  ) async {
    final page = _jpeg(width: 80, height: 100);
    await tester.pumpWidget(
      _app(PdfRotateScreen(initialPages: [page], initialStem: 'scan')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 0);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Rotate'), findsOneWidget);
    expect(find.text('Choose a PDF'), findsNothing);

    await tester.tap(find.text('Rotate'));
    await tester.pump();

    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('Rotate PDF names the current page when there are several', (
    tester,
  ) async {
    final a = _jpeg(width: 40, height: 50);
    final b = _jpeg(width: 40, height: 50);
    await tester.pumpWidget(
      _app(PdfRotateScreen(initialPages: [a, b])),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
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
