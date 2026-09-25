import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/features/pro/presentation/images_to_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/pdf_to_image_screen.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void main() {
  testWidgets('PDF to JPG offers JPG and PNG and a file pick', (tester) async {
    await tester.pumpWidget(_app(const PdfToImageScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'PDF to JPG'), findsOneWidget);
    expect(find.text('JPG'), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.textContaining('nothing is uploaded'), findsOneWidget);
    expect(
      find.textContaining('not in this version of Scanella yet'),
      findsNothing,
    );

    await tester.tap(find.text('PNG'));
    await tester.pump();
  });

  testWidgets('Image to PDF asks for photos and stays on device', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ImagesToPdfScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Image to PDF'), findsOneWidget);
    expect(find.text('Choose photos'), findsOneWidget);
    expect(find.textContaining('nothing is uploaded'), findsOneWidget);
  });
}
