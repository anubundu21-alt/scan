import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

const _mediaPrefix = 'word/media/';

/// Repairs the page pictures inside a converted .docx.
///
/// The conversion service writes a colour page as a truecolour PNG, but a grey
/// or black-and-white page — which is what a scan is — as an indexed one
/// carrying a `bKGD` chunk that names palette entry 0. On the pages we saw,
/// entry 0 is black. A reader that takes that hint paints the page black, so a
/// book came back with its colour cover intact and every scanned page after it
/// solid black.
///
/// Rewriting those as plain PNGs keeps every pixel — an index into a palette
/// and the colour it stands for are the same colour — and drops the hint.
///
/// Returns [docx] unchanged when nothing needed it, or when the bytes are not
/// a .docx at all.
Uint8List repairDocxImages(Uint8List docx) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(docx);
  } catch (_) {
    return docx;
  }

  var repairedAny = false;
  final out = Archive();
  for (final entry in archive.files) {
    if (!entry.isFile) {
      out.addFile(entry);
      continue;
    }
    final bytes = Uint8List.fromList(entry.content as List<int>);
    final repaired = _needsRepair(entry.name) ? _repairPng(bytes) : null;
    if (repaired == null) {
      out.addFile(entry);
      continue;
    }
    repairedAny = true;
    out.addFile(ArchiveFile(entry.name, repaired.length, repaired));
  }
  if (!repairedAny) return docx;

  final zipped = ZipEncoder().encode(out);
  if (zipped == null || zipped.isEmpty) return docx;
  return Uint8List.fromList(zipped);
}

bool _needsRepair(String name) =>
    name.startsWith(_mediaPrefix) && name.toLowerCase().endsWith('.png');

/// Null when the picture is already one every reader draws the same way, so
/// most files come back untouched and nothing is re-encoded for nothing.
Uint8List? _repairPng(Uint8List bytes) {
  final header = _readHeader(bytes);
  if (header == null) return null;
  if (!header.isIndexed && !header.hasBackground) return null;

  try {
    final decoded = img.PngDecoder().decode(bytes);
    if (decoded == null) return null;
    final plain = decoded.convert(
      format: img.Format.uint8,
      // A scan is grey, and saying so keeps the file about a third the size
      // of the same page written out in colour.
      numChannels: _isGrey(decoded) ? 1 : 3,
      withPalette: false,
    );
    return img.PngEncoder().encode(plain, singleFrame: true);
  } catch (_) {
    return null;
  }
}

bool _isGrey(img.Image image) {
  final palette = image.palette;
  if (palette != null) {
    for (var i = 0; i < palette.numColors; i++) {
      if (palette.getRed(i) != palette.getGreen(i) ||
          palette.getGreen(i) != palette.getBlue(i)) {
        return false;
      }
    }
    return true;
  }
  if (image.numChannels < 3) return true;
  for (final pixel in image) {
    if (pixel.r != pixel.g || pixel.g != pixel.b) return false;
  }
  return true;
}

class _PngHeader {
  const _PngHeader({required this.isIndexed, required this.hasBackground});

  final bool isIndexed;
  final bool hasBackground;
}

const _signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// Walks the chunk list far enough to see the colour type and whether a
/// background was named. Cheaper than decoding a picture we may not touch.
_PngHeader? _readHeader(Uint8List bytes) {
  if (bytes.length < 8 + 12 + 13) return null;
  for (var i = 0; i < _signature.length; i++) {
    if (bytes[i] != _signature[i]) return null;
  }

  final view = ByteData.sublistView(bytes);
  var isIndexed = false;
  var hasBackground = false;
  var offset = 8;
  var sawHeader = false;

  while (offset + 8 <= bytes.length) {
    final length = view.getUint32(offset);
    final name = String.fromCharCodes(bytes, offset + 4, offset + 8);
    if (name == 'IHDR') {
      if (offset + 8 + 13 > bytes.length) return null;
      isIndexed = bytes[offset + 8 + 9] == 3;
      sawHeader = true;
    } else if (name == 'bKGD') {
      hasBackground = true;
    } else if (name == 'IDAT' || name == 'IEND') {
      // Everything that matters is declared before the pixels.
      break;
    }
    offset += 12 + length;
  }

  if (!sawHeader) return null;
  return _PngHeader(isIndexed: isIndexed, hasBackground: hasBackground);
}
