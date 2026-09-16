import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scan2/features/pro/data/conversion_service.dart';
import 'package:scan2/features/pro/domain/pdf_page_tools.dart';
import 'package:scan2/features/pro/presentation/conversion_flow.dart';
import 'package:scan2/features/pro/presentation/pdf_to_image_screen.dart';

Future<({Uint8List bytes, String stem})?> _pickPdf({
  required void Function(String message) onWeb,
}) async {
  if (kIsWeb) {
    onWeb('This tool is available on iOS and Android.');
    return null;
  }
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  final files = result?.files ?? const <PlatformFile>[];
  if (files.isEmpty) return null;
  final path = files.first.path;
  if (path == null) return null;
  final bytes = await File(path).readAsBytes();
  final stem = p.basenameWithoutExtension(path).trim();
  return (bytes: bytes, stem: stem.isEmpty ? 'document' : stem);
}

/// Turn every page 90°, 180° or 270° clockwise, then share the new PDF.
class PdfRotateScreen extends StatefulWidget {
  const PdfRotateScreen({super.key, this.tools});

  final PdfPageTools? tools;

  @override
  State<PdfRotateScreen> createState() => _PdfRotateScreenState();
}

class _PdfRotateScreenState extends State<PdfRotateScreen>
    with ConversionRunner<PdfRotateScreen> {
  PdfPageTools get _tools => widget.tools ?? const PdfPageTools();
  int _quarterTurns = 1;

  Future<void> _pickAndRotate() async {
    if (isBusy) return;
    final picked = await _pickPdf(onWeb: showConversionMessage);
    if (picked == null) return;
    final turns = _quarterTurns;
    await runConversion(
      (onProgress) async {
        onProgress(
          const ConversionStatus(
            stage: ConversionStage.converting,
            message: 'Rotating pages…',
            fraction: 0.45,
          ),
        );
        final bytes = await _tools.rotate(picked.bytes, quarterTurns: turns);
        return ConvertedFile(
          bytes: bytes,
          filename: '${picked.stem}-rotated.pdf',
          mimeType: 'application/pdf',
        );
      },
      doneMessage: 'PDF rotated.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rotate PDF')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Turn every page clockwise. This runs on your device — '
                'nothing is uploaded.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('How far', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final entry in const [
                    (1, '90°'),
                    (2, '180°'),
                    (3, '270°'),
                  ]) ...[
                    if (entry.$1 > 1) const SizedBox(width: 10),
                    Expanded(
                      child: PressableChip(
                        label: entry.$2,
                        selected: _quarterTurns == entry.$1,
                        onTap: isBusy
                            ? null
                            : () => setState(() => _quarterTurns = entry.$1),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              ConversionUploadTile(
                title: 'Choose a PDF',
                subtitle: 'Pick a file from Files, then save the rotated one.',
                icon: Icons.rotate_90_degrees_cw_rounded,
                onPressed: isBusy ? null : _pickAndRotate,
              ),
            ],
          ),
          ConversionOverlay(status: status),
        ],
      ),
    );
  }
}

/// Print "1 / n" at the bottom of each page, then share the new PDF.
class PdfPageNumbersScreen extends StatefulWidget {
  const PdfPageNumbersScreen({super.key, this.tools});

  final PdfPageTools? tools;

  @override
  State<PdfPageNumbersScreen> createState() => _PdfPageNumbersScreenState();
}

class _PdfPageNumbersScreenState extends State<PdfPageNumbersScreen>
    with ConversionRunner<PdfPageNumbersScreen> {
  PdfPageTools get _tools => widget.tools ?? const PdfPageTools();

  Future<void> _pickAndStamp() async {
    if (isBusy) return;
    final picked = await _pickPdf(onWeb: showConversionMessage);
    if (picked == null) return;
    await runConversion(
      (onProgress) async {
        onProgress(
          const ConversionStatus(
            stage: ConversionStage.converting,
            message: 'Numbering pages…',
            fraction: 0.45,
          ),
        );
        final bytes = await _tools.addPageNumbers(picked.bytes);
        return ConvertedFile(
          bytes: bytes,
          filename: '${picked.stem}-pages.pdf',
          mimeType: 'application/pdf',
        );
      },
      doneMessage: 'Page numbers added.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Page numbers')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Put 1 / n at the bottom of each page. This runs on your '
                'device — nothing is uploaded.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              ConversionUploadTile(
                title: 'Choose a PDF',
                subtitle: 'Pick a file from Files, then save the numbered one.',
                icon: Icons.format_list_numbered_rounded,
                onPressed: isBusy ? null : _pickAndStamp,
              ),
            ],
          ),
          ConversionOverlay(status: status),
        ],
      ),
    );
  }
}

/// Stamp text across every page, then share the new PDF.
class PdfWatermarkScreen extends StatefulWidget {
  const PdfWatermarkScreen({super.key, this.tools});

  final PdfPageTools? tools;

  @override
  State<PdfWatermarkScreen> createState() => _PdfWatermarkScreenState();
}

class _PdfWatermarkScreenState extends State<PdfWatermarkScreen>
    with ConversionRunner<PdfWatermarkScreen> {
  PdfPageTools get _tools => widget.tools ?? const PdfPageTools();
  final _text = TextEditingController(text: 'CONFIDENTIAL');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickAndStamp() async {
    if (isBusy) return;
    final label = _text.text.trim();
    if (label.isEmpty) {
      showConversionMessage('Write a watermark first.');
      return;
    }
    final picked = await _pickPdf(onWeb: showConversionMessage);
    if (picked == null) return;
    await runConversion(
      (onProgress) async {
        onProgress(
          const ConversionStatus(
            stage: ConversionStage.converting,
            message: 'Adding the watermark…',
            fraction: 0.45,
          ),
        );
        final bytes = await _tools.addWatermark(picked.bytes, text: label);
        return ConvertedFile(
          bytes: bytes,
          filename: '${picked.stem}-watermark.pdf',
          mimeType: 'application/pdf',
        );
      },
      doneMessage: 'Watermark added.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Watermark')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Stamp text across the middle of every page. This runs on '
                'your device — nothing is uploaded.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                enabled: !isBusy,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Watermark',
                  hintText: 'CONFIDENTIAL',
                ),
              ),
              const SizedBox(height: 20),
              ConversionUploadTile(
                title: 'Choose a PDF',
                subtitle: 'Pick a file from Files, then save the stamped one.',
                icon: Icons.branding_watermark_outlined,
                onPressed: isBusy ? null : _pickAndStamp,
              ),
            ],
          ),
          ConversionOverlay(status: status),
        ],
      ),
    );
  }
}

/// Open a locked PDF with the password, write one that opens without it.
class PdfUnlockScreen extends StatefulWidget {
  const PdfUnlockScreen({super.key, this.tools});

  final PdfPageTools? tools;

  @override
  State<PdfUnlockScreen> createState() => _PdfUnlockScreenState();
}

class _PdfUnlockScreenState extends State<PdfUnlockScreen>
    with ConversionRunner<PdfUnlockScreen> {
  PdfPageTools get _tools => widget.tools ?? const PdfPageTools();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickAndUnlock() async {
    if (isBusy) return;
    final picked = await _pickPdf(onWeb: showConversionMessage);
    if (picked == null) return;
    final password = _password.text;
    await runConversion(
      (onProgress) async {
        onProgress(
          const ConversionStatus(
            stage: ConversionStage.converting,
            message: 'Removing the lock…',
            fraction: 0.45,
          ),
        );
        final bytes = await _tools.unlock(picked.bytes, password: password);
        return ConvertedFile(
          bytes: bytes,
          filename: '${picked.stem}-unlocked.pdf',
          mimeType: 'application/pdf',
        );
      },
      doneMessage: 'PDF unlocked.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock PDF')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Remove the open password from a PDF you already know. The '
                'new file opens without asking. This runs on your device — '
                'nothing is uploaded.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                enabled: !isBusy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'If the PDF asks for one to open',
                ),
              ),
              const SizedBox(height: 20),
              ConversionUploadTile(
                title: 'Choose a PDF',
                subtitle: 'Pick a locked file, then save one that opens freely.',
                icon: Icons.lock_open_rounded,
                onPressed: isBusy ? null : _pickAndUnlock,
              ),
            ],
          ),
          ConversionOverlay(status: status),
        ],
      ),
    );
  }
}
