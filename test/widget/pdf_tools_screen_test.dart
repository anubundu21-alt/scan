import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/features/pro/domain/file_conversion.dart';
import 'package:scan2/features/pro/domain/pdf_page_count.dart';
import 'package:scan2/features/pro/presentation/compress_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/conversion_flow.dart';
import 'package:scan2/features/pro/presentation/merge_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/split_pdf_screen.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void main() {
  testWidgets(
    'Compress PDF offers the three levels and is honest about quality',
    (tester) async {
      await tester.pumpWidget(_app(const CompressPdfScreen()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Compress PDF'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Most'), findsOneWidget);
      expect(find.text('Choose a PDF'), findsOneWidget);
      expect(
        find.textContaining('without turning it into pictures'),
        findsOneWidget,
      );
      expect(find.textContaining('text stays selectable'), findsOneWidget);
      expect(
        find.textContaining('deleted as soon as it comes back'),
        findsOneWidget,
      );
      expect(find.textContaining('iLove'), findsNothing);
      expect(
        find.textContaining('not switched on in this build'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Compress PDF says so before you pick a file if converting is off',
    (tester) async {
      await tester.pumpWidget(
        _app(
          CompressPdfScreen(
            converter: FileConverter(
              service: const ConversionService.withoutHost(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('not switched on in this build'),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping Most selects the hardest squeeze', (tester) async {
    await tester.pumpWidget(_app(const CompressPdfScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Most'));
    await tester.pump();

    final group = tester.widget<RadioGroup<CompressionLevel>>(
      find.byType(RadioGroup<CompressionLevel>),
    );
    expect(group.groupValue, CompressionLevel.hard);
  });

  testWidgets('Merge PDF will not run until two files are in', (tester) async {
    await tester.pumpWidget(_app(const MergePdfScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Merge PDF'), findsOneWidget);
    expect(find.text('Choose PDFs'), findsOneWidget);
    expect(find.textContaining('two or more PDFs'), findsWidgets);
    expect(find.textContaining('the top goes first'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Pick at least two PDFs'),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('iLove'), findsNothing);
  });

  testWidgets('Split PDF starts with a pick, then shows the page range', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SplitPdfScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Split PDF'), findsOneWidget);
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.text('Keep pages'), findsNothing);
    expect(find.text('Pages to keep'), findsNothing);
    expect(find.textContaining('copied across as they are'), findsOneWidget);
    expect(
      find.textContaining('deleted as soon as it comes back'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Split PDF shows keep-pages once a file is in, and can cut into files',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const SplitPdfScreen(
            seededName: 'Invoice.pdf',
            seededPageCount: 8,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invoice.pdf'), findsOneWidget);
      expect(find.text('8 pages'), findsOneWidget);
      expect(find.text('Keep pages'), findsOneWidget);
      expect(find.text('Cut into files'), findsOneWidget);
      expect(find.text('Pages to keep'), findsOneWidget);
      expect(find.textContaining('This PDF has 8 pages'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Split PDF'), findsOneWidget);
      expect(find.text('Choose a PDF'), findsNothing);

      await tester.tap(find.text('Cut into files'));
      await tester.pumpAndSettle();

      expect(find.text('Pages per file'), findsOneWidget);
      expect(find.textContaining('Cut all 8 pages'), findsOneWidget);
      expect(find.text('Pages to keep'), findsNothing);
    },
  );

  test('page ranges are the way someone would write them', () {
    expect(isPageRange('1-3, 8'), isTrue);
    expect(isPageRange('4'), isTrue);
    expect(isPageRange('1-3,8,11-12'), isTrue);
    expect(isPageRange(''), isFalse);
    expect(isPageRange('all of them'), isFalse);
    expect(isPageRange('1-'), isFalse);
    expect(isPageRange('-4'), isFalse);
    expect(isPageRange('1;2'), isFalse);
  });

  test('PDF page objects are counted, the Pages tree node is not', () {
    final pdf = latin1.encode(
      '%PDF-1.4\n'
      '1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj\n'
      '2 0 obj<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>endobj\n'
      '3 0 obj<< /Type /Page /Parent 2 0 R >>endobj\n'
      '4 0 obj<< /Type/Page /Parent 2 0 R >>endobj\n',
    );
    expect(countPdfPages(pdf), 2);
    expect(defaultKeepRange(2), '1-2');
    expect(defaultKeepRange(0), '1-3');
    expect(defaultKeepRange(12), '1-12');
  });

  test('file sizes read the way a person would say them', () {
    expect(formatBytes(400), '400 bytes');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(12 * 1024), '12 KB');
    expect(formatBytes((1.4 * 1024 * 1024).round()), '1.4 MB');
  });

  test('compress options wire the three levels the service knows', () {
    expect(
      const ConversionOptions(compression: CompressionLevel.light).toWire(),
      {'compressionLevel': 'low'},
    );
    expect(
      const ConversionOptions(compression: CompressionLevel.balanced).toWire(),
      {'compressionLevel': 'recommended'},
    );
    expect(
      const ConversionOptions(compression: CompressionLevel.hard).toWire(),
      {'compressionLevel': 'extreme'},
    );
  });

  test('split by ranges asks for one file, not a zip of one', () {
    expect(const ConversionOptions(ranges: '1-3, 8').toWire(), {
      'ranges': '1-3, 8',
      'mergeAfter': true,
    });
    expect(const ConversionOptions(everyPages: 2).toWire(), {'everyPages': 2});
  });
}
