import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/data/conversion_service.dart';
import 'package:scan2/features/pro/domain/image_pdf_convert.dart';
import 'package:scan2/features/pro/presentation/conversion_flow.dart';

/// Pro tool: pick a PDF, raster each page to JPG or PNG, then share.
class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key, this.convert});

  final ImagePdfConvert? convert;

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen>
    with ConversionRunner<PdfToImageScreen> {
  bool _png = false;

  ImagePdfConvert get _convert => widget.convert ?? const ImagePdfConvert();

  Future<void> _pickAndConvert() async {
    if (isBusy) return;
    if (kIsWeb) {
      showConversionMessage('PDF to JPG is available on iOS and Android.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty) return;
    final path = files.first.path;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    final stem = p.basenameWithoutExtension(path).trim();
    final png = _png;
    await runConversion((onProgress) async {
      onProgress(
        const ConversionStatus(
          stage: ConversionStage.starting,
          message: 'Reading pages…',
          fraction: 0.15,
        ),
      );
      final pages = await _convert.pdfToImages(bytes, png: png);
      onProgress(
        ConversionStatus(
          stage: ConversionStage.downloading,
          message: pages.length == 1
              ? 'Saving the image…'
              : 'Packing ${pages.length} pages…',
          fraction: 0.85,
        ),
      );
      return _convert.packImages(
        pages,
        png: png,
        stem: stem.isEmpty ? 'pages' : stem,
      );
    }, doneMessage: png ? 'PDF saved as PNG.' : 'PDF saved as JPG.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PDF to JPG')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Turn each PDF page into a JPG or PNG. One page comes back '
                'as an image; several pages come back as a zip. This runs '
                'on your device — nothing is uploaded.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('Format', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _FormatPicker(
                png: _png,
                onChanged: isBusy ? null : (png) => setState(() => _png = png),
              ),
              const SizedBox(height: 20),
              ConversionUploadTile(
                title: 'Choose a PDF',
                subtitle: 'Pick a file from Files, then save the pages.',
                icon: Icons.image_outlined,
                onPressed: isBusy ? null : _pickAndConvert,
              ),
            ],
          ),
          ConversionOverlay(status: status),
        ],
      ),
    );
  }
}

class _FormatPicker extends StatelessWidget {
  const _FormatPicker({required this.png, required this.onChanged});

  final bool png;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FormatChip(
            label: 'JPG',
            selected: !png,
            onTap: onChanged == null ? null : () => onChanged!(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FormatChip(
            label: 'PNG',
            selected: png,
            onTap: onChanged == null ? null : () => onChanged!(true),
          ),
        ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableChip(selected: selected, label: label, onTap: onTap);
  }
}

class PressableChip extends StatelessWidget {
  const PressableChip({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? Brand.accentWash : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        side: BorderSide(
          color: selected ? Brand.accent : theme.colorScheme.outlineVariant,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? Brand.accentDark : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
