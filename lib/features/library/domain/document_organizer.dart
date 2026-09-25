import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:scan2/features/library/domain/document.dart';

/// Names, categories and duplicate hashes derived from on-device OCR.
class DocumentOrganizer {
  const DocumentOrganizer();

  /// True for the titles the app invents itself, which are safe to replace
  /// once OCR has read a real heading.
  static bool isGenericTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return true;
    return RegExp(
      r'^(scan|document|pdf|merged scan|image)\b',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  /// A short title from the first meaningful line of [text].
  String suggestTitle(String text, {String? fallback}) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.length >= 4);
    for (final line in lines) {
      if (_junkLine.hasMatch(line)) continue;
      final clipped = line.length > 48
          ? '${line.substring(0, 45).trim()}…'
          : line;
      return clipped;
    }
    return fallback ?? 'Scan';
  }

  /// Keyword categories used by smart folders.
  String? categorize(String text) {
    final hay = text.toLowerCase();
    for (final rule in _categoryRules) {
      for (final word in rule.words) {
        if (hay.contains(word)) return rule.category;
      }
    }
    return null;
  }

  /// Passport vs ID card for auto-file. Passport wins when both match.
  IdentityKind detectIdentity(String text) {
    final hay = text.toLowerCase();
    if (_mrz.hasMatch(text)) return IdentityKind.passport;
    for (final word in _passportWords) {
      if (hay.contains(word)) return IdentityKind.passport;
    }
    for (final word in _idCardWords) {
      if (hay.contains(word)) return IdentityKind.idCard;
    }
    return IdentityKind.none;
  }

  String hashBytes(List<int> bytes) => sha256.convert(bytes).toString();

  /// Documents that share a [Document.contentHash] with at least one other.
  List<Document> duplicatesAmong(Iterable<Document> documents) {
    final counts = <String, int>{};
    for (final doc in documents) {
      final hash = doc.contentHash;
      if (hash == null || hash.isEmpty) continue;
      counts[hash] = (counts[hash] ?? 0) + 1;
    }
    return [
      for (final doc in documents)
        if (doc.contentHash != null && (counts[doc.contentHash] ?? 0) > 1) doc,
    ];
  }

  static final _junkLine = RegExp(
    r'^(page\s+\d+|https?:|www\.|tel:|fax:)',
    caseSensitive: false,
  );

  static final _mrz = RegExp(r'\bP<[A-Z]{3}');

  static const _passportWords = [
    'passport',
    'passeport',
    'pasaporte',
    'reisepass',
    'passaporto',
  ];

  static const _idCardWords = [
    'identity card',
    'national identity',
    'identification card',
    'id card',
    'driver licence',
    'driver license',
    "driver's license",
    'driving licence',
    'driving license',
    'aadhaar',
    'aadhar',
    'pan card',
  ];

  static const _categoryRules = <_CategoryRule>[
    _CategoryRule('receipt', ['receipt', 'thank you for your', 'change due']),
    _CategoryRule('invoice', [
      'invoice',
      'amount due',
      'bill to',
      'tax invoice',
    ]),
    _CategoryRule('id', [
      'passport',
      'driver licence',
      'driver license',
      'identity card',
      'date of birth',
    ]),
    _CategoryRule('contract', [
      'agreement',
      'hereinafter',
      'the parties',
      'terms and conditions',
    ]),
    _CategoryRule('statement', [
      'account statement',
      'bank statement',
      'opening balance',
      'closing balance',
    ]),
  ];
}

enum IdentityKind { none, passport, idCard }

@immutable
class _CategoryRule {
  const _CategoryRule(this.category, this.words);

  final String category;
  final List<String> words;
}
