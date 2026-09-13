import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/file_conversion.dart';
import 'package:scan2/features/pro/presentation/conversion_flow.dart';

/// Pro tool: pick a PDF, shrink it, then share the smaller one.
///
/// The pictures inside are downsampled and re-encoded; the text and the
/// vectors are left as they are, so the result is still a real PDF you can
/// select and search, not pages turned into photographs.
class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key, this.converter});

  /// Tests inject a converter so the screen never calls the service.
  final FileConverter? converter;

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen>
    with ConversionRunner<CompressPdfScreen> {
  FileConverter? _owned;
  CompressionLevel _level = CompressionLevel.balanced;

  FileConverter get _converter =>
      widget.converter ?? (_owned ??= FileConverter());

  Future<void> _pickAndCompress() async {
    if (isBusy) return;
    if (kIsWeb) {
      showConversionMessage('Compressing is available on iOS and Android.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ConversionKind.compress.sourceExtensions,
    );
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty) return;
    final path = files.first.path;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();
    final before = bytes.length;
    await runConversion(
      (onProgress) => _converter.convertFile(
        bytes,
        sourceName: p.basename(path),
        kind: ConversionKind.compress,
        options: ConversionOptions(compression: _level),
        onProgress: onProgress,
      ),
      doneMessage: 'PDF compressed.',
      describe: (result) => _savingFrom(before, result.bytes.length),
    );
  }

  /// Says what actually happened. A PDF that was already lean will not get
  /// much smaller, and claiming otherwise would be a lie someone can check.
  static String _savingFrom(int before, int after) {
    if (before <= 0) return 'PDF compressed.';
    final saved = before - after;
    if (saved < before * 0.005) {
      return 'This PDF was already about as small as it gets '
          '(${formatBytes(after)}).';
    }
    final percent = (saved / before * 100).round();
    return 'Compressed by $percent% — '
        '${formatBytes(before)} to ${formatBytes(after)}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Compress PDF')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Make a PDF smaller without turning it into pictures. The '
                'text stays selectable and searchable; the photographs and '
                'scans inside are what shrink.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (!_converter.isConfigured) ...[
                const ConversionUnavailableNotice(),
                const SizedBox(height: 16),
              ],
              Text('How much', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _LevelPicker(
                value: _level,
                onChanged: isBusy
                    ? null
                    : (level) => setState(() => _level = level),
              ),
              const SizedBox(height: 20),
              ConversionUploadTile(
                title: 'Choose a PDF',
                subtitle: 'Pick a file from Files, then compress it.',
                icon: Icons.compress_rounded,
                onPressed: isBusy ? null : _pickAndCompress,
              ),
              const SizedBox(height: 22),
              Text(
                'The smaller PDF opens in the share sheet, so you can save it '
                'to Files, mail it, or send it straight on. Your file is '
                'deleted as soon as it comes back.',
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

class _LevelPicker extends StatelessWidget {
  const _LevelPicker({required this.value, required this.onChanged});

  final CompressionLevel value;
  final ValueChanged<CompressionLevel>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return RadioGroup<CompressionLevel>(
      groupValue: value,
      onChanged: (picked) {
        final change = onChanged;
        if (change == null || picked == null) return;
        change(picked);
      },
      child: Column(
        children: [
          for (final level in CompressionLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RadioListTile<CompressionLevel>(
                value: level,
                enabled: onChanged != null,
                title: Text(level.label, style: theme.textTheme.titleSmall),
                subtitle: Text(level.blurb, style: theme.textTheme.bodySmall),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Brand.radiusCard),
                  side: BorderSide(
                    color: level == value
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
