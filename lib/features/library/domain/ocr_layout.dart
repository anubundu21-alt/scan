import 'package:flutter/foundation.dart';

/// One recognised line or word, in normalised page coordinates.
///
/// Origin is top-left, matching how we paint a page. Native Vision reports
/// a bottom-left origin; the platform channel flips Y before this reaches
/// Dart.
@immutable
class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.pageIndex = 0,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
  final int pageIndex;

  Map<String, dynamic> toJson() => {
    'text': text,
    'l': left,
    't': top,
    'w': width,
    'h': height,
    'p': pageIndex,
  };

  static OcrBlock? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = (raw['text'] as String? ?? '').trim();
    if (text.isEmpty) return null;
    return OcrBlock(
      text: text,
      left: (raw['l'] as num?)?.toDouble() ?? 0,
      top: (raw['t'] as num?)?.toDouble() ?? 0,
      width: (raw['w'] as num?)?.toDouble() ?? 1,
      height: (raw['h'] as num?)?.toDouble() ?? 0.04,
      pageIndex: (raw['p'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A language the on-device recogniser can be asked to prefer.
@immutable
class OcrLanguage {
  const OcrLanguage({
    required this.code,
    required this.label,
    required this.script,
  });

  /// BCP-47 / Vision identifier.
  final String code;
  final String label;

  /// ML Kit script group: latin, chinese, japanese, korean, devanagari.
  final String script;

  static const english = OcrLanguage(
    code: 'en-US',
    label: 'English',
    script: 'latin',
  );

  static const all = <OcrLanguage>[
    english,
    OcrLanguage(code: 'es-ES', label: 'Spanish', script: 'latin'),
    OcrLanguage(code: 'fr-FR', label: 'French', script: 'latin'),
    OcrLanguage(code: 'de-DE', label: 'German', script: 'latin'),
    OcrLanguage(code: 'it-IT', label: 'Italian', script: 'latin'),
    OcrLanguage(code: 'pt-BR', label: 'Portuguese', script: 'latin'),
    OcrLanguage(code: 'zh-Hans', label: 'Chinese', script: 'chinese'),
    OcrLanguage(code: 'ja-JP', label: 'Japanese', script: 'japanese'),
    OcrLanguage(code: 'ko-KR', label: 'Korean', script: 'korean'),
    OcrLanguage(code: 'hi-IN', label: 'Hindi', script: 'devanagari'),
  ];

  static OcrLanguage byCode(String? code) {
    if (code == null) return english;
    for (final language in all) {
      if (language.code == code) return language;
    }
    return english;
  }
}

class OcrPageResult {
  const OcrPageResult({required this.text, this.blocks = const []});

  final String text;
  final List<OcrBlock> blocks;
}
