import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/features/pro/data/docx_images.dart';

import '../support/scanned_docx.dart';

img.Image _pageIn(Uint8List docx, String name) {
  final archive = ZipDecoder().decodeBytes(docx);
  return img.PngDecoder().decode(
    Uint8List.fromList(archive.findFile(name)!.content as List<int>),
  )!;
}

void main() {
  test('a page that names a black background comes back without one', () {
    final page = indexedPageWithBlackBackground();
    final before = readPngFacts(page);
    expect(before.isIndexed, isTrue, reason: 'the fixture must be indexed');
    expect(before.hasBackground, isTrue);

    final repaired = repairDocxImages(
      docxWith({'word/media/image2.png': page}),
    );

    final after = pageFactsIn(repaired).single;
    expect(after.isIndexed, isFalse);
    expect(after.hasBackground, isFalse);
  });

  test(
    'the page still shows what it showed: ink on paper, not a black box',
    () {
      final repaired = repairDocxImages(
        docxWith({'word/media/image2.png': indexedPageWithBlackBackground()}),
      );

      final page = _pageIn(repaired, 'word/media/image2.png');
      expect(page.width, 60);
      expect(page.height, 40);
      // Paper above the line, ink on it.
      expect(page.getPixel(30, 5).r, greaterThan(200));
      expect(page.getPixel(30, 20).r, lessThan(60));

      var light = 0;
      for (var y = 0; y < page.height; y++) {
        for (var x = 0; x < page.width; x++) {
          if (page.getPixel(x, y).r > 200) light++;
        }
      }
      expect(
        light / (page.width * page.height),
        greaterThan(0.8),
        reason: 'the page should still be mostly paper',
      );
    },
  );

  // A scan written back out in colour would be three times the size for
  // nothing, and a long document is mostly these.
  test('a grey page stays grey rather than being written out in colour', () {
    final repaired = repairDocxImages(
      docxWith({'word/media/image2.png': indexedPageWithBlackBackground()}),
    );

    expect(pageFactsIn(repaired).single.colourType, 0);
  });

  test('a colour page that draws correctly is left exactly as it was', () {
    final colour = img.Image(width: 20, height: 20);
    img.fill(colour, color: img.ColorRgb8(10, 120, 200));
    final docx = docxWith({
      'word/media/image1.png': Uint8List.fromList(
        img.PngEncoder().encode(colour, singleFrame: true),
      ),
    });

    expect(identical(repairDocxImages(docx), docx), isTrue);
  });

  test('anything that is not a .docx is handed straight back', () {
    final notAZip = Uint8List.fromList('%PDF-1.7 hello'.codeUnits);
    expect(identical(repairDocxImages(notAZip), notAZip), isTrue);
  });

  test('the rest of the document survives the rewrite', () {
    final out = ZipDecoder().decodeBytes(
      repairDocxImages(
        docxWith({'word/media/image2.png': indexedPageWithBlackBackground()}),
      ),
    );

    expect(out.findFile('[Content_Types].xml'), isNotNull);
    expect(
      String.fromCharCodes(
        out.findFile('word/document.xml')!.content as List<int>,
      ),
      contains('w:document'),
    );
  });
}
