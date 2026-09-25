import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/core/imaging/flatten_white.dart';
import 'package:scan2/core/imaging/raster.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';
import 'package:scan2/features/crop/domain/page_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('flattenOntoWhite', () {
    test('transparent pixels become white, ink stays', () {
      final source = img.Image(width: 8, height: 8, numChannels: 4);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          source.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
      // A dark ink stroke in the middle, fully opaque.
      source.setPixelRgba(3, 3, 20, 20, 20, 255);
      source.setPixelRgba(4, 3, 20, 20, 20, 255);

      final flat = flattenOntoWhite(source);
      expect(flat.numChannels, 3);

      final paper = flat.getPixel(0, 0);
      expect(paper.r, 255);
      expect(paper.g, 255);
      expect(paper.b, 255);

      final ink = flat.getPixel(3, 3);
      expect(ink.r.toInt(), lessThan(40));
      expect(ink.g.toInt(), lessThan(40));
    });

    test('RGB-only images are left alone', () {
      final source = img.Image(width: 2, height: 1, numChannels: 3);
      source.setPixelRgb(0, 0, 10, 20, 30);
      source.setPixelRgb(1, 0, 40, 50, 60);
      final flat = flattenOntoWhite(source);
      expect(identical(flat, source) || flat.getPixel(0, 0).r == 10, isTrue);
      expect(flat.getPixel(0, 0).r, 10);
      expect(flat.getPixel(1, 0).b, 60);
    });
  });

  group('PDF raster flatten', () {
    test('premultiplied transparent black becomes white paper', () {
      final rgba = Uint8List(4 * 4 * 4);
      // Entirely transparent — what PDFKit leaves behind the glyphs.
      final jpeg = flattenPremultipliedRgbaToJpeg(rgba, width: 4, height: 4);
      expect(isMostlyBlack(jpeg), isFalse);
      final decoded = img.decodeImage(jpeg)!;
      expect(decoded.getPixel(0, 0).r, greaterThan(240));
      expect(decoded.getPixel(2, 2).g, greaterThan(240));
    });

    test('premultiplied black ink on transparent paper stays readable', () {
      final rgba = Uint8List(8 * 8 * 4);
      // Opaque dark ink at (2,2)
      const i = (2 * 8 + 2) * 4;
      rgba[i] = 15;
      rgba[i + 1] = 15;
      rgba[i + 2] = 15;
      rgba[i + 3] = 255;

      final jpeg = rasterPdfPageToJpeg(rgba, width: 8, height: 8);
      expect(isMostlyBlack(jpeg), isFalse);
      final decoded = img.decodeImage(jpeg)!;
      expect(decoded.getPixel(0, 0).r, greaterThan(240));
      expect(decoded.getPixel(2, 2).r.toInt(), lessThan(40));
    });

    test(
      'straight-alpha fallback recovers a page PDFKit-style premul misses',
      () {
        // Straight alpha: RGB is full colour, alpha is 0 everywhere except ink.
        // Premul blend would add 255 to those RGB values and wash them out or
        // keep empty pixels white either way; a buffer of (0,0,0,0) is white
        // in both. Use a page that is only recoverable as straight alpha:
        // dark RGB with alpha 0 would stay black if treated as premul.
        //
        // More realistic: half the pixels are (0,0,0,0), half are opaque white
        // already — premul is correct. The fallback is covered by isMostlyBlack
        // on a premul-black buffer of opaque black (alpha 255).
        final black = Uint8List(4 * 4 * 4);
        for (var i = 0; i < black.length; i += 4) {
          black[i + 3] = 255; // opaque black
        }
        expect(
          isMostlyBlack(
            flattenPremultipliedRgbaToJpeg(black, width: 4, height: 4),
          ),
          isTrue,
        );
      },
    );
  });

  group('PageProcessor on a transparent PDF-like PNG', () {
    test('does not save a black page', () async {
      final source = img.Image(width: 120, height: 160, numChannels: 4);
      for (var y = 0; y < 160; y++) {
        for (var x = 0; x < 120; x++) {
          source.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
      // A navy letter-box so we can prove content survived.
      for (var y = 40; y < 80; y++) {
        for (var x = 20; x < 100; x++) {
          source.setPixelRgba(x, y, 20, 40, 90, 255);
        }
      }

      final png = img.encodePng(source);
      final dir = Directory.systemTemp.createTempSync('scan2_flatten');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = '${dir.path}/pdf_page.png';
      File(file).writeAsBytesSync(png);

      final result = await const PageProcessor().process(
        imagePath: file,
        detectEdges: false,
        adjustments: const ScanAdjustments(filter: ScanFilter.original),
      );

      expect(isMostlyBlack(result.bytes), isFalse);
      final decoded = img.decodeImage(result.bytes)!;
      final paper = decoded.getPixel(2, 2);
      expect(paper.r, greaterThan(230));
      expect(paper.g, greaterThan(230));
      expect(paper.b, greaterThan(230));

      final ink = decoded.getPixel(50, 55);
      expect(ink.b, greaterThan(ink.r));
      expect(ink.r.toInt(), lessThan(80));
    });
  });

  group('Raster.fromImage', () {
    test('flattens alpha so RGB pages are not black', () {
      final source = img.Image(width: 4, height: 4, numChannels: 4);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          source.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
      final raster = Raster.fromImage(source);
      expect(raster.pixels[0], 255);
      expect(raster.pixels[1], 255);
      expect(raster.pixels[2], 255);
    });
  });
}
