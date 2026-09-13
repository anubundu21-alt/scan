import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

/// A page picture the way the conversion service writes a scanned one: an
/// index into a palette whose first entry is black, plus a `bKGD` chunk naming
/// that entry. Readers that take the hint paint the whole page black.
Uint8List indexedPageWithBlackBackground({int width = 60, int height = 40}) {
  // Three channels because a PNG palette is always RGB triples, and the grey
  // ramp the service writes has to be read back as grey.
  final image = img.Image(
    width: width,
    height: height,
    numChannels: 3,
    withPalette: true,
    paletteFormat: img.Format.uint8,
  );
  final palette = image.palette!;
  for (var i = 0; i < 256; i++) {
    palette.setRgb(i, i, i, i);
  }
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final ink = y >= 18 && y < 22 && x >= 8 && x < width - 8;
      image.setPixelIndex(x, y, ink ? 20 : 245);
    }
  }
  return _withBackgroundChunk(
    Uint8List.fromList(img.PngEncoder().encode(image, singleFrame: true)),
  );
}

/// A .docx carrying [media], enough of one for the parts under test.
Uint8List docxWith(Map<String, Uint8List> media) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        '[Content_Types].xml',
        '<?xml version="1.0"?><Types/>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'word/document.xml',
        '<?xml version="1.0"?><w:document/>',
      ),
    );
  media.forEach((name, bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// What a reader has to work out before it can draw a PNG.
class PngFacts {
  const PngFacts({required this.colourType, required this.hasBackground});

  final int colourType;
  final bool hasBackground;

  bool get isIndexed => colourType == 3;
}

PngFacts readPngFacts(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  var offset = 8;
  var colourType = -1;
  var hasBackground = false;
  while (offset + 8 <= bytes.length) {
    final length = view.getUint32(offset);
    final name = String.fromCharCodes(bytes, offset + 4, offset + 8);
    if (name == 'IHDR') colourType = bytes[offset + 8 + 9];
    if (name == 'bKGD') hasBackground = true;
    offset += 12 + length;
  }
  return PngFacts(colourType: colourType, hasBackground: hasBackground);
}

/// Every page picture in [docx], in the order a reader would meet them.
List<PngFacts> pageFactsIn(Uint8List docx) {
  final archive = ZipDecoder().decodeBytes(docx);
  return [
    for (final file in archive.files)
      if (file.isFile && file.name.startsWith('word/media/'))
        readPngFacts(Uint8List.fromList(file.content as List<int>)),
  ];
}

Uint8List _withBackgroundChunk(Uint8List png) {
  final out = BytesBuilder();
  final view = ByteData.sublistView(png);
  out.add(png.sublist(0, 8));
  var offset = 8;
  var inserted = false;
  while (offset + 8 <= png.length) {
    final length = view.getUint32(offset);
    final name = String.fromCharCodes(png, offset + 4, offset + 8);
    if (name == 'IDAT' && !inserted) {
      out.add(_chunk('bKGD', Uint8List.fromList(const [0])));
      inserted = true;
    }
    out.add(png.sublist(offset, offset + 12 + length));
    offset += 12 + length;
  }
  return out.toBytes();
}

Uint8List _chunk(String name, Uint8List data) {
  final body =
      (BytesBuilder()
            ..add(name.codeUnits)
            ..add(data))
          .toBytes();
  final out = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(body)
    ..add((ByteData(4)..setUint32(0, getCrc32(body))).buffer.asUint8List());
  return out.toBytes();
}
