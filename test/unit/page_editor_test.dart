import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/features/library/domain/page_editor.dart';
import 'package:scan2/features/library/domain/page_stamp.dart';

void main() {
  Uint8List solidJpeg(int width, int height, int r, int g, int b) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 95));
  }

  test('rotateClockwise swaps width and height', () {
    final rotated = const PageEditor().rotateClockwise(
      solidJpeg(40, 80, 10, 20, 200),
    );
    expect(rotated, isNotNull);
    final decoded = img.decodeImage(rotated!);
    expect(decoded!.width, 80);
    expect(decoded.height, 40);
  });

  test('rotateClockwise returns null for garbage bytes', () {
    expect(
      const PageEditor().rotateClockwise(Uint8List.fromList([1, 2, 3, 4])),
      isNull,
    );
  });

  test('compositeStamps paints the signature onto the page', () {
    final temp = Directory.systemTemp.createTempSync('scan2_stamp');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    final sig = img.Image(width: 20, height: 10);
    for (var y = 0; y < 10; y++) {
      for (var x = 0; x < 20; x++) {
        sig.setPixelRgba(x, y, 0, 0, 0, 255);
      }
    }
    final sigFile = File('${temp.path}/sig.png');
    sigFile.writeAsBytesSync(img.encodePng(sig));

    final page = solidJpeg(100, 100, 255, 255, 255);
    final out = const PageEditor().compositeStamps(page, [
      PageStamp(imagePath: sigFile.path, nx: 0, ny: 0, nw: 0.2, nh: 0.1),
    ]);
    final decoded = img.decodeImage(out)!;
    // Top-left of a white page should no longer be pure white after a black stamp.
    final pixel = decoded.getPixel(2, 2);
    expect(pixel.r.toInt(), lessThan(40));
    expect(pixel.g.toInt(), lessThan(40));
    expect(pixel.b.toInt(), lessThan(40));
  });

  test('asSignatureInk makes white paper transparent', () {
    final src = img.Image(width: 8, height: 8);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        src.setPixelRgb(x, y, 255, 255, 255);
      }
    }
    src.setPixelRgb(3, 3, 10, 10, 10);
    src.setPixelRgb(4, 3, 10, 10, 10);
    src.setPixelRgb(3, 4, 10, 10, 10);
    src.setPixelRgb(4, 4, 10, 10, 10);

    final ink = asSignatureInk(src);
    expect(ink.getPixel(0, 0).a.toInt(), 0);
    expect(ink.getPixel(7, 7).a.toInt(), 0);
    expect(ink.getPixel(3, 3).a.toInt(), greaterThan(200));
  });

  test('prepareStampOverlay leaves a transparent Flutter PNG alone', () {
    final src = img.Image(width: 8, height: 8, numChannels: 4);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        src.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
    src.setPixelRgba(3, 3, 17, 17, 17, 255);
    src.setPixelRgba(4, 3, 17, 17, 17, 255);
    final prepared = prepareStampOverlay(src);
    expect(prepared.getPixel(0, 0).a.toInt(), 0);
    expect(prepared.getPixel(3, 3).a.toInt(), 255);
    expect(prepared.getPixel(3, 3).r.toInt(), 17);
  });

  test('compositeStamps does not paint a white box over the page', () {
    final temp = Directory.systemTemp.createTempSync('scan2_stamp_clear');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    // The old pad snapshot: white sheet, black scribble in the middle.
    final sig = img.Image(width: 80, height: 80);
    for (var y = 0; y < 80; y++) {
      for (var x = 0; x < 80; x++) {
        sig.setPixelRgb(x, y, 255, 255, 255);
      }
    }
    for (var y = 30; y < 50; y++) {
      for (var x = 30; x < 50; x++) {
        sig.setPixelRgb(x, y, 0, 0, 0);
      }
    }
    final sigFile = File('${temp.path}/sig.png');
    sigFile.writeAsBytesSync(img.encodePng(sig));

    final page = solidJpeg(200, 200, 30, 90, 210);
    final out = const PageEditor().compositeStamps(page, [
      PageStamp(imagePath: sigFile.path, nx: 0, ny: 0, nw: 0.4, nh: 0.4),
    ]);
    final decoded = img.decodeImage(out)!;

    final paper = decoded.getPixel(8, 8);
    expect(paper.b.toInt(), greaterThan(150), reason: 'page shows through');
    expect(paper.r.toInt(), lessThan(80));

    final ink = decoded.getPixel(40, 40);
    expect(ink.r.toInt(), lessThan(50), reason: 'ink is dark');
    expect(ink.g.toInt(), lessThan(50));
    expect(ink.b.toInt(), lessThan(80));
  });

  test('PageStamp.rotatedClockwise maps the rect into the new page', () {
    const stamp = PageStamp(
      imagePath: 'sig.png',
      nx: 0.1,
      ny: 0.2,
      nw: 0.3,
      nh: 0.4,
    );
    final rotated = stamp.rotatedClockwise();
    expect(rotated.nx, closeTo(0.4, 0.0001));
    expect(rotated.ny, closeTo(0.1, 0.0001));
    expect(rotated.nw, closeTo(0.4, 0.0001));
    expect(rotated.nh, closeTo(0.3, 0.0001));
  });
}
