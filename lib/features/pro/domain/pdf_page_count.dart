import 'dart:convert';

/// How many pages a PDF claims to have, from the bytes on disk.
///
/// This counts page objects (`/Type /Page`) and ignores the `/Pages` tree
/// node. It is good enough to label a range field after a pick; the converter
/// still decides what actually comes back.
int countPdfPages(List<int> bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Type\s*/Page(?!s)').allMatches(text).length;
}

/// A keep-pages range that covers the whole file, or `1-3` when the count
/// could not be read.
String defaultKeepRange(int pageCount) {
  if (pageCount < 1) return '1-3';
  return '1-$pageCount';
}
