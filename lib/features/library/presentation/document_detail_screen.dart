import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/page_thumbnail.dart';
import 'package:scan2/core/widgets/paper.dart';
import 'package:scan2/features/crop/domain/crop_args.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';
import 'package:scan2/features/home/domain/import_service.dart';
import 'package:scan2/features/library/data/document_store.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/document_auto_file.dart';
import 'package:scan2/features/library/domain/document_organizer.dart';
import 'package:scan2/features/library/domain/export_service.dart';
import 'package:scan2/features/library/domain/ocr_layout.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/presentation/pro_gate.dart';
import 'package:scan2/features/library/presentation/name_scan_dialog.dart';
import 'package:scan2/features/library/presentation/widgets/add_pages_sheet.dart';
import 'package:scan2/features/library/presentation/widgets/export_sheet.dart';
import 'package:scan2/features/library/presentation/widgets/folder_actions.dart';
import 'package:scan2/features/library/presentation/widgets/merge_picker_sheet.dart';
import 'package:scan2/features/ocr/domain/on_device_ocr.dart';
import 'package:scan2/features/ocr/presentation/ocr_result_screen.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';
import 'package:scan2/features/shared/providers/settings_provider.dart';
import 'package:scan2/features/signatures/presentation/signature_picker_sheet.dart';

/// Save PDF to Files / Save to Photos from a new scan should land back on
/// home, not linger on the export screen.
bool exportReturnsToHome(DocumentScreenMode mode, ExportAction action) {
  if (mode != DocumentScreenMode.scan) return false;
  return action == ExportAction.savePdfToFiles ||
      action == ExportAction.saveToPhotos;
}

/// How this document was opened.
///
/// Scan is the camera result: crop, add a page, export. Edit PDF and Sign PDF
/// are separate tools from the home grid — a scan does not ask you to sign.
enum DocumentScreenMode { scan, editPdf, signPdf }

class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.documentId,
    this.mode = DocumentScreenMode.scan,
  });

  final int documentId;
  final DocumentScreenMode mode;

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  static const _exporter = ExportService();
  static const _importer = ImportService();
  static final _ocr = OnDeviceOcr();
  static const _autoFile = DocumentAutoFile();
  bool _busy = false;
  String _busyLabel = '';
  bool _autoFileStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_autoFileIfNeeded());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Cached in a provider so an unrelated rebuild (a dialog opening, the
    // busy flag flipping) does not re-read the document and blank the list.
    final document = ref.watch(documentProvider(widget.documentId)).valueOrNull;
    final pages = document?.pages ?? const <ScanPage>[];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: document == null
            ? const Text('Document')
            : _TitleBlock(document: document),
        bottom: widget.mode == DocumentScreenMode.scan
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(34),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.mode == DocumentScreenMode.editPdf
                          ? 'Edit PDF — rotate, add, merge, split'
                          : 'Sign PDF — draw and place a signature',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
        actions: [
          TactileIconButton(
            icon: Icons.folder_open_rounded,
            tooltip: 'Move to folder',
            color: theme.colorScheme.onSurface,
            onPressed: document == null ? null : () => _moveToFolder(document),
          ),
          TactileIconButton(
            icon: Icons.drive_file_rename_outline_rounded,
            tooltip: 'Rename',
            color: theme.colorScheme.onSurface,
            onPressed: document == null ? null : () => _rename(document),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            enabled: document != null,
            onSelected: (value) {
              if (document == null) return;
              switch (value) {
                case 'text':
                  _extractText(document);
                case 'favorite':
                  _toggleFavorite(document);
                case 'private':
                  _togglePrivate(document);
                case 'merge':
                  _mergeWith(document);
                case 'splitAll':
                  _splitAll(document);
                case 'trash':
                  _trash(document);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'text', child: Text('Extract text')),
              const PopupMenuItem(
                value: 'favorite',
                child: Text('Favorite'),
              ),
              const PopupMenuItem(value: 'private', child: Text('Private')),
              if (widget.mode == DocumentScreenMode.editPdf)
                const PopupMenuItem(
                  value: 'merge',
                  child: Text('Merge with another scan'),
                ),
              if ((document?.pageCount ?? 0) >= 2)
                const PopupMenuItem(
                  value: 'splitAll',
                  child: Text('Split into single pages'),
                ),
              const PopupMenuItem(value: 'trash', child: Text('Move to Trash')),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          if (document == null)
            const Center(child: CircularProgressIndicator())
          else if (pages.isEmpty)
            Center(
              child: Text(
                'This document has no pages.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: pages.length,
              // Each card supplies its own handle. Left on, this draws a
              // second one over the top of ours on any platform Flutter
              // considers pointer-driven — desktop, web, an iPad with a
              // trackpad — so the row ends up with two overlapping grips.
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorder(document, oldIndex, newIndex),
              itemBuilder: (context, index) => _PageCard(
                key: ValueKey(pages[index].path),
                documentId: document.id,
                page: pages[index],
                index: index,
                onEdit: widget.mode == DocumentScreenMode.signPdf
                    ? () => startSigningPage(
                        context,
                        document: document,
                        page: pages[index],
                      )
                    : () => _edit(document, pages[index]),
                onRotate: widget.mode == DocumentScreenMode.editPdf
                    ? () => _rotatePage(document, pages[index])
                    : null,
                onSign: widget.mode == DocumentScreenMode.signPdf
                    ? () => startSigningPage(
                        context,
                        document: document,
                        page: pages[index],
                      )
                    : null,
                onDelete: () => _deletePage(document, pages[index]),
                onSplitAfter: index < pages.length - 1
                    ? () => _splitAfter(document, index)
                    : null,
              ),
            ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Brand.ink.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      if (_busyLabel.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          _busyLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: document == null || pages.isEmpty
          ? null
          : _ActionBar(
              busy: _busy,
              mode: widget.mode,
              onAddPage: widget.mode == DocumentScreenMode.editPdf
                  ? () => _addPages(document)
                  : () => context.push('/camera'),
              onSign: () => _signDocument(document),
              onExport: () => _export(document),
            ),
    );
  }

  void _edit(Document document, ScanPage page) {
    context.push(
      '/crop',
      extra: CropArgs(
        // Editing re-derives from the original capture when one was kept.
        imagePath: page.editSource,
        initialQuad: page.quad,
        adjustments: page.adjustments,
        edgesAlreadyApplied: document.edgesAlreadyApplied,
      ),
    );
  }

  Future<void> _rotatePage(Document document, ScanPage page) async {
    await ref.read(documentRepositoryProvider).rotatePageClockwise(
      documentId: document.id,
      pagePath: page.path,
    );
    bumpLibrary(ref);
    AppHaptics.selection();
  }

  Future<void> _signDocument(Document document) async {
    if (document.pages.isEmpty) return;
    ScanPage page = document.pages.first;
    if (document.pageCount > 1) {
      final picked = await showModalBottomSheet<ScanPage>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Sign which page?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (var i = 0; i < document.pages.length; i++)
                  ListTile(
                    title: Text('Page ${i + 1}'),
                    onTap: () => Navigator.pop(context, document.pages[i]),
                  ),
              ],
            ),
          );
        },
      );
      if (picked == null || !mounted) return;
      page = picked;
    }
    await startSigningPage(context, document: document, page: page);
  }

  Future<void> _addPages(Document document) async {
    if (kIsWeb) {
      _showMessage('Adding pages is available on iOS and Android.');
      return;
    }
    final source = await showAddPagesSheet(context);
    if (source == null || !mounted) return;
    final repository = ref.read(documentRepositoryProvider);
    if (repository is! DocumentStore) {
      _showMessage('Adding pages is available on iOS and Android.');
      return;
    }

    setState(() {
      _busy = true;
      _busyLabel = source == AddPagesSource.photos
          ? 'Reading photos…'
          : 'Reading files…';
    });
    try {
      final filter = source == AddPagesSource.photos
          ? ref.read(settingsProvider).defaultFilter
          : ScanFilter.original;
      final pages = source == AddPagesSource.photos
          ? await _importer.fromPhotos(filter: filter)
          : await _importer.fromFiles(filter: filter);
      if (pages.isEmpty) return;
      await repository.addProcessedPages(document.id, pages);
      bumpLibrary(ref);
      if (!mounted) return;
      AppHaptics.success();
      _showMessage(
        'Added ${pages.length} page${pages.length == 1 ? '' : 's'}',
      );
    } catch (e) {
      if (mounted) _showMessage(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mergeWith(Document document) async {
    final all = ref.read(documentsProvider).valueOrNull ??
        await ref.read(documentRepositoryProvider).getAllDocuments();
    if (!mounted) return;
    final others = [
      for (final doc in all)
        if (doc.id != document.id) doc,
    ];
    final picked = await showMergePickerSheet(
      context: context,
      current: document,
      others: others,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    try {
      final merged = await ref
          .read(documentRepositoryProvider)
          .mergeDocuments([document.id, ...picked]);
      bumpLibrary(ref);
      AppHaptics.success();
      if (mounted) {
        context.push(
          '/library/document/${merged.id}',
          extra: widget.mode,
        );
      }
    } catch (e) {
      if (mounted) _showMessage(_readable(e));
    }
  }

  Future<void> _export(Document document) async {
    if (kIsWeb) {
      _showMessage('Export is available on device.');
      return;
    }

    final origin = shareOriginFor(context);
    final request = await ExportSheet.show(context, document);
    if (request == null || !mounted) return;

    // The sheet must finish dismissing before iOS can present Files or Share.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final latest =
        await ref.read(documentRepositoryProvider).getDocument(document.id) ??
        document;
    var exporting = latest;
    if (request.action == ExportAction.savePdfToFiles) {
      final name = await promptScanName(
        context,
        initial: document.title,
        title: 'Name this PDF',
      );
      if (!mounted) return;
      if (name != null && name != latest.title) {
        await ref
            .read(documentRepositoryProvider)
            .renameDocument(latest.id, name);
        bumpLibrary(ref);
        exporting = latest.copyWith(title: name);
      }
    }

    setState(() {
      _busy = true;
      _busyLabel = request.action == ExportAction.saveToPhotos
          ? 'Saving to Photos…'
          : request.action == ExportAction.savePdfToFiles
          ? 'Saving PDF…'
          : 'Preparing PDF…';
    });

    try {
      final message = await runExportAction(
        request,
        exporting,
        _exporter,
        shareOrigin: origin,
      );
      if (!mounted) return;
      AppHaptics.success();
      if (exportReturnsToHome(widget.mode, request.action) &&
          message.isNotEmpty) {
        if (!mounted) return;
        context.go('/library');
        return;
      }
      if (message.isNotEmpty) _showMessage(message);
    } catch (e) {
      debugPrint('Export failed: $e');
      // Surfaced rather than swallowed: an export that silently does nothing
      // is indistinguishable from a broken button.
      if (mounted) _showMessage('Export failed: ${_readable(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readable(Object error) {
    final text = error.toString();
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }

  Future<void> _rename(Document document) async {
    final controller = TextEditingController(text: document.title);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename scan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) return;
    await ref
        .read(documentRepositoryProvider)
        .renameDocument(document.id, trimmed);
    bumpLibrary(ref);
  }

  Future<void> _moveToFolder(Document document) async {
    final folders =
        ref.read(foldersProvider).valueOrNull ??
        await ref.read(documentRepositoryProvider).getFolders();
    if (!mounted) return;
    final destination = await showMoveToFolderSheet(
      context: context,
      folders: folders,
      createFolder: (name) async {
        final folder = await ref
            .read(documentRepositoryProvider)
            .createFolder(name);
        bumpLibrary(ref);
        return folder;
      },
    );
    if (destination == null || !mounted) return;
    await ref
        .read(documentRepositoryProvider)
        .moveDocuments(
          documentIds: [document.id],
          folderId: destination.folderId,
        );
    bumpLibrary(ref);
    if (!mounted) return;
    AppHaptics.success();
    _showMessage(
      destination.folderId == null ? 'Moved to Documents' : 'Moved to folder',
    );
  }

  Future<void> _reorder(Document document, int oldIndex, int newIndex) async {
    AppHaptics.selection();
    await ref
        .read(documentRepositoryProvider)
        .reorderPages(document.id, oldIndex, newIndex);
    bumpLibrary(ref);
  }

  Future<void> _deletePage(Document document, ScanPage page) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this page?'),
        content: const Text(
          'This page is removed. The last page of a scan goes to Trash for 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref
        .read(documentRepositoryProvider)
        .deletePage(documentId: document.id, pagePath: page.path);
    AppHaptics.success();
    bumpLibrary(ref);
    if (mounted && document.pageCount <= 1) context.pop();
  }

  Future<void> _extractText(Document document) async {
    if (kIsWeb) {
      _showMessage('Text recognition is available on iOS and Android.');
      return;
    }
    final isPro = ref.read(proProvider).isPro;
    if (document.pages.length > 1 && !isPro) {
      final ok = await requirePro(context, ref);
      if (!ok || !mounted) return;
    }
    var language = document.ocrLanguage ?? OcrLanguage.english.code;
    if (ref.read(proProvider).isPro) {
      final picked = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('OCR language')),
              for (final item in OcrLanguage.all)
                ListTile(
                  title: Text(item.label),
                  trailing: item.code == language
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, item.code),
                ),
            ],
          ),
        ),
      );
      if (picked != null) language = picked;
    }
    setState(() {
      _busy = true;
      _busyLabel = 'Reading the text…';
    });
    try {
      final parts = <String>[];
      final blocks = <OcrBlock>[];
      for (var i = 0; i < document.pages.length; i++) {
        final page = document.pages[i];
        if (!File(page.path).existsSync()) continue;
        if (mounted && document.pages.length > 1) {
          setState(() => _busyLabel = 'Reading page ${i + 1}…');
        }
        final result = await _ocr.recognizePage(
          await File(page.path).readAsBytes(),
          language: language,
          pageIndex: i,
        );
        if (result.text.isNotEmpty) parts.add(result.text);
        blocks.addAll(result.blocks);
      }
      final text = parts.join('\n\n').trim();
      const organizer = DocumentOrganizer();
      await ref.read(documentRepositoryProvider).updateDocument(
        document.id,
        (current) {
          var next = current.copyWith(
            ocrText: text,
            ocrBlocks: blocks,
            ocrLanguage: language,
            category: organizer.categorize(text) ?? current.category,
          );
          if (DocumentOrganizer.isGenericTitle(current.title) &&
              text.isNotEmpty) {
            next = next.copyWith(title: organizer.suggestTitle(text));
          }
          return next;
        },
      );
      bumpLibrary(ref);
      if (!mounted) return;
      AppHaptics.success();
      await _applyAutoFile(document, text);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => OcrResultScreen(text: text)),
      );
    } catch (e) {
      if (mounted) _showMessage(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFavorite(Document document) async {
    if (!ref.read(proProvider).isPro) {
      final ok = await requirePro(context, ref);
      if (!ok || !mounted) return;
    }
    await ref.read(documentRepositoryProvider).updateDocument(
      document.id,
      (current) => current.copyWith(isFavorite: !current.isFavorite),
    );
    bumpLibrary(ref);
  }

  Future<void> _togglePrivate(Document document) async {
    if (!ref.read(proProvider).isPro) {
      final ok = await requirePro(context, ref);
      if (!ok || !mounted) return;
    }
    await ref.read(documentRepositoryProvider).updateDocument(
      document.id,
      (current) => current.copyWith(isPrivate: !current.isPrivate),
    );
    bumpLibrary(ref);
  }

  Future<void> _splitAfter(Document document, int afterIndex) async {
    try {
      final created = await ref
          .read(documentRepositoryProvider)
          .splitAfter(documentId: document.id, afterIndex: afterIndex);
      bumpLibrary(ref);
      AppHaptics.success();
      if (mounted) {
        _showMessage('Split into “${created.title}”');
      }
    } catch (e) {
      if (mounted) _showMessage(_readable(e));
    }
  }

  Future<void> _splitAll(Document document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Split into single pages?'),
        content: const Text(
          'Each page becomes its own scan. This one goes to Trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Split'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(documentRepositoryProvider).splitAll(document.id);
      bumpLibrary(ref);
      AppHaptics.success();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _showMessage(_readable(e));
    }
  }

  Future<void> _trash(Document document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: const Text('It stays in Trash for 30 days.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(documentRepositoryProvider).moveToTrash(document.id);
    bumpLibrary(ref);
    AppHaptics.success();
    if (mounted) context.pop();
  }

  Future<void> _autoFileIfNeeded() async {
    if (_autoFileStarted || kIsWeb) return;
    _autoFileStarted = true;
    if (!ref.read(proProvider).isPro) return;
    final document = await ref
        .read(documentRepositoryProvider)
        .getDocument(widget.documentId);
    if (document == null ||
        document.autoFiled ||
        document.importedFromPdf ||
        widget.mode != DocumentScreenMode.scan) {
      return;
    }

    final parts = <String>[];
    for (final page in document.pages.take(2)) {
      if (!File(page.path).existsSync()) continue;
      try {
        final text = await _ocr.recognize(await File(page.path).readAsBytes());
        if (text.trim().isNotEmpty) parts.add(text.trim());
      } catch (_) {
        // Plugin missing or a bad page: try again the next time this scan opens.
        _autoFileStarted = false;
        return;
      }
    }
    if (!mounted) return;
    await _applyAutoFile(document, parts.join('\n\n'));
  }

  Future<void> _applyAutoFile(Document document, String text) async {
    final latest = await ref
        .read(documentRepositoryProvider)
        .getDocument(document.id);
    if (latest == null) return;
    final outcome = await _autoFile.apply(
      repository: ref.read(documentRepositoryProvider),
      document: latest,
      text: text,
      isPro: ref.read(proProvider).isPro,
    );
    bumpLibrary(ref);
    if (outcome.message != null && mounted) {
      _showMessage(outcome.message!);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Title and the document's vitals, stacked in the bar.
///
/// The page count and date used to sit in a separate strip under the app bar,
/// which spent a whole row of a small screen on two facts.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          document.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 2),
        Text(
          '${document.pageCount} page'
          '${document.pageCount == 1 ? '' : 's'} · '
          '${DateFormat.yMMMd().format(document.createdAt)}',
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// The two things you do to a finished document.
///
/// Adding a page was a bare 54pt square with a plus in it, sitting next to a
/// labelled button — the shape of an action nobody knows the name of.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.mode,
    required this.onAddPage,
    required this.onSign,
    required this.onExport,
  });

  final bool busy;
  final DocumentScreenMode mode;
  final VoidCallback onAddPage;
  final VoidCallback onSign;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.white
            : theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              if (mode == DocumentScreenMode.signPdf)
                Expanded(
                  child: TactileButton(
                    label: 'Sign',
                    icon: Icons.draw_rounded,
                    filled: false,
                    onPressed: busy ? null : onSign,
                  ),
                )
              else
                Expanded(
                  flex: 3,
                  child: TactileButton(
                    label: mode == DocumentScreenMode.editPdf
                        ? 'Add pages'
                        : 'Add page',
                    icon: Icons.add_rounded,
                    filled: false,
                    onPressed: busy ? null : onAddPage,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: TactileButton(
                  label: 'Export',
                  icon: Icons.ios_share_rounded,
                  haptic: AppHaptic.impactMedium,
                  onPressed: busy ? null : onExport,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    super.key,
    required this.documentId,
    required this.page,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    this.onRotate,
    this.onSign,
    this.onSplitAfter,
  });

  final int documentId;
  final ScanPage page;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRotate;
  final VoidCallback? onSign;
  final VoidCallback? onSplitAfter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final thumbnail = SizedBox(
      width: 68,
      height: 90,
      child: PaperSheet(
        radius: 10,
        lift: 0.7,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageThumbnail(path: page.path, cacheWidth: 204, seed: index + 1),
            for (final stamp in page.stamps)
              if (!kIsWeb && File(stamp.imagePath).existsSync())
                Positioned(
                  left: stamp.nx * 68,
                  top: stamp.ny * 90,
                  width: stamp.nw * 68,
                  height: stamp.nh * 90,
                  child: Image.file(
                    File(stamp.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onPressed: onEdit,
        haptic: AppHaptic.impactLight,
        scale: Tactile.pressScaleCard,
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        minSize: 0,
        child: Container(
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.light
                ? Colors.white
                : scheme.surface,
            borderRadius: BorderRadius.circular(Brand.radiusCard),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Only page one flies from the library tile — it is the page
                // the tile was showing.
                if (index == 0)
                  Hero(tag: 'document-$documentId', child: thumbnail)
                else
                  thumbnail,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Page ${index + 1}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            onSign != null
                                ? Icons.draw_rounded
                                : Icons.auto_fix_high_rounded,
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            onSign != null
                                ? (page.hasSignature
                                      ? 'Signed'
                                      : 'Tap to sign')
                                : 'Crop and enhance',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onRotate != null)
                  TactileIconButton(
                    icon: Icons.rotate_90_degrees_cw_rounded,
                    tooltip: 'Rotate page',
                    color: scheme.onSurfaceVariant,
                    onPressed: onRotate,
                  ),
                if (onSign != null)
                  TactileIconButton(
                    icon: Icons.draw_outlined,
                    tooltip: 'Sign this page',
                    color: scheme.onSurfaceVariant,
                    onPressed: onSign,
                  ),
                TactileIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete page',
                  color: scheme.onSurfaceVariant,
                  onPressed: onDelete,
                ),
                if (onSplitAfter != null)
                  TactileIconButton(
                    icon: Icons.call_split_rounded,
                    tooltip: 'Split after this page',
                    color: scheme.onSurfaceVariant,
                    onPressed: onSplitAfter,
                  ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
