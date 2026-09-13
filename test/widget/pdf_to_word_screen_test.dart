import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/file_conversion.dart';
import 'package:scan2/features/pro/presentation/pdf_to_word_screen.dart';
import 'package:scan2/features/pro/presentation/word_to_pdf_screen.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('PDF to Word is an upload screen, not a library of done PDFs', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(
            WebDemoRepository(seedSampleData: true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PdfToWordScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'PDF to Word'), findsOneWidget);
    expect(find.text('Upload a PDF'), findsOneWidget);
    expect(find.text('Your PDFs'), findsNothing);
    expect(find.text('Offer letter.pdf'), findsNothing);
    expect(find.text('Convert to Word'), findsNothing);
    expect(find.text('Rental agreement'), findsNothing);
    // The screen has to be straight about the fact that converting sends the
    // file somewhere, and about what happens to it afterwards.
    expect(find.textContaining('needs a connection'), findsOneWidget);
    expect(
      find.textContaining('deleted as soon as it comes back'),
      findsOneWidget,
    );

    final uploadCard = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.color == Brand.accent &&
              decoration.borderRadius ==
                  BorderRadius.circular(Brand.radiusCard);
        });
    expect(uploadCard, isNotNull);
  });

  // A build with no converter host would otherwise look fine until someone
  // had picked a file and waited.
  testWidgets('a build with no converter says so before you pick a file', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(
            WebDemoRepository(seedSampleData: true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PdfToWordScreen(
            converter: FileConverter(
              service: const ConversionService.withoutHost(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not switched on in this build'),
      findsOneWidget,
    );
  });

  // This is the screen someone gets from TestFlight, so it is the one that
  // has to be able to convert.
  testWidgets('the screen as shipped offers to convert, not an apology', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(
            WebDemoRepository(seedSampleData: true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PdfToWordScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('not switched on in this build'), findsNothing);
    expect(find.text('Upload a PDF'), findsOneWidget);
  });

  testWidgets('a build with a converter shows no such warning', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(
            WebDemoRepository(seedSampleData: true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PdfToWordScreen(
            converter: FileConverter(
              service: ConversionService(
                baseUrl: Uri.parse('https://example.com'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('not switched on in this build'), findsNothing);
    expect(find.text('Upload a PDF'), findsOneWidget);
  });

  testWidgets('Word to PDF takes a document, not a scan', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(
            WebDemoRepository(seedSampleData: true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WordToPdfScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Word to PDF'), findsOneWidget);
    expect(find.text('Upload a document'), findsOneWidget);
    expect(find.text('DOC, DOCX, ODT or RTF from Files.'), findsOneWidget);
    // Nothing in the library is a Word file, so there is no list to offer.
    expect(find.text('Offer letter.pdf'), findsNothing);
    expect(find.textContaining('needs a connection'), findsOneWidget);
  });
}
