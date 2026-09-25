import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/features/pro/domain/image_pdf_convert.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List solidJpeg({
    required int width,
    required int height,
    required int r,
    required int g,
    required int b,
  }) {
    final image = img.Image(width: width, height: height);
    for (final pixel in image) {
      image.setPixelRgb(pixel.x, pixel.y, r, g, b);
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  group('ImagePdfConvert', () {
    test('images become a PDF that still holds the ink', () async {
      final jpeg = solidJpeg(width: 80, height: 100, r: 210, g: 12, b: 18);
      final pdf = await const ImagePdfConvert().imagesToPdf([jpeg]);

      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      final embedded = firstJpegIn(pdf);
      expect(embedded, isNotNull);
      final decoded = img.decodeImage(embedded!);
      expect(decoded, isNotNull);
      final sample = decoded!.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
      expect(sample.r.toInt(), greaterThan(150));
      expect(sample.g.toInt(), lessThan(80));
      expect(sample.b.toInt(), lessThan(80));
    });

    test('two images become two pages', () async {
      final a = solidJpeg(width: 60, height: 80, r: 200, g: 10, b: 10);
      final b = solidJpeg(width: 90, height: 60, r: 10, g: 20, b: 200);
      final pdf = await const ImagePdfConvert().imagesToPdf([a, b]);
      expect(pdf.length, greaterThan(a.length));
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    });

    test('a red PDF raster buffer is not a black JPEG or PNG', () {
      const width = 24;
      const height = 24;
      final rgba = Uint8List(width * height * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 220;
        rgba[i + 1] = 18;
        rgba[i + 2] = 24;
        rgba[i + 3] = 255;
      }
      final jpeg = rgbaToPageImage(
        rgba,
        width: width,
        height: height,
        png: false,
      );
      expect(jpeg[0], 0xFF);
      expect(jpeg[1], 0xD8);
      final jpegImage = img.decodeImage(jpeg)!;
      final jpegPixel = jpegImage.getPixel(12, 12);
      expect(jpegPixel.r.toInt(), greaterThan(150));
      expect(jpegPixel.g.toInt(), lessThan(80));

      final png = rgbaToPageImage(
        rgba,
        width: width,
        height: height,
        png: true,
      );
      expect(png[0], 0x89);
      expect(String.fromCharCodes(png.sublist(1, 4)), 'PNG');
      final pngImage = img.decodeImage(png)!;
      final pngPixel = pngImage.getPixel(12, 12);
      expect(pngPixel.r.toInt(), greaterThan(150));
      expect(pngPixel.g.toInt(), lessThan(80));
    });

    test('one page is a JPEG; several pages come back as a zip', () {
      final page = solidJpeg(width: 32, height: 40, r: 40, g: 40, b: 40);
      const convert = ImagePdfConvert();
      final single = convert.packImages([page], png: false, stem: 'scan');
      expect(single.filename, 'scan.jpg');
      expect(single.mimeType, 'image/jpeg');
      expect(single.bytes, page);

      final zipped = convert.packImages([page, page], png: true, stem: 'pages');
      expect(zipped.filename, 'pages.zip');
      expect(zipped.mimeType, 'application/zip');
      final archive = ZipDecoder().decodeBytes(zipped.bytes);
      expect(archive.findFile('pages_page_1.png'), isNotNull);
      expect(archive.findFile('pages_page_2.png'), isNotNull);
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
