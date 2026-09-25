import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/library/presentation/document_detail_screen.dart';
import 'package:scan2/features/library/presentation/widgets/export_sheet.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';
import 'package:scan2/features/signatures/presentation/draw_signature_screen.dart';
import 'package:scan2/features/signatures/presentation/place_signature_screen.dart';
import 'package:scan2/features/signatures/presentation/signature_pad.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('scan export to Files or Photos returns to home', () {
    expect(
      exportReturnsToHome(DocumentScreenMode.scan, ExportAction.savePdfToFiles),
      isTrue,
    );
    expect(
      exportReturnsToHome(DocumentScreenMode.scan, ExportAction.saveToPhotos),
      isTrue,
    );
    expect(
      exportReturnsToHome(DocumentScreenMode.scan, ExportAction.sharePdf),
      isFalse,
    );
    expect(
      exportReturnsToHome(
        DocumentScreenMode.editPdf,
        ExportAction.saveToPhotos,
      ),
      isFalse,
    );
  });

  GoRouter router({DocumentScreenMode mode = DocumentScreenMode.scan}) =>
      GoRouter(
        initialLocation: '/library/document/1',
        routes: [
          GoRoute(
            path: '/library/document/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return DocumentDetailScreen(documentId: id, mode: mode);
            },
          ),
          GoRoute(path: '/crop', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/camera', builder: (_, __) => const SizedBox()),
          GoRoute(
            path: '/sign/place',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is PlaceSignatureArgs) {
                return PlaceSignatureScreen(args: extra);
              }
              return const SizedBox();
            },
          ),
        ],
      );

  Widget app({
    WebDemoRepository? repo,
    DocumentScreenMode mode = DocumentScreenMode.scan,
  }) => ProviderScope(
    overrides: [
      documentRepositoryProvider.overrideWithValue(
        repo ?? WebDemoRepository(seedSampleData: true),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router(mode: mode),
    ),
  );

  testWidgets('a scan has Add page and Export, not Sign', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Add page'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Sign'), findsNothing);
    expect(find.byTooltip('Rotate page'), findsNothing);
    expect(find.text('Crop and enhance'), findsWidgets);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Merge with another scan'), findsNothing);
    expect(find.text('Extract text'), findsOneWidget);
  });

  testWidgets('Edit PDF can rotate a page', (tester) async {
    final repo = WebDemoRepository(seedSampleData: true);
    await tester.pumpWidget(app(repo: repo, mode: DocumentScreenMode.editPdf));
    await tester.pumpAndSettle();

    expect(find.text('Add pages'), findsOneWidget);
    expect(find.textContaining('Edit PDF'), findsOneWidget);
    expect(find.byTooltip('Rotate page'), findsWidgets);

    await tester.tap(find.byTooltip('Rotate page').first);
    await tester.pumpAndSettle();
    final after = await repo.getDocument(1);
    expect(after!.pages.first.adjustments.rotationTurns, 1);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Merge with another scan'), findsOneWidget);
  });

  testWidgets('Sign PDF opens the signature picker', (tester) async {
    await tester.pumpWidget(app(mode: DocumentScreenMode.signPdf));
    await tester.pumpAndSettle();

    expect(find.text('Sign'), findsOneWidget);
    expect(find.textContaining('Sign PDF'), findsOneWidget);

    await tester.tap(find.text('Sign'));
    await tester.pumpAndSettle();

    expect(find.text('Sign which page?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Page 1'));
    await tester.pumpAndSettle();

    expect(find.text('Sign this page'), findsOneWidget);
    expect(find.text('Draw a new signature'), findsOneWidget);
  });

  testWidgets('drawing on the pad leaves ink', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DrawSignatureScreen()));
    await tester.pumpAndSettle();

    final pad = find.byType(SignaturePad);
    expect(pad, findsOneWidget);

    final save = tester.widget<TactileButton>(
      find.widgetWithText(TactileButton, 'Save signature'),
    );
    expect(save.onPressed, isNull);

    await tester.drag(pad, const Offset(80, 40));
    await tester.pump();

    final saveAfter = tester.widget<TactileButton>(
      find.widgetWithText(TactileButton, 'Save signature'),
    );
    expect(saveAfter.onPressed, isNotNull);
  });

  testWidgets('captured signature PNG is transparent around the ink', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final png = await tester.runAsync(
      () => encodeSignaturePng([
        [const Offset(40, 40), const Offset(90, 48), const Offset(140, 36)],
      ], logicalSize: const Size(200, 120)),
    );
    expect(png, isNotNull);
    final decoded = img.decodeImage(png!)!;
    expect(decoded.numChannels, 4);
    expect(decoded.getPixel(0, 0).a.toInt(), lessThan(20));
    expect(
      decoded.getPixel(decoded.width - 1, decoded.height - 1).a.toInt(),
      lessThan(20),
    );

    var inkPixels = 0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        if (decoded.getPixel(x, y).a.toInt() > 80) inkPixels++;
      }
    }
    expect(inkPixels, greaterThan(20));
  });
}
