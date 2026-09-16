import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:scan2/features/pro/data/conversion_service.dart';
import 'package:scan2/features/pro/domain/image_pdf_convert.dart';

/// Rotate, page numbers, watermark and unlock — raster the PDF on the phone,
/// edit the page pictures, write a new PDF. Nothing is uploaded.
class PdfPageTools {
  const PdfPageTools({
    this.convert = const ImagePdfConvert(),
    this.pagesFromPdf,
    this.unlockPdf,
  });

  final ImagePdfConvert convert;

  /// Tests inject rasters so they never call PDFKit / PdfRenderer.
  final Future<List<Uint8List>> Function(Uint8List pdf)? pagesFromPdf;

  /// Tests inject the unlocked bytes. On a device this is PDFKit rewriting
  /// the file without a lock, then a raster rebuild if that is missing.
  final Future<Uint8List> Function(Uint8List pdf, String password)? unlockPdf;

  Future<Uint8List> rotate(
    Uint8List pdfBytes, {
    int quarterTurns = 1,
  }) async {
    final turns = quarterTurns % 4;
    if (turns == 0) {
      throw StateError('Choose how far to turn the pages.');
    }
    final pages = await _pages(pdfBytes);
    return convert.imagesToPdf([
      for (final page in pages) rotateEncoded(page, quarterTurns: turns),
    ]);
  }

  Future<Uint8List> addPageNumbers(Uint8List pdfBytes) async {
    final pages = await _pages(pdfBytes);
    return convert.imagesToPdf([
      for (var i = 0; i < pages.length; i++)
        stampPageNumber(pages[i], page: i + 1, of: pages.length),
    ]);
  }

  Future<Uint8List> addWatermark(
    Uint8List pdfBytes, {
    required String text,
  }) async {
    final label = text.trim();
    if (label.isEmpty) {
      throw StateError('Write a watermark first.');
    }
    final pages = await _pages(pdfBytes);
    return convert.imagesToPdf([
      for (final page in pages) stampWatermark(page, label),
    ]);
  }

  Future<Uint8List> unlock(
    Uint8List pdfBytes, {
    String password = '',
  }) async {
    if (!pdfLooksEncrypted(pdfBytes)) {
      throw const ConversionFailure('not-locked', 'This PDF is not locked.');
    }
    try {
      return await (unlockPdf ?? nativeUnlockPdf)(pdfBytes, password);
    } on ConversionFailure {
      rethrow;
    } on MissingPluginException {
      return _rasterUnlocked(pdfBytes, password: password);
    } on PlatformException catch (e) {
      if (e.code == 'wrong_password' || e.code == 'encrypted') {
        throw ConversionFailure(
          'wrong-password',
          _wrongPasswordMessage(password),
        );
      }
      return _rasterUnlocked(pdfBytes, password: password);
    } catch (_) {
      return _rasterUnlocked(pdfBytes, password: password);
    }
  }

  Future<List<Uint8List>> _pages(Uint8List pdfBytes) {
    return pagesFromPdf?.call(pdfBytes) ??
        convert.pdfToImages(pdfBytes, png: false);
  }

  Future<Uint8List> _rasterUnlocked(
    Uint8List pdfBytes, {
    required String password,
  }) async {
    try {
      final pages = await _pages(pdfBytes);
      return convert.imagesToPdf(pages);
    } catch (_) {
      throw ConversionFailure(
        'wrong-password',
        _wrongPasswordMessage(password),
      );
    }
  }
}

String _wrongPasswordMessage(String password) {
  return password.trim().isEmpty
      ? 'This PDF is locked. Enter the password, then try again.'
      : 'Could not open this locked PDF. Check the password and try again.';
}

/// True when the file carries a Standard Security / Encrypt dictionary.
bool pdfLooksEncrypted(Uint8List bytes) {
  final start = bytes.length < 512000 ? bytes.length : 512000;
  final head = String.fromCharCodes(bytes.sublist(0, start));
  if (head.contains('/Encrypt')) return true;
  if (bytes.length <= start) return false;
  final tailFrom = bytes.length - 8000 < start ? start : bytes.length - 8000;
  return String.fromCharCodes(bytes.sublist(tailFrom)).contains('/Encrypt');
}

Future<Uint8List> nativeUnlockPdf(Uint8List pdf, String password) async {
  const channel = MethodChannel('scanella/pdf');
  final result = await channel.invokeMethod<dynamic>('unlock', {
    'bytes': pdf,
    'password': password,
  });
  if (result is Uint8List && result.isNotEmpty) return result;
  throw const ConversionFailure(
    'wrong-password',
    'Could not open this locked PDF. Check the password and try again.',
  );
}

/// 90° clockwise per [quarterTurns] (1, 2 or 3).
Uint8List rotateEncoded(Uint8List encoded, {required int quarterTurns}) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw StateError('That PDF page could not be rotated.');
  }
  final turns = quarterTurns % 4;
  if (turns == 0) return encoded;
  final rotated = img.copyRotate(decoded, angle: 90 * turns);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
}

/// Dark "1 / 3" at the bottom centre of the page image.
Uint8List stampPageNumber(
  Uint8List encoded, {
  required int page,
  required int of,
}) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) {
    throw StateError('That PDF page could not be numbered.');
  }
  final canvas = decoded.convert(numChannels: 3);
  final label = '$page / $of';
  final font = canvas.width >= 360 ? img.arial24 : img.arial14;
  final width = _textWidth(font, label);
  final x = ((canvas.width - width) / 2).round();
  final y = canvas.height - font.lineHeight - (canvas.height >= 200 ? 18 : 6);
  img.drawString(
    canvas,
    label,
    font: font,
    x: x.clamp(0, canvas.width - 1),
    y: y.clamp(0, canvas.height - 1),
    color: img.ColorRgb8(28, 28, 28),
  );
  return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
}

/// Dark watermark across the middle of the page image.
Uint8List stampWatermark(Uint8List encoded, String text) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) {
    throw StateError('That PDF page could not be watermarked.');
  }
  final canvas = decoded.convert(numChannels: 3);
  final label = text.trim();
  final font = canvas.width >= 400 ? img.arial48 : img.arial24;
  final width = _textWidth(font, label);
  final x = ((canvas.width - width) / 2).round();
  final y = ((canvas.height - font.lineHeight) / 2).round();
  img.drawString(
    canvas,
    label,
    font: font,
    x: x.clamp(0, canvas.width - 1),
    y: y.clamp(0, canvas.height - 1),
    color: img.ColorRgb8(48, 48, 48),
  );
  return Uint8List.fromList(img.encodeJpg(canvas, quality: 92));
}

int _textWidth(img.BitmapFont font, String text) {
  var width = 0;
  for (final unit in text.codeUnits) {
    final ch = font.characters[unit];
    width += ch?.xAdvance ?? (font.lineHeight ~/ 2);
  }
  return width;
}
