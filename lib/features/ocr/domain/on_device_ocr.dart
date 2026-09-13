import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:scan2/features/library/domain/ocr_layout.dart';

/// On-device text recognition: Vision on iOS, ML Kit on Android.
class OnDeviceOcr {
  OnDeviceOcr({this.engine, this.pageEngine});

  static const channel = MethodChannel('scanella/ocr');

  /// Injected in tests so widget tests do not need a platform view.
  final Future<String> Function(Uint8List bytes)? engine;

  /// Optional layout-aware engine for tests.
  final Future<OcrPageResult> Function(Uint8List bytes, String? language)?
  pageEngine;

  Future<String> recognize(Uint8List bytes, {String? language}) async {
    final page = await recognizePage(bytes, language: language);
    return page.text;
  }

  Future<OcrPageResult> recognizePage(
    Uint8List bytes, {
    String? language,
    int pageIndex = 0,
  }) async {
    if (pageEngine != null) {
      final result = await pageEngine!(bytes, language);
      return OcrPageResult(
        text: result.text,
        blocks: [
          for (final block in result.blocks)
            OcrBlock(
              text: block.text,
              left: block.left,
              top: block.top,
              width: block.width,
              height: block.height,
              pageIndex: pageIndex,
            ),
        ],
      );
    }
    if (engine != null) {
      return OcrPageResult(text: await engine!(bytes));
    }
    if (kIsWeb) {
      throw StateError('OCR is available on iOS and Android.');
    }
    try {
      final raw = await channel.invokeMethod<dynamic>('recognize', {
        'bytes': bytes,
        if (language != null) 'language': language,
      });
      return _parse(raw, pageIndex);
    } on MissingPluginException {
      throw StateError('Text recognition is not available on this build.');
    } on PlatformException catch (e) {
      throw StateError(e.message ?? 'Could not read text from that image.');
    }
  }

  static OcrPageResult _parse(dynamic raw, int pageIndex) {
    if (raw is String) return OcrPageResult(text: raw.trim());
    if (raw is! Map) return const OcrPageResult(text: '');
    final text = (raw['text'] as String? ?? '').trim();
    final blocks = <OcrBlock>[];
    final rawBlocks = raw['blocks'];
    if (rawBlocks is List) {
      for (final entry in rawBlocks) {
        final block = OcrBlock.fromJson(entry);
        if (block == null) continue;
        blocks.add(
          OcrBlock(
            text: block.text,
            left: block.left,
            top: block.top,
            width: block.width,
            height: block.height,
            pageIndex: pageIndex,
          ),
        );
      }
    }
    return OcrPageResult(text: text, blocks: blocks);
  }
}
