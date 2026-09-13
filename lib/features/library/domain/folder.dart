import 'package:flutter/foundation.dart';

/// A named group of scans on the home page.
@immutable
class Folder {
  const Folder({required this.id, required this.name, required this.createdAt});

  final int id;
  final String name;
  final DateTime createdAt;

  Folder copyWith({String? name}) {
    return Folder(id: id, name: name ?? this.name, createdAt: createdAt);
  }
}
