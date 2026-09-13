import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scan2/features/pro/domain/file_conversion.dart';
import 'package:scan2/features/pro/presentation/conversion_flow.dart';

/// Pro tool: pick a PDF, convert it to Word, then share the .docx.
class PdfToWordScreen extends StatefulWidget {
  const PdfToWordScreen({super.key, this.converter});

  /// Tests inject a converter so the screen never calls the service.
  final FileConverter? converter;

  @override
  State<PdfToWordScreen> createState() => _PdfToWordScreenState();
}

class _PdfToWordScreenState extends State<PdfToWordScreen>
    with ConversionRunner<PdfToWordScreen> {
  FileConverter? _owned;

  FileConverter get _converter =>
      widget.converter ?? (_owned ??= FileConverter());

  Future<void> _uploadPdf() async {
    if (isBusy) return;
    if (kIsWeb) {
      showConversionMessage('PDF to Word is available on iOS and Android.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ConversionKind.pdfToWord.sourceExtensions,
    );
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty) return;
    final path = files.first.path;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    await runConversion(
      (onProgress) => _converter.convertFile(
        bytes,
        sourceName: p.basename(path),
        kind: ConversionKind.pdfToWord,
        onProgress: onProgress,
      ),
      doneMessage: 'PDF converted to Word.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('PDF to Word')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Upload a PDF and get back an editable Word file with the '
                'layout, tables and images kept. Converting needs a '
                'connection; your file is deleted as soon as it comes back.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (!_converter.isConfigured) ...[
                const ConversionUnavailableNotice(),
                const SizedBox(height: 16),
              ],
              ConversionUploadTile(
                title: 'Upload a PDF',
                subtitle: 'Choose a file from Files, then convert to Word.',
                icon: Icons.description_rounded,
                onPressed: isBusy ? null : _uploadPdf,
              ),
            ],
          ),
          ConversionOverlay(status: status),
        ],
      ),
    );
  }
}
