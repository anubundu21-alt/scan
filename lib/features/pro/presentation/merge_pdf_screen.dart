import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/file_conversion.dart';
import 'package:scan2/features/pro/presentation/conversion_flow.dart';

/// Pro tool: pick several PDFs, put them in the order you want, and get one
/// PDF back with all of their pages.
///
/// The pages are copied, not rebuilt, so text, tables and images arrive as
/// they were in the file they came from.
class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key, this.converter});

  /// Tests inject a converter so the screen never calls the service.
  final FileConverter? converter;

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen>
    with ConversionRunner<MergePdfScreen> {
  static const _maxFiles = 20;

  FileConverter? _owned;
  final List<ConversionSource> _files = [];

  FileConverter get _converter =>
      widget.converter ?? (_owned ??= FileConverter());

  bool get _canMerge => _files.length >= 2 && !isBusy;

  Future<void> _addFiles() async {
    if (isBusy) return;
    if (kIsWeb) {
      showConversionMessage('Merging is available on iOS and Android.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ConversionKind.merge.sourceExtensions,
      allowMultiple: true,
    );
    final picked = result?.files ?? const <PlatformFile>[];
    if (picked.isEmpty) return;

    final added = <ConversionSource>[];
    for (final file in picked) {
      final path = file.path;
      if (path == null) continue;
      if (_files.length + added.length >= _maxFiles) break;
      added.add(
        ConversionSource(
          bytes: await File(path).readAsBytes(),
          filename: p.basename(path),
        ),
      );
    }
    if (!mounted || added.isEmpty) return;
    setState(() => _files.addAll(added));
    if (_files.length >= _maxFiles) {
      showConversionMessage('That is as many files as one merge can take.');
    }
  }

  Future<void> _merge() async {
    if (!_canMerge) return;
    final ordered = List<ConversionSource>.of(_files);
    await runConversion(
      (onProgress) => _converter.convertFiles(
        ordered,
        kind: ConversionKind.merge,
        onProgress: onProgress,
      ),
      doneMessage: 'PDFs merged.',
      describe: (result) =>
          '${ordered.length} PDFs merged into one '
          '(${formatBytes(result.bytes.length)}).',
    );
  }

  void _move(int oldIndex, int newIndex) {
    setState(() {
      _files.insert(newIndex, _files.removeAt(oldIndex));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDF')),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    Text(
                      'Pick two or more PDFs and get one back with all of '
                      'their pages. Drag to change the order — the file at '
                      'the top goes first.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    if (!_converter.isConfigured) ...[
                      const ConversionUnavailableNotice(),
                      const SizedBox(height: 16),
                    ],
                    ConversionUploadTile(
                      title: _files.isEmpty ? 'Choose PDFs' : 'Add more PDFs',
                      subtitle: _files.isEmpty
                          ? 'Pick two or more files from Files.'
                          : '${_files.length} of $_maxFiles chosen.',
                      icon: Icons.merge_rounded,
                      onPressed: isBusy ? null : _addFiles,
                    ),
                    if (_files.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('In this order', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _FileList(
                        files: _files,
                        onReorder: isBusy ? null : _move,
                        onRemove: isBusy
                            ? null
                            : (index) => setState(() => _files.removeAt(index)),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canMerge ? _merge : null,
                      child: Text(
                        _files.length < 2
                            ? 'Pick at least two PDFs'
                            : 'Merge ${_files.length} PDFs',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ConversionOverlay(status: status),
        ],
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({
    required this.files,
    required this.onReorder,
    required this.onRemove,
  });

  final List<ConversionSource> files;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(int index)? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: onReorder != null,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      onReorderItem: onReorder ?? (_, _) {},
      itemBuilder: (context, index) {
        final file = files[index];
        return Padding(
          key: ValueKey('${file.filename}-$index'),
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? Colors.white
                  : scheme.surface,
              borderRadius: BorderRadius.circular(Brand.radiusCard),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Text(
                  '${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        formatBytes(file.bytes.length),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove == null ? null : () => onRemove!(index),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
