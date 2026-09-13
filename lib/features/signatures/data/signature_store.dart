import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scan2/features/signatures/domain/saved_signature.dart';

/// Drawn signatures kept on device, reused across documents.
class SignatureStore {
  SignatureStore({Directory? overrideRoot}) : _overrideRoot = overrideRoot;

  final Directory? _overrideRoot;
  Directory? _cachedRoot;

  static const _indexName = 'index.json';

  Future<Directory> _root() async {
    final cached = _cachedRoot;
    if (cached != null) return cached;
    final base = _overrideRoot ?? await getApplicationDocumentsDirectory();
    final root = Directory(p.join(base.path, 'signatures'));
    if (!await root.exists()) await root.create(recursive: true);
    _cachedRoot = root;
    return root;
  }

  Future<String> _rootPath() async => (await _root()).path;

  Future<List<SavedSignature>> list() async {
    final root = await _root();
    final file = File(p.join(root.path, _indexName));
    if (!await file.exists()) return const [];
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return const [];
      return [
        for (final entry in raw)
          ?SavedSignature.fromJson(
            entry,
            (rel) => p.isAbsolute(rel) ? rel : p.join(root.path, rel),
          ),
      ].where((s) => File(s.path).existsSync()).toList();
    } catch (e) {
      debugPrint('Signature index unreadable: $e');
      return const [];
    }
  }

  Future<SavedSignature> savePng(Uint8List png) async {
    final root = await _root();
    final id = _newId();
    final file = File(p.join(root.path, '$id.png'));
    await file.writeAsBytes(png, flush: true);
    final signature = SavedSignature(
      id: id,
      path: file.path,
      createdAt: DateTime.now(),
    );
    final all = [...await list(), signature];
    await _writeIndex(all);
    return signature;
  }

  Future<void> delete(String id) async {
    final all = await list();
    SavedSignature? removed;
    final kept = <SavedSignature>[];
    for (final signature in all) {
      if (signature.id == id) {
        removed = signature;
      } else {
        kept.add(signature);
      }
    }
    await _writeIndex(kept);
    final path = removed?.path;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<void> _writeIndex(List<SavedSignature> signatures) async {
    final rootPath = await _rootPath();
    final file = File(p.join(rootPath, _indexName));
    final payload = [
      for (final signature in signatures)
        {
          'id': signature.id,
          'path': p.basename(signature.path),
          'createdAt': signature.createdAt.toIso8601String(),
        },
    ];
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  static String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20).toRadixString(16);
    return 'sig_${now}_$rand';
  }
}
