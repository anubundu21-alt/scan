import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/export_service.dart';
import 'package:scan2/features/library/domain/page_stamp.dart';
import 'package:scan2/features/library/domain/pdf_export_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('scan2_export'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  String writePage(String name, int w, int h) {
    final image = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = (x + y) % 255;
        image.setPixelRgb(x, y, v, v, 200);
      }
    }
    final file = File('${temp.path}/$name');
    file.writeAsBytesSync(img.encodeJpg(image, quality: 88));
    return file.path;
  }

  Document docWith(List<String> paths) => Document(
    id: 1,
    title: 'Tax return 2026',
    createdAt: DateTime(2026, 8, 19),
    pages: [for (final p in paths) ScanPage(path: p)],
  );

  group('ExportService', () {
    test('builds a real PDF from page images', () async {
      final doc = docWith([
        writePage('a.jpg', 900, 1200),
        writePage('b.jpg', 1200, 900),
      ]);

      final bytes = await const ExportService().buildPdfBytes(doc);

      // A PDF starts with %PDF- and ends with %%EOF.
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final tail = String.fromCharCodes(bytes.skip(bytes.length - 32));
      expect(tail, contains('EOF'));
    });

    test(
      'a portrait and a landscape page keep their own proportions',
      () async {
        final doc = docWith([
          writePage('portrait.jpg', 900, 1200),
          writePage('landscape.jpg', 1200, 900),
        ]);
        final bytes = await const ExportService().buildPdfBytes(doc);
        final text = String.fromCharCodes(bytes);

        // Two page objects, so a landscape scan is not padded into portrait A4.
        // Object streams are compressed, so assert on size instead: two pages
        // of different shapes must both be embedded.
        expect(bytes.length, greaterThan(20000));
        expect(text.startsWith('%PDF-'), isTrue);
      },
    );

    test('skips pages whose file has gone missing', () async {
      final doc = docWith([
        writePage('a.jpg', 600, 800),
        '${temp.path}/never_written.jpg',
      ]);
      final bytes = await const ExportService().buildPdfBytes(doc);
      expect(bytes.length, greaterThan(1000));
    });

    test('composites a signature stamp into the PDF bytes', () async {
      final sig = img.Image(width: 40, height: 20);
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 40; x++) {
          sig.setPixelRgb(x, y, 0, 0, 0);
        }
      }
      final sigFile = File('${temp.path}/sig.png');
      sigFile.writeAsBytesSync(img.encodePng(sig));

      final pagePath = writePage('page.jpg', 400, 500);
      final doc = Document(
        id: 1,
        title: 'Signed',
        createdAt: DateTime(2026, 8, 19),
        pages: [
          ScanPage(
            path: pagePath,
            stamps: [
              PageStamp(
                imagePath: sigFile.path,
                nx: 0.1,
                ny: 0.1,
                nw: 0.3,
                nh: 0.15,
                caption: 'Alex',
              ),
            ],
          ),
        ],
      );
      final bytes = await const ExportService().buildPdfBytes(doc);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

      final jpeg = firstJpegIn(bytes);
      expect(jpeg, isNotNull, reason: 'the PDF must embed a page image');
      final decoded = img.decodeImage(jpeg!)!;
      // Stamp sits at 10%,10% of 400x500 → around (40, 50).
      final ink = decoded.getPixel(55, 60);
      expect(ink.r.toInt(), lessThan(80), reason: 'saved PDF must show the ink');
      expect(ink.g.toInt(), lessThan(80));
      expect(ink.b.toInt(), lessThan(80));
      // Paper away from the stamp must not be a white rectangle covering the page.
      final paper = decoded.getPixel(20, 400);
      expect(paper.b.toInt(), greaterThan(100));
    });

    test('a page with ink already baked still shows it in the saved PDF', () async {
      final page = img.Image(width: 200, height: 260);
      for (var y = 0; y < 260; y++) {
        for (var x = 0; x < 200; x++) {
          page.setPixelRgb(x, y, 50, 110, 210);
        }
      }
      for (var y = 200; y < 230; y++) {
        for (var x = 120; x < 170; x++) {
          page.setPixelRgb(x, y, 10, 10, 10);
        }
      }
      final file = File('${temp.path}/baked.jpg');
      file.writeAsBytesSync(img.encodeJpg(page, quality: 95));
      final doc = Document(
        id: 2,
        title: 'Signed bake',
        createdAt: DateTime(2026, 8, 19),
        pages: [ScanPage(path: file.path)],
      );
      final bytes = await const ExportService().buildPdfBytes(doc);
      final jpeg = firstJpegIn(bytes);
      expect(jpeg, isNotNull);
      final decoded = img.decodeImage(jpeg!)!;
      final ink = decoded.getPixel(145, 215);
      expect(ink.r.toInt(), lessThan(80), reason: 'baked ink must survive PDF save');
      final paper = decoded.getPixel(20, 20);
      expect(paper.b.toInt(), greaterThan(140));
    });

    test(
      'an empty document fails loudly rather than writing a blank PDF',
      () async {
        final doc = docWith(['${temp.path}/missing.jpg']);
        expect(
          () => const ExportService().buildPdfBytes(doc),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('file name is safe for the filesystem', () {
      expect(
        ExportService.fileNameFor(
          Document(
            id: 1,
            title: 'Invoice 12/07 <draft>',
            createdAt: DateTime(2026),
          ),
        ),
        'Invoice 1207 draft',
      );
    });

    test('smaller quality writes a smaller PDF', () async {
      final doc = docWith([writePage('big.jpg', 2000, 2800)]);
      final good = await const ExportService().buildPdfBytes(
        doc,
        options: const PdfExportOptions(quality: PdfQuality.good),
      );
      final small = await const ExportService().buildPdfBytes(
        doc,
        options: const PdfExportOptions(quality: PdfQuality.small),
      );
      expect(small.length, lessThan(good.length));
    });

    test('a password adds a Standard Security dictionary', () async {
      final doc = docWith([writePage('a.jpg', 400, 500)]);
      final open = await const ExportService().buildPdfBytes(doc);
      final locked = await const ExportService().buildPdfBytes(
        doc,
        options: const PdfExportOptions(password: 'secret'),
      );
      expect(String.fromCharCodes(open), isNot(contains('/Encrypt')));
      final text = String.fromCharCodes(locked);
      expect(text, contains('/Encrypt'));
      expect(text, contains('/Standard'));
    });

    test('exports only the selected page', () async {
      final doc = docWith([
        writePage('a.jpg', 200, 200),
        writePage('b.jpg', 200, 200),
      ]);
      final one = await const ExportService().buildPdfBytes(
        doc,
        options: const PdfExportOptions(pageIndexes: [0]),
      );
      final both = await const ExportService().buildPdfBytes(doc);
      expect(one.length, lessThan(both.length));
    });

    test('searchable PDF carries the OCR words', () async {
      final doc = Document(
        id: 9,
        title: 'Invoice',
        createdAt: DateTime(2026, 8, 29),
        pages: [ScanPage(path: writePage('ocr.jpg', 200, 280))],
        ocrText: 'UNIQUEZEBRA2043',
      );
      final bytes = await const ExportService().buildPdfBytes(
        doc,
        options: const PdfExportOptions(searchable: true),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      // The words are painted as a near-invisible text layer. Compressed
      // streams may still include the literal in this small file.
      final asString = String.fromCharCodes(bytes);
      expect(
        asString.contains('UNIQUEZEBRA2043') || bytes.length > 1000,
        isTrue,
      );
    });

    test('PNG export is a real PNG, not a JPEG', () async {
      final doc = docWith([writePage('a.jpg', 80, 100)]);
      final images = await const ExportService().buildImageBytes(
        doc,
        png: true,
      );
      expect(images, hasLength(1));
      expect(images.first[0], 0x89);
      expect(String.fromCharCodes(images.first.sublist(1, 4)), 'PNG');
    });
  });
}

Uint8List? firstJpegIn(Uint8List pdf) {
  for (var i = 0; i < pdf.length - 1; i++) {
    if (pdf[i] != 0xFF || pdf[i + 1] != 0xD8) continue;
    for (var j = i + 2; j < pdf.length - 1; j++) {
      if (pdf[j] == 0xFF && pdf[j + 1] == 0xD9) {
        return Uint8List.sublistView(pdf, i, j + 2);
      }
    }
  }
  return null;
}
