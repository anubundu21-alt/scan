import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/home/presentation/all_tools_screen.dart';
import 'package:scan2/features/home/presentation/tool_art.dart';
import 'package:scan2/features/home/presentation/home_hero.dart';
import 'package:scan2/features/home/presentation/home_shortcuts.dart';
import 'package:scan2/features/home/presentation/home_shell.dart';
import 'package:scan2/features/legal/legal_copy.dart';
import 'package:scan2/features/legal/legal_screen.dart';
import 'package:scan2/features/library/presentation/help_screen.dart';
import 'package:scan2/features/library/presentation/documents_view.dart';
import 'package:scan2/features/library/presentation/scan_picker_screen.dart';
import 'package:scan2/features/library/presentation/sign_pdf_screen.dart';
import 'package:scan2/features/library/presentation/document_detail_screen.dart';
import 'package:scan2/features/pro/presentation/coming_soon_tool_screen.dart';
import 'package:scan2/features/pro/presentation/complete_features_screen.dart';
import 'package:scan2/features/pro/presentation/pdf_to_word_screen.dart';
import 'package:scan2/features/pro/presentation/word_to_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/compress_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/merge_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/split_pdf_screen.dart';
import 'package:scan2/features/pro/presentation/pdf_to_image_screen.dart';
import 'package:scan2/features/pro/presentation/images_to_pdf_screen.dart';
import 'package:scan2/features/library/presentation/trash_screen.dart';
import 'package:scan2/features/settings/presentation/settings_screen.dart';
import 'package:scan2/features/pro/domain/localized_pricing.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:scan2/features/pro/presentation/pro_paywall.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GoRouter testRouter() => GoRouter(
    initialLocation: '/library',
    routes: [
      GoRoute(path: '/library', builder: (_, __) => const HomeShell()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/camera', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/trash', builder: (_, __) => const TrashScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
      GoRoute(
        path: '/features',
        builder: (_, __) => const CompleteFeaturesScreen(),
      ),
      GoRoute(
        path: '/pdf/edit',
        builder: (_, __) =>
            const ScanPickerScreen(mode: DocumentScreenMode.editPdf),
      ),
      GoRoute(path: '/pdf/sign', builder: (_, __) => const SignPdfScreen()),
      GoRoute(path: '/pdf/word', builder: (_, __) => const PdfToWordScreen()),
      GoRoute(path: '/word/pdf', builder: (_, __) => const WordToPdfScreen()),
      GoRoute(
        path: '/pdf/compress',
        builder: (_, __) => const CompressPdfScreen(),
      ),
      GoRoute(path: '/pdf/merge', builder: (_, __) => const MergePdfScreen()),
      GoRoute(path: '/pdf/split', builder: (_, __) => const SplitPdfScreen()),
      GoRoute(path: '/pdf/images', builder: (_, __) => const PdfToImageScreen()),
      GoRoute(
        path: '/pdf/from-images',
        builder: (_, __) => const ImagesToPdfScreen(),
      ),
      GoRoute(path: '/tools', builder: (_, __) => const AllToolsScreen()),
      GoRoute(
        path: '/tools/unavailable',
        builder: (_, state) {
          final extra = state.extra;
          if (extra is ComingSoonTool) {
            return ComingSoonToolScreen(tool: extra);
          }
          return const ComingSoonToolScreen(
            tool: ComingSoonTool(
              title: 'Coming soon',
              detail: 'This conversion is not in this version of Scanella yet.',
            ),
          );
        },
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (_, __) => const LegalScreen(document: LegalDocument.terms),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, __) => const LegalScreen(document: LegalDocument.privacy),
      ),
    ],
  );

  Widget app(GoRouter router, {List<Override> extra = const []}) =>
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(
            WebDemoRepository(seedSampleData: true),
          ),
          quotaStoreProvider.overrideWithValue(MemoryQuotaStore()),
          ...extra,
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );

  List<Override> withPro() => [
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
  ];

  Future<void> tapHomeTool(WidgetTester tester, String label) async {
    await tester.tap(find.text('All tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(label),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('menu opens a drawer with Settings and About', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget, reason: 'bottom bar');
    expect(find.text('About'), findsNothing);

    expect(find.text('Scan from photos'), findsOneWidget);
    expect(find.text('Import from file'), findsOneWidget);
    expect(find.text('Scan from camera'), findsOneWidget);
    expect(find.text('All tools'), findsOneWidget);
    expect(find.text('From photos'), findsNothing);
    expect(find.text('Upload PDF'), findsNothing);
    expect(find.text('Extract text'), findsNothing);
    expect(find.text('Sign PDF'), findsNothing);
    expect(find.text('PDF to Word'), findsNothing);
    expect(find.text('Word to PDF'), findsNothing);
    expect(find.text('Compress PDF'), findsNothing);
    expect(find.text('Merge PDF'), findsNothing);
    expect(find.text('Split PDF'), findsNothing);
    expect(find.text('ID card'), findsNothing);
    expect(find.text('Import files'), findsNothing);
    expect(find.text('Recent scans'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('Your best document scanner'), findsOneWidget);
    expect(find.text('Turn your documents\ninto clarity'), findsOneWidget);
    expect(find.byType(ScanellaWordmark), findsWidgets);
    expect(find.text('Search'), findsNothing);
    expect(find.text('Search names or text'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Search names or text')).dy,
      greaterThan(tester.getBottomLeft(find.text('Recent scans')).dy),
    );
    final headline = tester.widget<Text>(
      find.text('Turn your documents\ninto clarity'),
    );
    expect(headline.style?.fontSize, 22);
    expect(headline.style?.decoration, isNot(TextDecoration.underline));
    expect(find.text('Scan. Save. Organize. Anytime.'), findsOneWidget);
    expect(find.text('Everything you scan lives here'), findsNothing);
    final hero = tester.getSize(find.byType(HomeHero));
    expect(hero.height, lessThan(210));
    expect(tester.getSize(find.byType(HomeHeroArt)).height, 94);
    expect(
      tester.getTopLeft(find.text('Turn your documents\ninto clarity')).dy -
          tester.getBottomLeft(find.text('Your best document scanner')).dy,
      greaterThan(14),
    );

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('ID card')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Edit PDF')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Sign PDF')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Scanella Pro'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Favorites'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Complete features'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('All documents'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('IDs')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Receipts')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Invoices')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Untagged')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Duplicates')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Recent')),
      findsNothing,
    );
    expect(find.byType(FilterChip), findsNothing);

    final drawerScroll = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.descendant(of: find.byType(Drawer), matching: find.text('Settings')),
      80,
      scrollable: drawerScroll,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Settings')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.descendant(of: find.byType(Drawer), matching: find.text('About')),
      80,
      scrollable: drawerScroll,
    );

    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('About')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Trash')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Help')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Settings')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('Use the in-app camera'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('App lock'), 200);
    expect(find.text('App lock'), findsOneWidget);
  });

  testWidgets('About from the menu shows version, not licences', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    final about = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('About'),
    );
    await tester.scrollUntilVisible(
      about,
      120,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(about);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(ScanellaAboutScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'About'), findsOneWidget);
    expect(find.byType(ScanellaAppMark), findsWidgets);
    expect(find.text(ScanellaAboutScreen.legalese), findsOneWidget);
    expect(find.byType(AboutDialog), findsNothing);
    expect(find.byType(LicensePage), findsNothing);
    expect(find.text('View licenses'), findsNothing);
    expect(find.text('Powered by Flutter'), findsNothing);
    expect(find.text('_fe_analyzer_shared'), findsNothing);
  });

  testWidgets('bottom Settings opens the settings page', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('Use the in-app camera'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Privacy Policy'),
      find.byType(ListView),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Privacy Policy'), findsOneWidget);
    expect(find.textContaining('does not have a server'), findsOneWidget);
  });

  testWidgets('scan button shows Scan me under the scanner', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Scan me'), findsOneWidget);
    expect(find.text('Scan me'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byTooltip('Scan me'),
        matching: find.text('Scan me'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byTooltip('Scan me'),
        matching: find.byIcon(Icons.document_scanner_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Scan me')).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.descendant(
                of: find.byTooltip('Scan me'),
                matching: find.byIcon(Icons.document_scanner_rounded),
              ),
            )
            .dy,
      ),
    );
  });

  testWidgets('scan button is a rounded square, not a circle', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    final fab = tester.widgetList<Container>(find.byType(Container)).firstWhere(
      (container) {
        return container.constraints?.maxWidth == 68 &&
            container.constraints?.maxHeight == 68 &&
            container.decoration is BoxDecoration;
      },
    );
    final decoration = fab.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.rectangle);
    expect(decoration.borderRadius, BorderRadius.circular(Brand.radiusFab + 4));

    final bar = tester.widget<BottomAppBar>(find.byType(BottomAppBar));
    expect(bar.shape, isA<AutomaticNotchedShape>());
    expect(bar.shape, isNot(isA<CircularNotchedRectangle>()));
  });

  testWidgets('New folder uses solid brand green', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    expect(find.text('On device'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'New folder'),
      80,
      scrollable: find.byType(Scrollable).first,
    );

    final newFolder = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'New folder'),
    );
    final style = newFolder.style;
    expect(style?.backgroundColor?.resolve({}), Brand.accent);
    expect(style?.foregroundColor?.resolve({}), Colors.white);

    final size = tester.getSize(find.widgetWithText(FilledButton, 'New folder'));
    expect(size.height, lessThan(40));
    final label = tester.widget<Text>(
      find.descendant(
        of: find.widgetWithText(FilledButton, 'New folder'),
        matching: find.text('New folder'),
      ),
    );
    expect(label.style?.fontSize, 12);
  });

  testWidgets('Scanella wordmark sits next to the drawer, not centered', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    final menu = tester.getRect(find.byTooltip('Menu'));
    final mark = tester.getRect(
      find.descendant(
        of: find.byType(DocumentsView),
        matching: find.byType(ScanellaWordmark),
      ),
    );
    expect(mark.left, lessThan(menu.right + 4));
    expect(mark.left, greaterThan(menu.left));
  });

  testWidgets('each document card has a more menu, not an Upload button', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Offer letter.pdf'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Upload'), findsNothing);
    expect(find.byTooltip('More'), findsWidgets);
  });

  testWidgets('scan more menu omits Tags and keeps Move to Trash reachable', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Offer letter.pdf'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();

    expect(find.text('Tags'), findsNothing);
    expect(find.text('Share PDF'), findsOneWidget);
    await tester.ensureVisible(find.text('Move to Trash'));
    expect(find.text('Move to Trash'), findsOneWidget);

    await tester.tap(find.text('Move to Trash'));
    await tester.pumpAndSettle();

    expect(find.textContaining('to Trash?'), findsOneWidget);
  });

  testWidgets('home shortcuts are compact cards plus a quiet All tools', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    final photos = tester.widget<Text>(find.text('Scan from photos')).style;
    expect(photos?.fontSize, closeTo(13, 0.1));
    expect(photos?.fontWeight, FontWeight.w800);

    final card = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.color == HomeShortcuts.photosWash &&
              decoration.borderRadius ==
                  BorderRadius.circular(Brand.radiusCard);
        });
    expect(card, isNotNull);
    expect(HomeShortcuts.photosWash, const Color(0xFFD9EAFF));
    expect(HomeShortcuts.fileWash, const Color(0xFFE7DEFF));
    expect(HomeShortcuts.cameraWash, const Color(0xFFFFE0CC));
    expect(HomeShortcuts.toolsWash, const Color(0xFFE5F7F0));
    expect(HomeShortcuts.toolsInk, const Color(0xFF19A974));
    expect(find.byIcon(Icons.photo_camera_rounded), findsWidgets);
    expect(find.text('PDF, text, sign, convert and more'), findsOneWidget);
    Rect washRect(Color wash) {
      final container = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere((candidate) {
            final decoration = candidate.decoration;
            return decoration is BoxDecoration && decoration.color == wash;
          });
      return tester.getRect(find.byWidget(container));
    }

    final photosRect = washRect(HomeShortcuts.photosWash);
    final fileRect = washRect(HomeShortcuts.fileWash);
    final cameraRect = washRect(HomeShortcuts.cameraWash);
    expect(photosRect.height, closeTo(fileRect.height, 0.5));
    expect(photosRect.height, closeTo(cameraRect.height, 0.5));
    expect(photosRect.top, closeTo(fileRect.top, 0.5));
    expect(photosRect.top, closeTo(cameraRect.top, 0.5));
    expect(photosRect.bottom, closeTo(fileRect.bottom, 0.5));
    expect(photosRect.bottom, closeTo(cameraRect.bottom, 0.5));
    expect(
      tester.getTopLeft(find.text('All tools')).dy - photosRect.bottom,
      greaterThan(24),
    );
    expect(HomeHeroArt.edgeNavy, const Color(0xFF101D41));
    final heroFill = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration && decoration.color == Brand.hero;
        });
    expect(heroFill, isNotNull);
  });

  testWidgets('Trash in the menu opens the trash page', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    final drawerScroll = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.descendant(of: find.byType(Drawer), matching: find.text('Trash')),
      80,
      scrollable: drawerScroll,
    );
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Trash')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Trash'), findsOneWidget);
  });

  testWidgets('Upload PDF from home is not a scan picker', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import from file'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Edit PDF'), findsNothing);
    expect(
      find.text('Scan a document first, then come back here.'),
      findsNothing,
    );
    expect(
      find.text('Importing is available on iOS and Android.'),
      findsOneWidget,
    );
  });

  testWidgets('Sign PDF asks to upload and lists existing PDFs, not scans', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'Sign PDF');

    expect(find.widgetWithText(AppBar, 'Sign PDF'), findsOneWidget);
    expect(find.text('Upload a PDF'), findsOneWidget);
    expect(find.text('Your PDFs'), findsOneWidget);
    expect(find.text('Offer letter.pdf'), findsOneWidget);
    expect(find.text('Rental agreement'), findsNothing);
    expect(
      find.text('Scan a document first, then come back here.'),
      findsNothing,
    );
  });

  testWidgets('PDF to Word opens without Pro', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('PDF to Word'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('PDF to Word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF to Word'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'PDF to Word'), findsOneWidget);
    expect(find.text('Scanella Pro'), findsNothing);
  });

  testWidgets('PDF to Word opens when Pro is on', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(
      app(
        router,
        extra: [
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('All tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('PDF to Word'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('PDF to Word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF to Word'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'PDF to Word'), findsOneWidget);
    expect(find.text('Upload a PDF'), findsOneWidget);
    expect(find.text('Your PDFs'), findsNothing);
    expect(find.text('Offer letter.pdf'), findsNothing);
    expect(find.text('Rental agreement'), findsNothing);
  });

  testWidgets('Word to PDF opens without Pro', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Word to PDF'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Word to PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Word to PDF'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Word to PDF'), findsOneWidget);
    expect(find.text('Scanella Pro'), findsNothing);
  });

  testWidgets('Word to PDF opens when Pro is on', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(
      app(
        router,
        extra: [
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('All tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Word to PDF'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Word to PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Word to PDF'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Word to PDF'), findsOneWidget);
    expect(find.text('Upload a document'), findsOneWidget);
  });

  testWidgets('Compress PDF opens without Pro', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'Compress PDF');

    expect(find.widgetWithText(AppBar, 'Compress PDF'), findsOneWidget);
    expect(find.text('Scanella Pro'), findsNothing);
  });

  testWidgets('Compress PDF opens when Pro is on', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router, extra: withPro()));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'Compress PDF');

    expect(find.widgetWithText(AppBar, 'Compress PDF'), findsOneWidget);
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Less'), findsOneWidget);
    expect(find.text('Most'), findsOneWidget);
  });

  testWidgets('Merge PDF opens without Pro', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'Merge PDF');

    expect(find.widgetWithText(AppBar, 'Merge PDF'), findsOneWidget);
    expect(find.text('Scanella Pro'), findsNothing);
  });

  testWidgets('Merge PDF opens when Pro is on', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router, extra: withPro()));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'Merge PDF');

    expect(find.widgetWithText(AppBar, 'Merge PDF'), findsOneWidget);
    expect(find.text('Choose PDFs'), findsOneWidget);
    expect(find.text('Pick at least two PDFs'), findsOneWidget);
  });

  testWidgets('Split PDF opens without Pro', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'Split PDF');

    expect(find.widgetWithText(AppBar, 'Split PDF'), findsOneWidget);
    expect(find.text('Scanella Pro'), findsNothing);
  });

  testWidgets('Split PDF opens when Pro is on', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router, extra: withPro()));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'Split PDF');

    expect(find.widgetWithText(AppBar, 'Split PDF'), findsOneWidget);
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.text('Keep pages'), findsNothing);
    expect(find.text('Pages to keep'), findsNothing);
  });

  testWidgets('ID card from home opens the camera route', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('ID card'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('ID card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ID card'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/camera');
  });

  testWidgets('Scan from camera on home opens the camera route', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan from camera'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/camera');
  });

  testWidgets('Scan from camera asks for Pro when weekly scans are used', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(
      app(
        router,
        extra: [
          quotaStoreProvider.overrideWithValue(
            MemoryQuotaStore(
              used: ScanQuota.weeklyLimit,
              starterDone: true,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan from camera'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('${ScanQuota.weeklyLimit} free scans used'), findsOneWidget);
    expect(find.text('See Scanella Pro'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, isNot('/camera'));
  });

  testWidgets('All tools lists every converter in its category', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All tools'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'All tools'), findsOneWidget);
    expect(find.text('PDF, text, sign, convert and more'), findsWidgets);
    expect(find.text('On device'), findsNothing);
    expect(find.text('Search document tools...'), findsNothing);
    expect(find.text('CONVERT DOCUMENTS'), findsNothing);
    expect(find.text('EDIT & ORGANIZE'), findsNothing);
    expect(find.text('VIEW & EXTRACT'), findsNothing);
    expect(find.text('PDF to Word'), findsOneWidget);
    expect(find.byType(AllToolsMark), findsWidgets);
    expect(find.text('Word to PDF'), findsOneWidget);
    expect(find.text('Image to PDF'), findsOneWidget);
    expect(find.text('Excel to PDF'), findsOneWidget);
    expect(find.text('PowerPoint to PDF'), findsOneWidget);
    expect(find.text('PDF to Excel'), findsOneWidget);
    expect(find.text('PDF to PowerPoint'), findsOneWidget);
    expect(find.text('Merge PDF'), findsOneWidget);
    expect(find.text('Split PDF'), findsOneWidget);
    expect(find.text('Compress PDF'), findsOneWidget);
    expect(find.text('PDF to JPG'), findsOneWidget);
    expect(find.text('PDF to JPG/PNG'), findsNothing);
    expect(find.text('Page numbers'), findsOneWidget);
    expect(find.text('Watermark'), findsOneWidget);
    expect(find.text('Rotate PDF'), findsOneWidget);
    expect(find.text('Unlock PDF'), findsOneWidget);
    expect(find.text('Extract text'), findsOneWidget);
    expect(find.text('Sign PDF'), findsOneWidget);
    expect(find.text('ID card'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('PDF to Word')).dy,
      lessThan(tester.getTopLeft(find.text('Excel to PDF')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Word to PDF')).dy,
      lessThan(tester.getTopLeft(find.text('Compress PDF')).dy),
    );
    expect(find.text('Popular'), findsNothing);
    expect(
      find.text('Split by page ranges or into one PDF per page'),
      findsNothing,
    );
  });

  testWidgets('Excel to PDF is listed and says it is not built yet', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'Excel to PDF');

    expect(find.widgetWithText(AppBar, 'Excel to PDF'), findsOneWidget);
    expect(
      find.textContaining('not in this version of Scanella yet'),
      findsOneWidget,
    );
    expect(find.text('Scanella Pro'), findsNothing);
  });

  testWidgets('PDF to JPG opens without Pro', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'PDF to JPG');

    expect(find.widgetWithText(AppBar, 'PDF to JPG'), findsOneWidget);
    expect(find.text('Scanella Pro'), findsNothing);
  });

  testWidgets('Image to PDF opens without Pro', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'Image to PDF');

    expect(find.widgetWithText(AppBar, 'Image to PDF'), findsOneWidget);
    expect(find.text('Scanella Pro'), findsNothing);
  });

  testWidgets('PDF to JPG opens when Pro is on', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router, extra: withPro()));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'PDF to JPG');

    expect(find.widgetWithText(AppBar, 'PDF to JPG'), findsOneWidget);
    expect(find.text('JPG'), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.textContaining('not in this version of Scanella yet'), findsNothing);
  });

  testWidgets('Image to PDF opens when Pro is on', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router, extra: withPro()));
    await tester.pumpAndSettle();

    await tapHomeTool(tester, 'Image to PDF');

    expect(find.widgetWithText(AppBar, 'Image to PDF'), findsOneWidget);
    expect(find.text('Choose photos'), findsOneWidget);
    expect(find.textContaining('not in this version of Scanella yet'), findsNothing);
  });

  testWidgets('drawer shows remaining free scans, not chips under search', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(
      app(
        router,
        extra: [
          quotaStoreProvider.overrideWithValue(MemoryQuotaStore(used: 3)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('Favorites'), findsNothing);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '${ScanQuota.starterLimit - 3} of ${ScanQuota.starterLimit} free scans left',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Favorites'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('Private')),
      findsOneWidget,
    );
  });

  testWidgets('Complete features lists free, Pro, and prices', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Complete features'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Choose your plan'), findsOneWidget);
    expect(find.text('Free plan'), findsOneWidget);
    expect(find.text('Pro plan'), findsOneWidget);
    expect(find.text('All PDF tools'), findsNWidgets(2));
    expect(find.text('Unlimited scans'), findsOneWidget);
    expect(find.text('Advanced OCR'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Yearly'),
      80,
      scrollable: find.descendant(
        of: find.byType(CompleteFeaturesScreen),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CompleteFeaturesScreen),
        matching: find.text('All tools'),
      ),
      findsNothing,
    );
  });

  testWidgets('Favorites in the drawer asks for Pro, Close returns home', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Favorites'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Go Pro'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Go Pro'), findsNothing);
    expect(find.text('Documents'), findsWidgets);
  });

  testWidgets('scan button asks for Pro when free scans are used', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(
      app(
        router,
        extra: [
          quotaStoreProvider.overrideWithValue(
            MemoryQuotaStore(
              used: ScanQuota.weeklyLimit,
              starterDone: true,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.document_scanner_rounded));
    await tester.pumpAndSettle();

    expect(find.text('${ScanQuota.weeklyLimit} free scans used'), findsOneWidget);
    expect(find.text('See Scanella Pro'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, isNot('/camera'));
  });

  testWidgets('drawer shows used-up scans and the same popup on Pro', (
    tester,
  ) async {
    final router = testRouter();
    await tester.pumpWidget(
      app(
        router,
        extra: [
          quotaStoreProvider.overrideWithValue(
            MemoryQuotaStore(
              used: ScanQuota.weeklyLimit,
              starterDone: true,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.textContaining('Resets'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Scanella Pro'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('${ScanQuota.weeklyLimit} free scans used'), findsOneWidget);
    expect(
      find.textContaining('Your ${ScanQuota.weeklyLimit} free scans reset'),
      findsOneWidget,
    );
    expect(find.text('Not now'), findsNothing);

    await tester.tap(find.text('See Scanella Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Go Pro'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('Pro drawer does not show weekly reset counts', (tester) async {
    final router = testRouter();
    await tester.pumpWidget(
      app(
        router,
        extra: [
          ...withPro(),
          quotaStoreProvider.overrideWithValue(
            MemoryQuotaStore(
              used: ScanQuota.weeklyLimit,
              starterDone: true,
              periodStartMs: DateTime(2026, 9, 12, 12, 31).millisecondsSinceEpoch,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Scanella Pro is on'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.textContaining('Resets'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.textContaining('free scans'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Scanella Pro'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Go Pro'), findsOneWidget);
    expect(find.textContaining('free scans reset'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('You have Scanella Pro'),
      80,
      scrollable: find.descendant(
        of: find.byType(ProPaywall),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('You have Scanella Pro'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Go Pro'), findsNothing);
    expect(find.text('Documents'), findsWidgets);
  });
}
