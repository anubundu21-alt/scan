import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scan2/features/pro/domain/file_conversion.dart';
import 'package:scan2/features/pro/presentation/conversion_flow.dart';

/// Pro tool: pick a Word document, convert it to PDF, then share the .pdf.
class WordToPdfScreen extends StatefulWidget {
  const WordToPdfScreen({super.key, this.converter});

  /// Tests inject a converter so the screen never calls the service.
  final FileConverter? converter;

  @override
  State<WordToPdfScreen> createState() => _WordToPdfScreenState();
}

class _WordToPdfScreenState extends State<WordToPdfScreen>
    with ConversionRunner<WordToPdfScreen> {
  FileConverter? _owned;

  FileConverter get _converter =>
      widget.converter ?? (_owned ??= FileConverter());

  Future<void> _uploadWord() async {
    if (isBusy) return;
    if (kIsWeb) {
      showConversionMessage('Word to PDF is available on iOS and Android.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ConversionKind.wordToPdf.sourceExtensions,
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
        kind: ConversionKind.wordToPdf,
        onProgress: onProgress,
      ),
      doneMessage: 'Word document converted to PDF.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Word to PDF')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Upload a Word document and get back a PDF that keeps the '
                'fonts, spacing and page breaks. Converting needs a '
                'connection; your file is deleted as soon as it comes back.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (!_converter.isConfigured) ...[
                const ConversionUnavailableNotice(),
                const SizedBox(height: 16),
              ],
              ConversionUploadTile(
                title: 'Upload a document',
                subtitle: 'DOC, DOCX, ODT or RTF from Files.',
                icon: Icons.article_rounded,
                onPressed: isBusy ? null : _uploadWord,
              ),
              const SizedBox(height: 22),
              Text(
                'The PDF opens in the share sheet, so you can save it to '
                'Files, mail it, or send it straight on.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          ConversionOverlay(status: status),
        ],
      ),
    );
  }
}
