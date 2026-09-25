import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/file_conversion.dart';
import 'package:scan2/features/pro/domain/pdf_page_count.dart';
import 'package:scan2/features/pro/presentation/conversion_flow.dart';

/// The two ways of cutting a PDF up that are worth having on a phone.
enum SplitMode {
  /// Keep the pages named and throw the rest away — one PDF back.
  extract,

  /// Cut the whole document into files of a fixed length — a zip back.
  every,
}

/// Pro tool: take some pages out of a PDF, or cut one into several.
///
/// Pages are copied rather than rebuilt, so what comes out is exactly what
/// went in — same text, same pictures, same quality.
///
/// The range fields stay hidden until a file is in, so the page count on
/// screen is the file you actually picked.
class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({
    super.key,
    this.converter,
    this.seededBytes,
    this.seededName,
    this.seededPageCount,
  });

  /// Tests inject a converter so the screen never calls the service.
  final FileConverter? converter;

  /// Widget tests seed a picked file so the range UI can be asserted
  /// without opening FilePicker.
  final Uint8List? seededBytes;
  final String? seededName;
  final int? seededPageCount;

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen>
    with ConversionRunner<SplitPdfScreen> {
  FileConverter? _owned;
  SplitMode _mode = SplitMode.extract;
  final _ranges = TextEditingController();
  final _every = TextEditingController(text: '1');
  Uint8List? _bytes;
  String? _fileName;
  int? _pageCount;

  FileConverter get _converter =>
      widget.converter ?? (_owned ??= FileConverter());

  bool get _hasFile => _bytes != null || _pageCount != null;

  @override
  void initState() {
    super.initState();
    final seededBytes = widget.seededBytes;
    if (seededBytes != null || widget.seededPageCount != null) {
      _bytes = seededBytes;
      _fileName = widget.seededName ?? 'document.pdf';
      _pageCount =
          widget.seededPageCount ??
          (seededBytes == null ? null : countPdfPages(seededBytes));
    }
    _ranges.text = defaultKeepRange(_pageCount ?? 0);
  }

  @override
  void dispose() {
    _ranges.dispose();
    _every.dispose();
    super.dispose();
  }

  /// Null when what was typed is not something to ask for.
  ConversionOptions? _options() {
    if (_mode == SplitMode.every) {
      final every = int.tryParse(_every.text.trim());
      if (every == null || every < 1) return null;
      return ConversionOptions(everyPages: every);
    }
    final ranges = _ranges.text.trim();
    if (!isPageRange(ranges)) return null;
    return ConversionOptions(ranges: ranges);
  }

  Future<void> _pickPdf() async {
    if (isBusy) return;
    if (kIsWeb) {
      showConversionMessage('Splitting is available on iOS and Android.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ConversionKind.split.sourceExtensions,
    );
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty) return;
    final path = files.first.path;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();
    final pages = countPdfPages(bytes);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _fileName = p.basename(path);
      _pageCount = pages;
      _ranges.text = defaultKeepRange(pages);
    });
  }

  Future<void> _split() async {
    if (isBusy) return;
    final bytes = _bytes;
    final name = _fileName;
    if (bytes == null || name == null) {
      await _pickPdf();
      return;
    }
    final options = _options();
    if (options == null) {
      showConversionMessage(
        _mode == SplitMode.every
            ? 'Say how many pages each file should have.'
            : 'Write the pages like 1-3, 8.',
      );
      return;
    }
    await runConversion(
      (onProgress) => _converter.convertFile(
        bytes,
        sourceName: name,
        kind: ConversionKind.split,
        options: options,
        onProgress: onProgress,
      ),
      doneMessage: 'PDF split.',
      describe: (result) => result.filename.toLowerCase().endsWith('.zip')
          ? 'Split into separate PDFs, zipped together.'
          : 'Those pages are now a PDF of their own.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extracting = _mode == SplitMode.extract;
    final pages = _pageCount;
    return Scaffold(
      appBar: AppBar(title: const Text('Split PDF')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Take some pages out of a PDF, or cut one into several. The '
                'pages are copied across as they are, so nothing loses '
                'quality.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (!_converter.isConfigured) ...[
                const ConversionUnavailableNotice(),
                const SizedBox(height: 16),
              ],
              if (!_hasFile)
                ConversionUploadTile(
                  title: 'Choose a PDF',
                  subtitle: 'Pick a file, then choose the pages to keep.',
                  icon: Icons.content_cut_rounded,
                  onPressed: isBusy ? null : _pickPdf,
                )
              else ...[
                _PickedFileCard(
                  name: _fileName ?? 'document.pdf',
                  pageCount: pages,
                  onChange: isBusy ? null : _pickPdf,
                ),
                const SizedBox(height: 16),
                SegmentedButton<SplitMode>(
                  segments: const [
                    ButtonSegment(
                      value: SplitMode.extract,
                      label: Text('Keep pages'),
                    ),
                    ButtonSegment(
                      value: SplitMode.every,
                      label: Text('Cut into files'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: isBusy
                      ? null
                      : (picked) => setState(() => _mode = picked.first),
                ),
                const SizedBox(height: 16),
                if (extracting)
                  TextField(
                    controller: _ranges,
                    enabled: !isBusy,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'Pages to keep',
                      hintText: pages == null || pages < 1
                          ? '1-3, 8'
                          : '1-$pages',
                      helperText: pages == null || pages < 1
                          ? 'One PDF back, holding just those pages.'
                          : 'This PDF has $pages '
                                'page${pages == 1 ? '' : 's'}. One PDF back.',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                else
                  TextField(
                    controller: _every,
                    enabled: !isBusy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Pages per file',
                      hintText: '1',
                      helperText: pages == null || pages < 1
                          ? 'A zip holding one PDF per piece.'
                          : 'Cut all $pages pages into files of this length.',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: isBusy ? null : _split,
                  child: const Text('Split PDF'),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'What comes back opens in the share sheet, so you can save it '
                'to Files or send it on. Your file is deleted as soon as it '
                'comes back.',
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

class _PickedFileCard extends StatelessWidget {
  const _PickedFileCard({
    required this.name,
    required this.pageCount,
    required this.onChange,
  });

  final String name;
  final int? pageCount;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = pageCount;
    final subtitle = pages == null || pages < 1
        ? 'Page count could not be read. You can still type a range.'
        : '$pages page${pages == 1 ? '' : 's'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.white
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Brand.pdfRed.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Brand.pdfRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onChange,
              child: const Text('Choose a different PDF'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page numbers the way someone writes them: `4`, `1-3`, `1-3, 8, 11-12`.
bool isPageRange(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(
    r'^\d{1,6}(?:-\d{1,6})?(?:\s*,\s*\d{1,6}(?:-\d{1,6})?)*$',
  ).hasMatch(trimmed);
}
