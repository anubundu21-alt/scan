import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:scan2/core/imaging/flatten_white.dart';
import 'package:scan2/features/pro/data/conversion_service.dart';

/// JPG/PNG ↔ PDF on the device. No conversion host, no scan pipeline.
class ImagePdfConvert {
  const ImagePdfConvert();

  /// One PDF page per image, sized to the picture. Not a scan.
  Future<Uint8List> imagesToPdf(List<Uint8List> images) async {
    final pages = <_PdfImage>[];
    for (final bytes in images) {
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        continue;
      }
      pages.add(
        _PdfImage(bytes: bytes, width: decoded.width, height: decoded.height),
      );
    }
    if (pages.isEmpty) {
      throw StateError('Nothing in that selection could be read as an image.');
    }

    final document = pw.Document();
    final longestSide = PdfPageFormat.a4.height;
    for (final page in pages) {
      final scale = longestSide / math.max(page.width, page.height);
      final format = PdfPageFormat(
        page.width.toDouble() * scale,
        page.height.toDouble() * scale,
      );
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Image(pw.MemoryImage(page.bytes), fit: pw.BoxFit.fill),
        ),
      );
    }
    return await document.save();
  }

  /// Raster each PDF page onto white paper, then encode JPG or PNG.
  Future<List<Uint8List>> pdfToImages(
    Uint8List pdfBytes, {
    required bool png,
    double dpi = 150,
  }) async {
    final pages = <Uint8List>[];
    await for (final page in Printing.raster(pdfBytes, dpi: dpi)) {
      pages.add(
        rgbaToPageImage(
          page.pixels,
          width: page.width,
          height: page.height,
          png: png,
        ),
      );
    }
    if (pages.isEmpty) {
      throw StateError('That PDF has no pages that could be read.');
    }
    return pages;
  }

  /// One image, or a zip when there is more than one page.
  ConvertedFile packImages(
    List<Uint8List> pages, {
    required bool png,
    required String stem,
  }) {
    if (pages.isEmpty) {
      throw StateError('That PDF has no pages that could be read.');
    }
    final ext = png ? 'png' : 'jpg';
    final mime = png ? 'image/png' : 'image/jpeg';
    if (pages.length == 1) {
      return ConvertedFile(
        bytes: pages.first,
        filename: '$stem.$ext',
        mimeType: mime,
      );
    }
    final archive = Archive();
    for (var i = 0; i < pages.length; i++) {
      final name = '${stem}_page_${i + 1}.$ext';
      archive.addFile(ArchiveFile(name, pages[i].length, pages[i]));
    }
    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) {
      throw StateError('Could not pack the images into a zip.');
    }
    return ConvertedFile(
      bytes: Uint8List.fromList(zipped),
      filename: '$stem.zip',
      mimeType: 'application/zip',
    );
  }
}

/// Flatten a PDFKit / PdfRenderer RGBA buffer onto white, then JPG or PNG.
Uint8List rgbaToPageImage(
  Uint8List rgba, {
  required int width,
  required int height,
  required bool png,
}) {
  final jpeg = rasterPdfPageToJpeg(rgba, width: width, height: height);
  if (!png) return jpeg;
  final decoded = img.decodeImage(jpeg);
  if (decoded == null) {
    throw StateError('That page could not be encoded as a PNG.');
  }
  return Uint8List.fromList(img.encodePng(decoded));
}

class _PdfImage {
  const _PdfImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}
