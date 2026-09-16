import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/features/pro/data/conversion_service.dart';
import 'package:scan2/features/pro/domain/image_pdf_convert.dart';
import 'package:scan2/features/pro/domain/pdf_page_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List solidJpeg({
    required int width,
    required int height,
    int r = 210,
    int g = 12,
    int b = 18,
  }) {
    final image = img.Image(width: width, height: height);
    for (final pixel in image) {
      image.setPixelRgb(pixel.x, pixel.y, r, g, b);
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  bool hasDarkInk(img.Image page, {required int y0, required int y1}) {
    final top = y0.clamp(0, page.height - 1);
    final bottom = y1.clamp(0, page.height - 1);
    for (var y = top; y <= bottom; y++) {
      for (var x = 0; x < page.width; x++) {
        final pixel = page.getPixel(x, y);
        if (pixel.r.toInt() < 90 && pixel.g.toInt() < 90) return true;
      }
    }
    return false;
  }

  group('PdfPageTools', () {
    test('rotate 90° turns a wide red page into a tall red page', () async {
      final jpeg = solidJpeg(width: 120, height: 60);
      final source = await const ImagePdfConvert().imagesToPdf([jpeg]);
      final tools = PdfPageTools(pagesFromPdf: (_) async => [jpeg]);
      final pdf = await tools.rotate(source, quarterTurns: 1);

      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      final embedded = firstJpegIn(pdf);
      expect(embedded, isNotNull);
      final decoded = img.decodeImage(embedded!)!;
      expect(decoded.width, lessThan(decoded.height));
      final sample = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
      expect(sample.r.toInt(), greaterThan(150));
      expect(sample.g.toInt(), lessThan(80));
      expect(sample.b.toInt(), lessThan(80));
    });

    test('page numbers burn 1 / 2 into the bottom of each page', () async {
      final a = solidJpeg(width: 240, height: 320, r: 230, g: 230, b: 230);
      final b = solidJpeg(width: 240, height: 320, r: 230, g: 230, b: 230);
      final source = await const ImagePdfConvert().imagesToPdf([a, b]);
      final tools = PdfPageTools(pagesFromPdf: (_) async => [a, b]);
      final pdf = await tools.addPageNumbers(source);
      final pages = jpegsIn(pdf);
      expect(pages.length, greaterThanOrEqualTo(2));

      final first = img.decodeImage(pages[0])!;
      expect(
        hasDarkInk(first, y0: first.height - 50, y1: first.height - 1),
        isTrue,
        reason: 'page 1 should have a dark "1 / 2" on the bottom',
      );
      final mid = first.getPixel(first.width ~/ 2, first.height ~/ 2);
      expect(mid.r.toInt(), greaterThan(180));

      final second = img.decodeImage(pages[1])!;
      expect(
        hasDarkInk(second, y0: second.height - 50, y1: second.height - 1),
        isTrue,
        reason: 'page 2 should have a dark "2 / 2" on the bottom',
      );
    });

    test('watermark burns CONFIDENTIAL into the middle of the page', () async {
      final jpeg = solidJpeg(width: 420, height: 560, r: 236, g: 236, b: 236);
      final source = await const ImagePdfConvert().imagesToPdf([jpeg]);
      final tools = PdfPageTools(pagesFromPdf: (_) async => [jpeg]);
      final pdf = await tools.addWatermark(source, text: 'CONFIDENTIAL');

      final embedded = firstJpegIn(pdf);
      expect(embedded, isNotNull);
      final decoded = img.decodeImage(embedded!)!;
      expect(
        hasDarkInk(
          decoded,
          y0: decoded.height ~/ 2 - 40,
          y1: decoded.height ~/ 2 + 40,
        ),
        isTrue,
        reason: 'CONFIDENTIAL should be dark pixels in the middle',
      );
      final corner = decoded.getPixel(8, 8);
      expect(corner.r.toInt(), greaterThan(180));
    });

    test('unlock refuses a PDF that is not locked', () async {
      final jpeg = solidJpeg(width: 80, height: 100);
      final pdf = await const ImagePdfConvert().imagesToPdf([jpeg]);
      expect(pdfLooksEncrypted(pdf), isFalse);
      expect(
        () => const PdfPageTools().unlock(pdf),
        throwsA(
          isA<ConversionFailure>().having(
            (e) => e.code,
            'code',
            'not-locked',
          ),
        ),
      );
    });

    test('unlock writes a PDF without Encrypt and keeps the page ink', () async {
      final jpeg = solidJpeg(width: 80, height: 100);
      final open = await const ImagePdfConvert().imagesToPdf([jpeg]);
      final locked = Uint8List.fromList([
        ...open,
        ...utf8.encode('\n/Encrypt\n'),
      ]);
      expect(pdfLooksEncrypted(locked), isTrue);

      final tools = PdfPageTools(pagesFromPdf: (_) async => [jpeg]);
      final unlocked = await tools.unlock(locked, password: 'secret');
      expect(String.fromCharCodes(unlocked.take(5)), '%PDF-');
      expect(pdfLooksEncrypted(unlocked), isFalse);

      final embedded = firstJpegIn(unlocked);
      expect(embedded, isNotNull);
      final decoded = img.decodeImage(embedded!)!;
      final sample = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
      expect(sample.r.toInt(), greaterThan(150));
      expect(sample.g.toInt(), lessThan(80));
    });

    test('unlock keeps a wrong-password error from native', () async {
      final jpeg = solidJpeg(width: 80, height: 100);
      final open = await const ImagePdfConvert().imagesToPdf([jpeg]);
      final locked = Uint8List.fromList([
        ...open,
        ...utf8.encode('\n/Encrypt\n'),
      ]);
      final tools = PdfPageTools(
        unlockPdf: (_, __) async {
          throw PlatformException(
            code: 'wrong_password',
            message: 'Could not open this locked PDF.',
          );
        },
      );
      expect(
        () => tools.unlock(locked, password: 'nope'),
        throwsA(
          isA<ConversionFailure>().having(
            (e) => e.message,
            'message',
            contains('Check the password'),
          ),
        ),
      );
    });
  });

  test('stampPageNumber paints dark ink on a light page', () {
    final jpeg = solidJpeg(width: 240, height: 320, r: 240, g: 240, b: 240);
    final stamped = stampPageNumber(jpeg, page: 3, of: 8);
    final decoded = img.decodeImage(stamped)!;
    expect(
      hasDarkInk(decoded, y0: decoded.height - 50, y1: decoded.height - 1),
      isTrue,
    );
  });

  test('stampWatermark paints dark ink in the middle', () {
    final jpeg = solidJpeg(width: 420, height: 560, r: 240, g: 240, b: 240);
    final stamped = stampWatermark(jpeg, 'DRAFT');
    final decoded = img.decodeImage(stamped)!;
    expect(
      hasDarkInk(
        decoded,
        y0: decoded.height ~/ 2 - 40,
        y1: decoded.height ~/ 2 + 40,
      ),
      isTrue,
    );
  });
}

Uint8List? firstJpegIn(Uint8List pdf) {
  final all = jpegsIn(pdf);
  return all.isEmpty ? null : all.first;
}

List<Uint8List> jpegsIn(Uint8List pdf) {
  final pages = <Uint8List>[];
  var i = 0;
  while (i < pdf.length - 1) {
    if (pdf[i] == 0xFF && pdf[i + 1] == 0xD8) {
      var end = -1;
      for (var j = i + 2; j < pdf.length - 1; j++) {
        if (pdf[j] == 0xFF && pdf[j + 1] == 0xD9) {
          end = j + 2;
          break;
        }
      }
      if (end > 0) {
        pages.add(Uint8List.sublistView(pdf, i, end));
        i = end;
        continue;
      }
    }
    i++;
  }
  return pages;
}
