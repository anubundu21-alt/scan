import 'package:flutter/foundation.dart';

@immutable
class SavedSignature {
  const SavedSignature({
    required this.id,
    required this.path,
    required this.createdAt,
  });

  final String id;
  final String path;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'createdAt': createdAt.toIso8601String(),
  };

  static SavedSignature? fromJson(
    Object? raw,
    String Function(String rel) resolve,
  ) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final path = raw['path'];
    if (id is! String || path is! String) return null;
    return SavedSignature(
      id: id,
      path: resolve(path),
      createdAt:
          DateTime.tryParse(raw['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
