import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:scan2/features/library/data/document_storage.dart';
import 'package:scan2/features/library/data/document_store.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/export_service.dart';
import 'package:scan2/features/library/domain/page_stamp.dart';
import 'package:scan2/features/signatures/presentation/signature_pad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a drawn signature is ink in the saved PDF', (tester) async {
    await tester.runAsync(() async {
      final temp = Directory.systemTemp.createTempSync('scan2_sign_flow');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      final png = await encodeSignaturePng(
        [
          [
            const Offset(20, 40),
            const Offset(60, 18),
            const Offset(110, 48),
            const Offset(160, 22),
            const Offset(200, 44),
          ],
        ],
        logicalSize: const Size(240, 80),
        pixelRatio: 3,
      );
      expect(png, isNotNull);
      final sigFile = File(p.join(temp.path, 'drawn.png'));
      sigFile.writeAsBytesSync(png!);

      final page = img.Image(width: 400, height: 520);
      for (var y = 0; y < 520; y++) {
        for (var x = 0; x < 400; x++) {
          page.setPixelRgb(x, y, 50, 110, 210);
        }
      }
      final pageFile = File(p.join(temp.path, 'page.jpg'));
      pageFile.writeAsBytesSync(img.encodeJpg(page, quality: 95));

      final store = DocumentStore(
        storage: DocumentStorage(
          overrideRoot: Directory(p.join(temp.path, 'lib')),
        ),
      );
      final doc = await store.createDocumentFromScans([pageFile.path]);
      await store.setPageStamps(
        documentId: doc.id,
        pagePath: doc.pagePaths.first,
        stamps: [
          PageStamp(
            imagePath: sigFile.path,
            nx: 0.5,
            ny: 0.72,
            nw: 0.42,
            nh: 0.18,
          ),
        ],
      );

      final saved = (await store.getDocument(doc.id))!;
      final pdf = await const ExportService().buildPdfBytes(saved);
      final jpeg = firstJpegIn(pdf);
      expect(jpeg, isNotNull, reason: 'exported PDF must embed the page');
      final decoded = img.decodeImage(jpeg!)!;

      var dark = 0;
      for (
        var y = (0.72 * decoded.height).round();
        y < (0.90 * decoded.height).round();
        y += 2
      ) {
        for (
          var x = (0.50 * decoded.width).round();
          x < (0.92 * decoded.width).round();
          x += 2
        ) {
          final pixel = decoded.getPixel(
            x.clamp(0, decoded.width - 1),
            y.clamp(0, decoded.height - 1),
          );
          if (pixel.r.toInt() < 80 && pixel.g.toInt() < 80) dark++;
        }
      }
      expect(dark, greaterThan(8), reason: 'saved PDF must show the drawn ink');
      expect(decoded.getPixel(20, 20).b.toInt(), greaterThan(140));
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
