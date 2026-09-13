import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/export_service.dart';
import 'package:scan2/features/library/domain/pdf_export_options.dart';
import 'package:scan2/features/pro/data/conversion_service.dart';

export 'package:scan2/features/pro/data/conversion_service.dart'
    show
        CompressionLevel,
        ConversionFailure,
        ConversionKind,
        ConversionOptions,
        ConversionProgress,
        ConversionSource,
        ConversionStage,
        ConversionStatus,
        ConversionService,
        ConvertedFile;

/// Pro tools that run off the device: convert, compress, merge and split.
///
/// The job itself runs on the conversion service, because keeping a document's
/// text and vectors through those steps needs an engine no phone ships with.
/// This class decides what to send, what to call the result, and how to
/// describe a failure.
class FileConverter {
  FileConverter({ConversionService? service, ExportService? exporter})
    : _service = service ?? ConversionService(),
      _exporter = exporter ?? const ExportService();

  final ConversionService _service;
  final ExportService _exporter;

  bool get isConfigured => _service.isConfigured;

  /// Converts a file the customer picked from Files.
  Future<ConvertedFile> convertFile(
    Uint8List bytes, {
    required String sourceName,
    required ConversionKind kind,
    ConversionOptions? options,
    ConversionProgress? onProgress,
  }) {
    return convertFiles(
      [ConversionSource(bytes: bytes, filename: sourceName)],
      kind: kind,
      options: options,
      onProgress: onProgress,
    );
  }

  /// Merging is the one job that takes more than a file, and they go up in
  /// the order they are given.
  Future<ConvertedFile> convertFiles(
    List<ConversionSource> sources, {
    required ConversionKind kind,
    ConversionOptions? options,
    ConversionProgress? onProgress,
  }) async {
    if (kIsWeb) {
      throw const ConversionFailure(
        'platform',
        'These tools are available on iOS and Android.',
      );
    }
    if (sources.isEmpty || sources.any((source) => source.bytes.isEmpty)) {
      throw ConversionFailure('empty', switch (kind) {
        ConversionKind.wordToPdf => 'That document is empty.',
        _ => 'That PDF has no pages that could be read.',
      });
    }
    return _service.convertAll(
      sources: sources,
      kind: kind,
      options: options,
      onProgress: onProgress,
    );
  }

  /// Converts a PDF already in the library.
  ///
  /// The pages are laid back into a PDF first, so the service sees the same
  /// file someone would have got from Share. A camera scan is a picture of a
  /// page with no text layer, so the Word file comes back as the picture —
  /// Extract text is the tool for pulling words off a scan.
  Future<ConvertedFile> convertDocument(
    Document document, {
    ConversionProgress? onProgress,
  }) async {
    if (kIsWeb) {
      throw const ConversionFailure(
        'platform',
        'Converting is available on iOS and Android.',
      );
    }
    if (document.pages.isEmpty) {
      throw const ConversionFailure(
        'empty',
        'That PDF has no pages that could be read.',
      );
    }
    onProgress?.call(
      const ConversionStatus(
        stage: ConversionStage.starting,
        message: 'Reading PDF…',
        fraction: 0,
      ),
    );
    final Uint8List pdfBytes;
    try {
      pdfBytes = await _exporter.buildPdfBytes(
        document,
        options: const PdfExportOptions(),
      );
    } catch (e) {
      throw ConversionFailure('corrupt', readableConversionError(e));
    }
    return convertFile(
      pdfBytes,
      sourceName: '${document.title}.pdf',
      kind: ConversionKind.pdfToWord,
      onProgress: onProgress,
    );
  }
}

/// Turns whatever the service or the platform threw into one line a customer
/// can act on.
String readableConversionError(Object error) {
  if (error is ConversionFailure) {
    return switch (error.code) {
      'password' =>
        'That file is password-protected. Unlock it first, then convert it.',
      'corrupt' => 'That file could not be read. It may be damaged.',
      'unconfigured' =>
        'Converting is not available in this build of the app yet.',
      _ => error.message,
    };
  }
  if (error is SocketException) {
    return 'Could not reach the converter. Check your connection and try again.';
  }
  if (error is FileSystemException) {
    return 'That file could not be read.';
  }
  final text = error is StateError ? error.message : error.toString();
  if (RegExp('password|encrypt', caseSensitive: false).hasMatch(text)) {
    return 'That file is password-protected. Unlock it first, then convert it.';
  }
  if (text.startsWith('Bad state: ')) return text.substring(11);
  return text.isEmpty ? 'That file could not be converted.' : text;
}
