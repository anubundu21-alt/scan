import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:scan2/features/pro/data/conversion_service.dart';
import 'package:scan2/features/pro/domain/image_pdf_convert.dart';
import 'package:scan2/features/pro/presentation/conversion_flow.dart';

/// Pro tool: pick JPG/PNG files, wrap them as a PDF, then share.
class ImagesToPdfScreen extends StatefulWidget {
  const ImagesToPdfScreen({super.key, this.convert});

  final ImagePdfConvert? convert;

  @override
  State<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends State<ImagesToPdfScreen>
    with ConversionRunner<ImagesToPdfScreen> {
  ImagePdfConvert get _convert => widget.convert ?? const ImagePdfConvert();

  Future<void> _pickAndConvert() async {
    if (isBusy) return;
    if (kIsWeb) {
      showConversionMessage('Image to PDF is available on iOS and Android.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
    );
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty) return;
    final images = <List<int>>[];
    for (final file in files) {
      final path = file.path;
      if (path == null) continue;
      images.add(await File(path).readAsBytes());
    }
    if (images.isEmpty) {
      showConversionMessage(
        'Nothing in that selection could be read as an image.',
      );
      return;
    }
    await runConversion((onProgress) async {
      onProgress(
        const ConversionStatus(
          stage: ConversionStage.converting,
          message: 'Building the PDF…',
          fraction: 0.5,
        ),
      );
      final bytes = await _convert.imagesToPdf([
        for (final image in images) Uint8List.fromList(image),
      ]);
      return ConvertedFile(
        bytes: bytes,
        filename: 'images.pdf',
        mimeType: 'application/pdf',
      );
    }, doneMessage: 'Images saved as a PDF.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Image to PDF')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Turn JPG or PNG photos into a PDF, one page per image, in '
                'the order you pick them. This runs on your device — '
                'nothing is uploaded.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ConversionUploadTile(
                title: 'Choose photos',
                subtitle: 'JPG or PNG from Files. Several become one PDF.',
                icon: Icons.photo_library_rounded,
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
