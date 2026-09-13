import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gal/gal.dart';
import 'package:scan2/core/branding.dart';
import 'package:scan2/core/imaging/raster.dart';
import 'package:scan2/features/library/data/pdf_standard_security.dart';
import 'package:printing/printing.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/pdf_export_options.dart';
import 'package:scan2/features/library/domain/stamp_compositor.dart';
import 'package:share_plus/share_plus.dart';

/// Builds PDFs and hands documents to the share sheet.
///
/// A scanner that cannot produce a PDF is a camera, so this is part of the
/// core flow rather than an extra.
class ExportService {
  const ExportService();

  /// Renders [document] to PDF bytes, one page per scan.
  ///
  /// Separate from [buildPdf] so it can be exercised without a platform
  /// temp directory.
  Future<Uint8List> buildPdfBytes(
    Document document, {
    PdfExportOptions options = const PdfExportOptions(),
  }) async {
    final chosen = _pagesToExport(document, options.pageIndexes);
    final images = <_SizedImage>[];
    final pageIndexes = <int>[];
    for (final entry in chosen) {
      final file = File(entry.page.path);
      if (!await file.exists()) continue;
      var bytes = await file.readAsBytes();
      if (entry.page.stamps.isNotEmpty) {
        bytes = await const StampCompositor().paint(bytes, entry.page.stamps);
      }
      final prepared = await compute(
        _prepareForPdf,
        _PrepareArgs(
          bytes: bytes,
          maxEdge: options.quality.maxEdge,
          jpegQuality: options.quality.jpegQuality,
        ),
      );
      if (prepared == null) continue;
      images.add(prepared);
      pageIndexes.add(entry.index);
    }

    if (images.isEmpty) {
      throw StateError('This document has no pages to export.');
    }
    return compute(
      _buildPdfBytes,
      _BuildPdfArgs(
        images: images,
        pageSize: options.pageSize,
        password: options.password,
        searchable: options.searchable,
        ocrText: document.ocrText,
        blocks: [
          for (final block in document.ocrBlocks) block.toJson(),
        ],
        pageIndexes: pageIndexes,
      ),
    );
  }

  /// Renders [document] to a PDF in the temp directory.
  Future<File> buildPdf(
    Document document, {
    PdfExportOptions options = const PdfExportOptions(),
  }) async {
    final pdf = await buildPdfBytes(document, options: options);
    final directory = await getTemporaryDirectory();
    final file = File(
      path.join(directory.path, '${fileNameFor(document)}.pdf'),
    );
    await file.writeAsBytes(pdf, flush: true);
    return file;
  }

  /// Filesystem-safe base name for [document].
  static String fileNameFor(Document document) => _safeFileName(document.title);

  /// Shares [document] as a PDF.
  ///
  /// [shareOrigin] is required on iPad (and some iPhones in landscape): the
  /// system share popover has to know where to point. Callers take it from
  /// the widget that opened Export.
  Future<void> sharePdf(
    Document document, {
    Rect? shareOrigin,
    PdfExportOptions options = const PdfExportOptions(),
  }) async {
    final file = await buildPdf(document, options: options);
    final name = '${fileNameFor(document)}.pdf';
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/pdf', name: name),
    ], sharePositionOrigin: shareOrigin);
  }

  /// Presents the system Files picker and writes the PDF there.
  ///
  /// Returns false when the user cancels. Previously this aliased [sharePdf],
  /// which on iOS failed if another sheet was still dismissing and never
  /// opened the Files browser on its own.
  Future<bool> savePdfToFiles(
    Document document, {
    PdfExportOptions options = const PdfExportOptions(),
  }) async {
    final bytes = await buildPdfBytes(document, options: options);
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: '${fileNameFor(document)}.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
    return savedPath != null && savedPath.isNotEmpty;
  }

  /// Saves every page image into the system photo library.
  ///
  /// Throws [GalException] when access is refused, which the caller surfaces —
  /// silently doing nothing is the worst possible outcome for a save action.
  Future<int> saveToPhotos(
    Document document, {
    List<int>? pageIndexes,
  }) async {
    var saved = 0;
    for (final entry in _pagesToExport(document, pageIndexes)) {
      final bytes = await _compositedPageBytes(entry.page);
      if (bytes == null) continue;
      final temp = await _writeTempJpeg(bytes, 'photo_$saved');
      await Gal.putImage(temp.path, album: AppIdentity.photosAlbum);
      saved++;
    }
    if (saved == 0) {
      throw StateError('This document has no pages to save.');
    }
    return saved;
  }

  /// Shares the page images themselves, for people who want the JPEGs.
  /// JPEG or PNG bytes for each chosen page.
  Future<List<Uint8List>> buildImageBytes(
    Document document, {
    required bool png,
    List<int>? pageIndexes,
  }) async {
    final out = <Uint8List>[];
    for (final entry in _pagesToExport(document, pageIndexes)) {
      final bytes = await _compositedPageBytes(entry.page);
      if (bytes == null) continue;
      if (!png) {
        out.add(bytes);
        continue;
      }
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;
      out.add(Uint8List.fromList(img.encodePng(decoded)));
    }
    if (out.isEmpty) {
      throw StateError('This document has no pages to export.');
    }
    return out;
  }

  Future<void> shareImages(
    Document document, {
    Rect? shareOrigin,
    bool png = false,
    List<int>? pageIndexes,
  }) async {
    final files = <XFile>[];
    final images = await buildImageBytes(
      document,
      png: png,
      pageIndexes: pageIndexes,
    );
    final ext = png ? 'png' : 'jpg';
    final mime = png ? 'image/png' : 'image/jpeg';
    for (var i = 0; i < images.length; i++) {
      final temp = await _writeTempBytes(images[i], 'share_$i.$ext');
      files.add(XFile(temp.path, mimeType: mime));
    }
    await Share.shareXFiles(files, sharePositionOrigin: shareOrigin);
  }

  /// One PDF per document, handed to the system share sheet together.
  Future<void> shareDocuments(
    List<Document> documents, {
    Rect? shareOrigin,
    PdfExportOptions options = const PdfExportOptions(),
  }) async {
    if (documents.isEmpty) {
      throw StateError('Nothing to share.');
    }
    if (documents.length == 1) {
      await sharePdf(
        documents.first,
        shareOrigin: shareOrigin,
        options: options,
      );
      return;
    }
    final files = <XFile>[];
    for (final document in documents) {
      final file = await buildPdf(document, options: options);
      files.add(
        XFile(
          file.path,
          mimeType: 'application/pdf',
          name: '${fileNameFor(document)}.pdf',
        ),
      );
    }
    await Share.shareXFiles(files, sharePositionOrigin: shareOrigin);
  }

  Future<void> shareOcrText(Document document, {Rect? shareOrigin}) async {
    final text = (document.ocrText ?? '').trim();
    if (text.isEmpty) {
      throw StateError('Run Extract text first, then export the OCR.');
    }
    final directory = await getTemporaryDirectory();
    final file = File(
      path.join(directory.path, '${fileNameFor(document)}.txt'),
    );
    await file.writeAsString(text, flush: true);
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'text/plain'),
    ], sharePositionOrigin: shareOrigin);
  }

  Future<void> printPdf(
    Document document, {
    PdfExportOptions options = const PdfExportOptions(),
  }) async {
    final bytes = await buildPdfBytes(document, options: options);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: fileNameFor(document),
    );
  }

  List<_IndexedPage> _pagesToExport(Document document, List<int>? indexes) {
    if (indexes == null || indexes.isEmpty) {
      return [
        for (var i = 0; i < document.pages.length; i++)
          _IndexedPage(i, document.pages[i]),
      ];
    }
    return [
      for (final i in indexes)
        if (i >= 0 && i < document.pages.length)
          _IndexedPage(i, document.pages[i]),
    ];
  }

  Future<Uint8List?> _compositedPageBytes(ScanPage page) async {
    final file = File(page.path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (page.stamps.isEmpty) return bytes;
    return const StampCompositor().paint(bytes, page.stamps);
  }

  Future<File> _writeTempJpeg(Uint8List bytes, String name) async {
    return _writeTempBytes(bytes, '$name.jpg');
  }

  Future<File> _writeTempBytes(Uint8List bytes, String name) async {
    final directory = await getTemporaryDirectory();
    final file = File(path.join(directory.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String _safeFileName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    return cleaned.isEmpty ? 'scan' : cleaned;
  }
}

class _IndexedPage {
  const _IndexedPage(this.index, this.page);

  final int index;
  final ScanPage page;
}

class _SizedImage {
  const _SizedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class _PrepareArgs {
  const _PrepareArgs({
    required this.bytes,
    required this.maxEdge,
    required this.jpegQuality,
  });

  final Uint8List bytes;
  final int maxEdge;
  final int jpegQuality;
}

class _BuildPdfArgs {
  const _BuildPdfArgs({
    required this.images,
    required this.pageSize,
    this.password,
    this.searchable = false,
    this.ocrText,
    this.blocks = const [],
    this.pageIndexes = const [],
  });

  final List<_SizedImage> images;
  final PdfPageSize pageSize;
  final String? password;
  final bool searchable;
  final String? ocrText;
  final List<Map<String, dynamic>> blocks;
  final List<int> pageIndexes;
}

_SizedImage? _prepareForPdf(_PrepareArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) return null;

  img.Image source = decoded;
  final longest = math.max(decoded.width, decoded.height);
  if (longest > args.maxEdge) {
    source = Raster.fromImage(decoded).downscaledTo(args.maxEdge).toImage();
  }

  final shouldReencode = longest > args.maxEdge || args.jpegQuality < 88;
  return _SizedImage(
    bytes: shouldReencode
        ? Uint8List.fromList(img.encodeJpg(source, quality: args.jpegQuality))
        : args.bytes,
    width: source.width,
    height: source.height,
  );
}

Future<Uint8List> _buildPdfBytes(_BuildPdfArgs args) async {
  final document = pw.Document();
  final fit = args.pageSize == PdfPageSize.fit;
  for (var i = 0; i < args.images.length; i++) {
    final image = args.images[i];
    final pageIndex = i < args.pageIndexes.length ? args.pageIndexes[i] : i;
    final format = _pageFormatFor(image, args.pageSize);
    document.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Stack(
          children: [
            pw.Image(
              pw.MemoryImage(image.bytes),
              fit: fit ? pw.BoxFit.fill : pw.BoxFit.contain,
            ),
            if (args.searchable)
              ..._searchableLayer(
                args,
                pageIndex: pageIndex,
                pageWidth: format.width,
                pageHeight: format.height,
              ),
          ],
        ),
      ),
    );
  }
  final password = args.password?.trim();
  if (password != null && password.isNotEmpty) {
    PdfStandardSecurity(document.document, userPassword: password);
  }
  return document.save();
}

/// Fit uses the scan's own proportions, scaled so its longest side matches
/// A4's. A4 and Letter keep a printer page and letterbox the scan.
PdfPageFormat _pageFormatFor(_SizedImage image, PdfPageSize size) {
  switch (size) {
    case PdfPageSize.a4:
      return PdfPageFormat.a4;
    case PdfPageSize.letter:
      return PdfPageFormat.letter;
    case PdfPageSize.fit:
      final longestSide = PdfPageFormat.a4.height;
      final width = image.width.toDouble();
      final height = image.height.toDouble();
      if (width <= 0 || height <= 0) return PdfPageFormat.a4;
      final scale = longestSide / math.max(width, height);
      return PdfPageFormat(width * scale, height * scale);
  }
}

List<pw.Widget> _searchableLayer(
  _BuildPdfArgs args, {
  required int pageIndex,
  required double pageWidth,
  required double pageHeight,
}) {
  final onPage = [
    for (final raw in args.blocks)
      if ((raw['p'] as num?)?.toInt() == pageIndex) raw,
  ];
  if (onPage.isNotEmpty) {
    return [
      for (final raw in onPage)
        pw.Positioned(
          left: ((raw['l'] as num?)?.toDouble() ?? 0) * pageWidth,
          top: ((raw['t'] as num?)?.toDouble() ?? 0) * pageHeight,
          child: pw.SizedBox(
            width: math.max(
              4,
              ((raw['w'] as num?)?.toDouble() ?? 0.2) * pageWidth,
            ),
            height: math.max(
              4,
              ((raw['h'] as num?)?.toDouble() ?? 0.04) * pageHeight,
            ),
            child: pw.Opacity(
              opacity: 0.01,
              child: pw.Text(
                raw['text'] as String? ?? '',
                style: pw.TextStyle(
                  fontSize: math.max(
                    6,
                    ((raw['h'] as num?)?.toDouble() ?? 0.04) * pageHeight,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }
  final text = (args.ocrText ?? '').trim();
  if (text.isEmpty || pageIndex != (args.pageIndexes.isEmpty ? 0 : args.pageIndexes.first)) {
    return const [];
  }
  return [
    pw.Positioned(
      left: 4,
      top: 4,
      child: pw.SizedBox(
        width: pageWidth - 8,
        child: pw.Opacity(
          opacity: 0.01,
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
        ),
      ),
    ),
  ];
}
