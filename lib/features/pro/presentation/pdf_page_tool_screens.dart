import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scan2/features/pro/data/conversion_service.dart';
import 'package:scan2/features/pro/domain/pdf_page_tools.dart';
import 'package:scan2/features/pro/presentation/conversion_flow.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';

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

/// Pick a PDF, turn the pages on screen, then download when it looks right.
class PdfRotateScreen extends StatefulWidget {
  const PdfRotateScreen({
    super.key,
    this.tools,
    this.initialPages,
    this.initialStem = 'document',
  });

  final PdfPageTools? tools;

  /// Tests seed the preview so they never open the file picker.
  final List<Uint8List>? initialPages;
  final String initialStem;

  @override
  State<PdfRotateScreen> createState() => _PdfRotateScreenState();
}

class _PdfRotateScreenState extends State<PdfRotateScreen>
    with ConversionRunner<PdfRotateScreen> {
  PdfPageTools get _tools => widget.tools ?? const PdfPageTools();

  List<Uint8List> _pages = const [];
  String _stem = 'document';
  int _turns = 0;
  int _index = 0;
  bool _reading = false;
  PageController? _pager;

  bool get _hasDocument => _pages.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialPages;
    if (seed != null && seed.isNotEmpty) {
      _pages = seed;
      _stem = widget.initialStem;
      _pager = PageController();
    }
  }

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (isBusy || _reading) return;
    final picked = await _pickPdf(onWeb: showConversionMessage);
    if (picked == null) return;
    setState(() => _reading = true);
    try {
      final pages = await _tools.rasterPages(picked.bytes);
      if (!mounted) return;
      _pager?.dispose();
      setState(() {
        _pages = pages;
        _stem = picked.stem;
        _turns = 0;
        _index = 0;
        _reading = false;
        _pager = PageController();
      });
    } catch (e) {
      await AppHaptics.error();
      if (!mounted) return;
      setState(() => _reading = false);
      showConversionMessage(
        e is StateError ? e.message : 'That PDF could not be read.',
      );
    }
  }

  void _rotate() {
    if (!_hasDocument || isBusy || _reading) return;
    AppHaptics.impactLight();
    setState(() => _turns = (_turns + 1) % 4);
  }

  Future<void> _download() async {
    if (!_hasDocument || isBusy || _reading) return;
    final pages = _pages;
    final turns = _turns;
    final stem = _stem;
    await runConversion(
      (onProgress) async {
        onProgress(
          const ConversionStatus(
            stage: ConversionStage.converting,
            message: 'Building the PDF…',
            fraction: 0.55,
          ),
        );
        final bytes = await _tools.buildRotatedPdf(
          pages,
          quarterTurns: turns,
        );
        final suffix = turns % 4 == 0 ? '' : '-rotated';
        return ConvertedFile(
          bytes: bytes,
          filename: '$stem$suffix.pdf',
          mimeType: 'application/pdf',
        );
      },
      doneMessage: 'PDF ready to save.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rotate PDF')),
      body: Stack(
        children: [
          if (!_hasDocument)
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                Text(
                  'Pick a PDF, turn the pages on this screen, then download '
                  'when it looks right. This runs on your device — nothing '
                  'is uploaded.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                ConversionUploadTile(
                  title: 'Choose a PDF',
                  subtitle: 'The pages open here so you can rotate them first.',
                  icon: Icons.rotate_90_degrees_cw_rounded,
                  onPressed: _reading ? null : _pick,
                ),
              ],
            )
          else
            Column(
              children: [
                Expanded(
                  child: _Preview(
                    pages: _pages,
                    turns: _turns,
                    pager: _pager,
                    onPage: (i) => setState(() => _index = i),
                  ),
                ),
                _RotateBar(
                  pageLabel: _pages.length < 2
                      ? null
                      : '${_index + 1} of ${_pages.length}',
                  onRotate: isBusy ? null : _rotate,
                  onDownload: isBusy ? null : _download,
                  onChooseAnother: isBusy ? null : _pick,
                ),
              ],
            ),
          if (_reading)
            const ConversionOverlay(
              status: ConversionStatus(
                stage: ConversionStage.converting,
                message: 'Reading pages…',
                fraction: 0.35,
              ),
            ),
          ConversionOverlay(status: status),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.pages,
    required this.turns,
    required this.pager,
    required this.onPage,
  });

  final List<Uint8List> pages;
  final int turns;
  final PageController? pager;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Brand.canvas,
      child: PageView.builder(
        controller: pager,
        itemCount: pages.length,
        onPageChanged: onPage,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: RotatedBox(
                  quarterTurns: turns,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Brand.ink.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.memory(
                      pages[index],
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RotateBar extends StatelessWidget {
  const _RotateBar({
    required this.pageLabel,
    required this.onRotate,
    required this.onDownload,
    required this.onChooseAnother,
  });

  final String? pageLabel;
  final VoidCallback? onRotate;
  final VoidCallback? onDownload;
  final VoidCallback? onChooseAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pageLabel != null) ...[
                Text(pageLabel!, style: theme.textTheme.labelLarge),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRotate,
                      icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
                      label: const Text('Rotate'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onDownload,
                      child: const Text('Download'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onChooseAnother,
                child: const Text('Choose a different PDF'),
              ),
            ],
          ),
        ),
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
