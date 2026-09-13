import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/export_service.dart';
import 'package:scan2/features/library/domain/pdf_export_options.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/presentation/pro_gate.dart';

/// What the user picked in the export sheet.
enum ExportAction {
  savePdfToFiles,
  saveToPhotos,
  sharePdf,
  shareImages,
  sharePng,
  printPdf,
  exportOcrText,
}

class ExportRequest {
  const ExportRequest(this.action, this.options);

  final ExportAction action;
  final PdfExportOptions options;
}

/// Bottom sheet listing the ways a document can leave the app.
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key, required this.document});

  final Document document;

  static Future<ExportRequest?> show(BuildContext context, Document document) {
    return showModalBottomSheet<ExportRequest>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ExportSheet(document: document),
    );
  }

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  PdfPageSize _pageSize = PdfPageSize.fit;
  PdfQuality _quality = PdfQuality.good;
  bool _searchable = false;
  final Set<int> _selectedPages = {};
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  PdfExportOptions get _options => PdfExportOptions(
    pageSize: _pageSize,
    quality: _quality,
    password: _password.text.trim().isEmpty ? null : _password.text.trim(),
    searchable: _searchable,
    pageIndexes: _selectedPages.isEmpty ? null : (_selectedPages.toList()..sort()),
  );

  Future<void> _pick(ExportAction action, {bool pro = false}) async {
    if (pro && !ref.read(proProvider).isPro) {
      final ok = await requirePro(context, ref);
      if (!ok || !mounted) return;
    }
    Navigator.pop(context, ExportRequest(action, _options));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageCount = widget.document.pageCount;
    final pageLabel = '$pageCount page${pageCount == 1 ? '' : 's'}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.document.title} · $pageLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text('PDF page', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              SegmentedButton<PdfPageSize>(
                showSelectedIcon: false,
                segments: [
                  for (final size in PdfPageSize.values)
                    ButtonSegment(value: size, label: Text(size.shortLabel)),
                ],
                selected: {_pageSize},
                onSelectionChanged: (selection) {
                  AppHaptics.selection();
                  setState(() => _pageSize = selection.first);
                },
              ),
              const SizedBox(height: 14),
              Text('PDF quality', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              SegmentedButton<PdfQuality>(
                showSelectedIcon: false,
                segments: [
                  for (final quality in PdfQuality.values)
                    ButtonSegment(value: quality, label: Text(quality.label)),
                ],
                selected: {_quality},
                onSelectionChanged: (selection) {
                  AppHaptics.selection();
                  setState(() => _quality = selection.first);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Encrypt PDF (password)',
                  hintText: 'Opens only with this password',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Searchable PDF'),
                subtitle: const Text(
                  'Pro · hidden text you can find and copy',
                ),
                value: _searchable,
                onChanged: (value) async {
                  if (value && !ref.read(proProvider).isPro) {
                    final ok = await requirePro(context, ref);
                    if (!ok || !mounted) return;
                  }
                  setState(() => _searchable = value);
                },
              ),
              if (pageCount > 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Pages (Pro · empty means all)',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < pageCount; i++)
                      FilterChip(
                        label: Text('${i + 1}'),
                        selected: _selectedPages.contains(i),
                        onSelected: (selected) async {
                          if (!ref.read(proProvider).isPro) {
                            final ok = await requirePro(context, ref);
                            if (!ok || !mounted) return;
                          }
                          setState(() {
                            if (selected) {
                              _selectedPages.add(i);
                            } else {
                              _selectedPages.remove(i);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _ExportTile(
                icon: Icons.picture_as_pdf_rounded,
                tint: Brand.pdfRed,
                title: 'Save PDF to Files',
                subtitle: 'Name the file, then pick a folder',
                highlighted: true,
                onTap: () => _pick(ExportAction.savePdfToFiles),
              ),
              const SizedBox(height: 8),
              _ExportTile(
                icon: Icons.photo_library_rounded,
                tint: Brand.amber,
                title: 'Save to Photos',
                subtitle: 'Adds the pages to a Scanella album',
                onTap: () => _pick(ExportAction.saveToPhotos),
              ),
              const SizedBox(height: 8),
              _ExportTile(
                icon: Icons.ios_share_rounded,
                tint: Brand.docBlue,
                title: 'Share PDF',
                subtitle: 'Mail, Messages, or another app',
                onTap: () => _pick(ExportAction.sharePdf),
              ),
              const SizedBox(height: 8),
              _ExportTile(
                icon: Icons.image_rounded,
                tint: Brand.cloudBlue,
                title: 'Share JPEG',
                subtitle: 'One JPEG per page',
                onTap: () => _pick(ExportAction.shareImages),
              ),
              const SizedBox(height: 8),
              _ExportTile(
                icon: Icons.photo_size_select_actual_rounded,
                tint: Brand.imageGreen,
                title: 'Share PNG',
                subtitle: 'Pro · lossless pages',
                onTap: () => _pick(ExportAction.sharePng, pro: true),
              ),
              const SizedBox(height: 8),
              _ExportTile(
                icon: Icons.print_rounded,
                tint: Brand.ink,
                title: 'Print',
                subtitle: 'Pro · system printer',
                onTap: () => _pick(ExportAction.printPdf, pro: true),
              ),
              const SizedBox(height: 8),
              _ExportTile(
                icon: Icons.notes_rounded,
                tint: Brand.docBlue,
                title: 'Export OCR text',
                subtitle: 'Pro · a .txt of the recognised words',
                onTap: () => _pick(ExportAction.exportOcrText, pro: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PressableScale(
      onPressed: onTap,
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(Brand.radiusField),
      minSize: 0,
      child: Container(
        decoration: BoxDecoration(
          color: highlighted
              ? scheme.primaryContainer
              : (theme.brightness == Brightness.light
                    ? scheme.surfaceContainer
                    : scheme.surfaceContainerLow),
          borderRadius: BorderRadius.circular(Brand.radiusField),
          border: Border.all(
            color: highlighted ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: tint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Runs [request] for [document], returning a message to show the user.
Future<String> runExportAction(
  ExportRequest request,
  Document document,
  ExportService exporter, {
  Rect? shareOrigin,
}) async {
  final origin = shareOrigin ?? Rect.zero;
  final options = request.options;
  switch (request.action) {
    case ExportAction.savePdfToFiles:
      final saved = await exporter.savePdfToFiles(document, options: options);
      return saved ? 'PDF saved to Files' : '';
    case ExportAction.saveToPhotos:
      final saved = await exporter.saveToPhotos(
        document,
        pageIndexes: options.pageIndexes,
      );
      return 'Saved $saved page${saved == 1 ? '' : 's'} to Photos';
    case ExportAction.sharePdf:
      await exporter.sharePdf(
        document,
        shareOrigin: origin.isEmpty ? null : origin,
        options: options,
      );
      return '';
    case ExportAction.shareImages:
      await exporter.shareImages(
        document,
        shareOrigin: origin.isEmpty ? null : origin,
        pageIndexes: options.pageIndexes,
      );
      return '';
    case ExportAction.sharePng:
      await exporter.shareImages(
        document,
        shareOrigin: origin.isEmpty ? null : origin,
        png: true,
        pageIndexes: options.pageIndexes,
      );
      return '';
    case ExportAction.printPdf:
      await exporter.printPdf(document, options: options);
      return '';
    case ExportAction.exportOcrText:
      await exporter.shareOcrText(
        document,
        shareOrigin: origin.isEmpty ? null : origin,
      );
      return '';
  }
}

/// A compact rect inside the window. iOS needs this for the share popover;
/// a full-screen origin is often *outside* the presenting view's frame and
/// is rejected.
Rect shareOriginFor(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  return Rect.fromLTWH(
    size.width / 2 - 24,
    (size.height - padding.bottom - 88).clamp(
      padding.top + 24,
      math.max(padding.top + 24, size.height - 56),
    ),
    48,
    48,
  );
}
