import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';
import 'package:scan2/features/home/domain/import_service.dart';
import 'package:scan2/features/home/presentation/home_hero.dart';
import 'package:scan2/features/home/presentation/home_shortcuts.dart';
import 'package:scan2/features/library/presentation/document_detail_screen.dart';
import 'package:scan2/features/library/data/document_store.dart';
import 'package:scan2/features/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/features/crop/domain/crop_args.dart';
import 'package:intl/intl.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/illustrations.dart';
import 'package:scan2/core/widgets/page_thumbnail.dart';
import 'package:scan2/core/widgets/paper.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/export_service.dart';
import 'package:scan2/features/library/domain/folder.dart';
import 'package:scan2/features/library/domain/smart_folder.dart';
import 'package:scan2/features/library/presentation/widgets/export_sheet.dart';
import 'package:scan2/features/library/presentation/widgets/folder_actions.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:scan2/features/pro/presentation/pro_gate.dart';
import 'package:scan2/features/settings/presentation/app_lock.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';

enum DocumentSort {
  newest('Newest first', Icons.schedule_rounded),
  oldest('Oldest first', Icons.history_rounded),
  name('Name', Icons.sort_by_alpha_rounded),
  pages('Most pages', Icons.layers_rounded);

  const DocumentSort(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The documents workspace: search, sort, grid or list, and multi-select.
class DocumentsView extends ConsumerStatefulWidget {
  const DocumentsView({
    super.key,
    this.onOpenMenu,
    this.onScan,
    this.onAllTools,
  });

  /// Opens the shell's side menu. Null when this view is shown on its own.
  final VoidCallback? onOpenMenu;

  /// Camera capture. The shell handles this so `/camera` is pushed from the
  /// same context as the docked Scan button — `context.push('/camera')` from
  /// inside this view does not change the route.
  final VoidCallback? onScan;

  /// Opens All tools. Pushed from the shell so the route actually changes.
  final VoidCallback? onAllTools;

  @override
  ConsumerState<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends ConsumerState<DocumentsView> {
  final _searchController = TextEditingController();
  String _query = '';
  DocumentSort _sort = DocumentSort.newest;
  bool _gridView = false;
  bool _browsingAll = false;
  final Set<int> _selected = {};

  static final _importer = ImportService();

  bool get _selecting => _selected.isNotEmpty;
  bool _working = false;
  String _workingLabel = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(documentsProvider);
    final all = async.valueOrNull ?? const <Document>[];
    final folders = ref.watch(foldersProvider).valueOrNull ?? const <Folder>[];
    final viewingFolderId = ref.watch(openFolderIdProvider);
    final smartFolder = ref.watch(smartFolderProvider);
    final openFolder = _folderById(folders, viewingFolderId);
    final documents = _sorted(
      _filtered(_visibleDocuments(all, viewingFolderId)),
    );
    final shownFolders = _visibleFolders(folders, viewingFolderId);
    final items = <_LibraryItem>[
      for (final folder in shownFolders)
        _LibraryItem.folder(folder, _countInFolder(all, folder.id)),
      for (final doc in documents) _LibraryItem.document(doc),
    ];
    final loading = async.valueOrNull == null && async.isLoading;
    final hasLibrary = all.isNotEmpty || folders.isNotEmpty;
    final empty = !loading && items.isEmpty;
    final onRoot = openFolder == null && smartFolder == null;
    final showSearch = hasLibrary && !_selecting;
    final listed = onRoot && !_browsingAll && _query.isEmpty
        ? items.take(8).toList()
        : items;

    final body = Scaffold(
      backgroundColor: theme.brightness == Brightness.light
          ? Brand.canvas
          : scheme.surface,
      body: _StatusBarScrim(
        color: onRoot && !_selecting
            ? Brand.hero
            : theme.brightness == Brightness.light
            ? Brand.canvas
            : scheme.surface,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _selecting
                    ? SafeArea(
                        bottom: false,
                        child: _SelectionBar(
                          key: const ValueKey('selecting'),
                          count: _selected.length,
                          onCancel: () => setState(_selected.clear),
                          onSelectAll: () => setState(() {
                            _selected
                              ..clear()
                              ..addAll(documents.map((d) => d.id));
                          }),
                          onMove: () => _moveSelected(folders),
                          onShare: () => _shareSelected(documents),
                          onMerge: _selected.length >= 2
                              ? () => _mergeSelected()
                              : null,
                          onDelete: () => _deleteSelected(documents),
                        ),
                      )
                    : onRoot
                    ? HomeHero(
                        key: const ValueKey('home'),
                        onOpenMenu: widget.onOpenMenu,
                      )
                    : SafeArea(
                        bottom: false,
                        child: _FolderHeader(
                          key: ValueKey(
                            openFolder?.id ?? smartFolder?.name ?? 'folder',
                          ),
                          title: openFolder?.name ?? smartFolder?.label ?? '',
                          scanCount: documents.length,
                          onBack: _leaveFolder,
                        ),
                      ),
              ),
            ),
            if (!_selecting && onRoot)
              SliverToBoxAdapter(
                child: HomeShortcuts(
                  onFromPhotos: _importPhotos,
                  onImportFile: _uploadPdf,
                  onScanFromCamera: _openCameraScan,
                  onAllTools: _openAllTools,
                ),
              ),
            if (!_selecting && onRoot)
              SliverToBoxAdapter(
                child: _FreeScansLine(
                  label: ref.watch(proProvider).isPro
                      ? 'Scanella Pro · unlimited scans'
                      : ref.watch(scanQuotaProvider).freePlanLabel,
                ),
              ),
            if (hasLibrary) ...[
              SliverToBoxAdapter(
                child: _toolBar(
                  theme,
                  documents.length,
                  folderCount: shownFolders.length,
                  onRoot: onRoot,
                ),
              ),
              if (showSearch) SliverToBoxAdapter(child: _searchField(theme)),
            ],
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (empty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _query.isNotEmpty
                    ? _NoResults(query: _query)
                    : openFolder != null
                    ? _EmptyFolder(name: openFolder.name)
                    : smartFolder != null
                    ? _EmptyFolder(name: smartFolder.label)
                    : _EmptyLibrary(onNewFolder: _createFolder),
              )
            else if (_gridView)
              _grid(listed)
            else
              _list(listed),
          ],
        ),
      ),
    );

    if (!_working) return body;
    return Stack(
      children: [
        body,
        Positioned.fill(
          child: ColoredBox(
            color: Brand.ink.withValues(alpha: 0.55),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 18),
                  Text(
                    _workingLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Tools -------------------------------------------------------------

  Future<void> _importPhotos() async {
    if (!await ensureFreeScanSlot(context, ref)) return;
    if (!mounted) return;
    await _runImport(
      'Reading photos…',
      (filter, onProgress) =>
          _importer.fromPhotos(filter: filter, onProgress: onProgress),
    );
  }

  void _openCameraScan() {
    final open = widget.onScan;
    if (open != null) {
      open();
      return;
    }
    if (GoRouter.maybeOf(context) != null) {
      context.push('/camera');
    }
  }

  void _openAllTools() {
    final open = widget.onAllTools;
    if (open != null) {
      open();
      return;
    }
    if (GoRouter.maybeOf(context) != null) {
      context.push('/tools');
    }
  }

  /// Pick a PDF from Files and open it with Edit PDF tools — not the scan
  /// crop/enhance path, and not a picker of existing scans.
  Future<void> _uploadPdf() async {
    if (_working) return;
    if (!await ensureFreeScanSlot(context, ref)) return;
    if (!mounted) return;
    final repository = ref.read(documentRepositoryProvider);
    if (repository is! DocumentStore) {
      _message('Importing is available on iOS and Android.');
      return;
    }
    setState(() {
      _working = true;
      _workingLabel = 'Reading PDF…';
    });
    try {
      final imported = await _importer.fromPdfs(
        onProgress: (done, total) {
          if (!mounted || total < 2) return;
          setState(
            () => _workingLabel =
                'Reading page ${(done + 1).clamp(1, total)} of $total…',
          );
        },
      );
      if (imported == null) return;
      final doc = await repository.createProcessedDocument(
        pages: imported.pages,
        title: imported.title,
        folderId: ref.read(openFolderIdProvider),
        importedFromPdf: true,
      );
      await recordNewScan(ref);
      bumpLibrary(ref);
      await AppHaptics.success();
      if (mounted) {
        context.push(
          '/library/document/${doc.id}',
          extra: DocumentScreenMode.editPdf,
        );
      }
    } catch (e) {
      await AppHaptics.error();
      if (mounted) _message(_readable(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Shared by photo import: pick, process, file as one document, open it.
  /// Cancelling the picker is a no-op rather than an error — backing out of a
  /// photo library is not a failure.
  Future<void> _runImport(
    String label,
    Future<List<ProcessedPage>> Function(
      ScanFilter filter,
      void Function(int done, int total) onProgress,
    )
    pick,
  ) async {
    if (_working) return;
    final repository = ref.read(documentRepositoryProvider);
    if (repository is! DocumentStore) {
      _message('Importing is available on iOS and Android.');
      return;
    }
    final filter = ref.read(settingsProvider).defaultFilter;
    setState(() {
      _working = true;
      _workingLabel = label;
    });
    try {
      final pages = await pick(filter, (done, total) {
        if (!mounted || total < 2) return;
        setState(
          () => _workingLabel =
              'Reading page ${(done + 1).clamp(1, total)} of $total…',
        );
      });
      if (pages.isEmpty) return;
      final doc = await repository.createProcessedDocument(
        pages: pages,
        folderId: ref.read(openFolderIdProvider),
      );
      await recordNewScan(ref);
      bumpLibrary(ref);
      await AppHaptics.success();
      if (!mounted) return;
      // Open the crop on page one with no quad, so the crop screen finds the
      // page edges itself; the user checks them and taps Next.
      final first = doc.pages.first;
      context.push(
        '/crop',
        extra: CropArgs(
          imagePath: first.editSource,
          adjustments: first.adjustments,
          documentId: doc.id,
          cropRemainingPages: true,
        ),
      );
    } catch (e) {
      await AppHaptics.error();
      if (mounted) _message(_readable(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _readable(Object error) {
    final text = error is StateError ? error.message : error.toString();
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }

  Folder? _folderById(List<Folder> folders, int? id) {
    if (id == null) return null;
    for (final folder in folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  void _setFolder(int? id) {
    setState(() {
      _selected.clear();
      if (id != null) {
        _searchController.clear();
        _query = '';
      }
    });
    ref.read(openFolderIdProvider.notifier).state = id;
    if (id != null) {
      ref.read(smartFolderProvider.notifier).state = null;
    }
  }

  void _leaveFolder() {
    setState(_selected.clear);
    ref.read(openFolderIdProvider.notifier).state = null;
    ref.read(smartFolderProvider.notifier).state = null;
  }

  List<Document> _visibleDocuments(List<Document> documents, int? folderId) {
    final scoped = _scopedDocuments(documents, folderId);
    final smart = ref.read(smartFolderProvider);
    if (smart == null) {
      return [
        for (final doc in scoped)
          if (!doc.isPrivate && !doc.hideFromLibrary) doc,
      ];
    }
    if (smart == SmartFolder.private) {
      return smart.filter(scoped);
    }
    if (smart == SmartFolder.ids) {
      return smart.filter([
        for (final doc in scoped)
          if (!doc.isPrivate) doc,
      ]);
    }
    return smart.filter([
      for (final doc in scoped)
        if (!doc.isPrivate && !doc.hideFromLibrary) doc,
    ]);
  }

  List<Document> _scopedDocuments(List<Document> documents, int? folderId) {
    // Searching from home looks through every scan, including ones already
    // filed, so a document is not hidden just because it lives in a folder.
    if (folderId == null && _query.isNotEmpty) return documents;
    return [
      for (final doc in documents)
        if (doc.folderId == folderId) doc,
    ];
  }

  List<Folder> _visibleFolders(List<Folder> folders, int? folderId) {
    if (folderId != null) return const [];
    if (ref.read(smartFolderProvider) != null) return const [];
    if (_query.isEmpty) return folders;
    final needle = _query.toLowerCase();
    return [
      for (final folder in folders)
        if (folder.name.toLowerCase().contains(needle)) folder,
    ];
  }

  int _countInFolder(List<Document> documents, int folderId) {
    var count = 0;
    for (final doc in documents) {
      if (doc.folderId == folderId) count++;
    }
    return count;
  }

  Future<void> _createFolder() async {
    final name = await promptFolderName(context);
    if (name == null || !mounted) return;
    try {
      await ref.read(documentRepositoryProvider).createFolder(name);
      bumpLibrary(ref);
      await AppHaptics.success();
    } catch (e) {
      if (mounted) _message(_readable(e));
    }
  }

  Future<void> _renameFolder(Folder folder) async {
    final name = await promptFolderName(
      context,
      title: 'Rename folder',
      confirmLabel: 'Save',
      initial: folder.name,
    );
    if (name == null || !mounted) return;
    await ref.read(documentRepositoryProvider).renameFolder(folder.id, name);
    bumpLibrary(ref);
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${folder.name}”?'),
        content: const Text(
          'The scans inside stay in Documents. Only the folder is removed.',
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
    await ref.read(documentRepositoryProvider).deleteFolder(folder.id);
    if (ref.read(openFolderIdProvider) == folder.id) _setFolder(null);
    AppHaptics.success();
    bumpLibrary(ref);
  }

  Future<void> _moveSelected(List<Folder> folders) async {
    if (_selected.isEmpty) return;
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
          documentIds: _selected.toList(),
          folderId: destination.folderId,
        );
    AppHaptics.success();
    setState(_selected.clear);
    bumpLibrary(ref);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // -------------------------------------------------------------------------

  List<Document> _filtered(List<Document> documents) {
    if (_query.isEmpty) return documents;
    final needle = _query.toLowerCase();
    return [
      for (final doc in documents)
        if (doc.title.toLowerCase().contains(needle) ||
            (doc.ocrText?.toLowerCase().contains(needle) ?? false) ||
            (doc.category?.toLowerCase().contains(needle) ?? false) ||
            doc.tags.any((tag) => tag.toLowerCase().contains(needle)))
          doc,
    ];
  }

  List<Document> _sorted(List<Document> documents) {
    final list = [...documents];
    switch (_sort) {
      case DocumentSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case DocumentSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case DocumentSort.name:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case DocumentSort.pages:
        list.sort((a, b) => b.pageCount.compareTo(a.pageCount));
    }
    return list;
  }

  Widget _searchField(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search names',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 21,
            color: scheme.onSurfaceVariant,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : TactileIconButton(
                  icon: Icons.cancel_rounded,
                  size: 19,
                  tooltip: 'Clear search',
                  color: scheme.onSurfaceVariant,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: theme.brightness == Brightness.light
              ? Colors.white
              : scheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Brand.radiusField),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Brand.radiusField),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Brand.radiusField),
            borderSide: BorderSide(color: scheme.primary, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _toolBar(
    ThemeData theme,
    int shown, {
    int folderCount = 0,
    bool onRoot = true,
  }) {
    final scheme = theme.colorScheme;
    final parts = <String>[
      if (folderCount > 0) '$folderCount folder${folderCount == 1 ? '' : 's'}',
      '$shown scan${shown == 1 ? '' : 's'}',
    ];
    final newFolder = Tooltip(
      message: 'New folder',
      child: FilledButton.icon(
        onPressed: _createFolder,
        icon: const Icon(Icons.create_new_folder_outlined, size: 15),
        label: const Text(
          'New folder',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Brand.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: [
          if (onRoot)
            Text(
              _browsingAll ? 'All scans' : 'Recent scans',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.brightness == Brightness.light
                    ? Brand.ink
                    : theme.colorScheme.onSurface,
              ),
            )
          else
            Text(parts.join(' · '), style: theme.textTheme.labelMedium),
          if (onRoot && !_browsingAll)
            TextButton(
              onPressed: () => setState(() => _browsingAll = true),
              style: TextButton.styleFrom(
                foregroundColor: Brand.accent,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.only(left: 8, right: 4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          const Spacer(),
          if (onRoot) newFolder,
          if (!onRoot) ...[
            PopupMenuButton<DocumentSort>(
              initialValue: _sort,
              tooltip: 'Sort',
              position: PopupMenuPosition.under,
              onSelected: (value) {
                AppHaptics.selection();
                setState(() => _sort = value);
              },
              itemBuilder: (context) => [
                for (final option in DocumentSort.values)
                  PopupMenuItem(
                    value: option,
                    child: Row(
                      children: [
                        Icon(
                          option.icon,
                          size: 18,
                          color: option == _sort
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Text(option.label),
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.light
                      ? Colors.white
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swap_vert_rounded,
                      size: 17,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(_sort.label, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ViewToggle(
              gridView: _gridView,
              onChanged: (value) => setState(() => _gridView = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _grid(List<_LibraryItem> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 150),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 22,
          crossAxisSpacing: 18,
          childAspectRatio: 0.68,
        ),
        delegate: SliverChildBuilderDelegate(
          childCount: items.length,
          (context, index) => Reveal(
            index: index,
            key: ValueKey(items[index].key),
            child: _libraryCell(items[index], index),
          ),
        ),
      ),
    );
  }

  Widget _list(List<_LibraryItem> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 150),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => Reveal(
          index: index,
          key: ValueKey('row-${items[index].key}'),
          child: _libraryRow(items[index], index),
        ),
      ),
    );
  }

  Widget _libraryCell(_LibraryItem item, int index) {
    final folder = item.folder;
    if (folder != null) {
      return _FolderTile(
        folder: folder,
        count: item.scanCount,
        onOpen: () => _setFolder(folder.id),
        onRename: () => _renameFolder(folder),
        onDelete: () => _deleteFolder(folder),
      );
    }
    final document = item.document!;
    return _DocumentTile(
      document: document,
      index: index,
      selected: _selected.contains(document.id),
      selecting: _selecting,
      onTap: () => _open(document),
      onToggle: () => _toggle(document),
      onLongPress: () => _documentMenu(document),
    );
  }

  Widget _libraryRow(_LibraryItem item, int index) {
    final folder = item.folder;
    if (folder != null) {
      return _FolderRow(
        folder: folder,
        count: item.scanCount,
        onOpen: () => _setFolder(folder.id),
        onRename: () => _renameFolder(folder),
        onDelete: () => _deleteFolder(folder),
      );
    }
    final document = item.document!;
    return _DocumentRow(
      document: document,
      index: index,
      selected: _selected.contains(document.id),
      selecting: _selecting,
      onTap: () => _open(document),
      onToggle: () => _toggle(document),
      onLongPress: () => _documentMenu(document),
    );
  }

  void _open(Document document) {
    if (_selecting) {
      _toggle(document);
      return;
    }
    context.push('/library/document/${document.id}');
  }

  void _toggle(Document document) {
    setState(() {
      if (!_selected.remove(document.id)) _selected.add(document.id);
    });
  }

  Future<void> _deleteSelected(List<Document> documents) async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move $count scan${count == 1 ? '' : 's'} to Trash?'),
        content: const Text('They stay in Trash for 30 days.'),
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

    final repository = ref.read(documentRepositoryProvider);
    for (final id in _selected.toList()) {
      await repository.moveToTrash(id);
    }
    AppHaptics.success();
    setState(_selected.clear);
    bumpLibrary(ref);
  }

  Future<void> _shareSelected(List<Document> documents) async {
    if (kIsWeb) {
      _message('Share is available on device.');
      return;
    }
    final selected = [
      for (final doc in documents)
        if (_selected.contains(doc.id)) doc,
    ];
    if (selected.isEmpty) return;
    setState(() {
      _working = true;
      _workingLabel = 'Preparing PDF…';
    });
    try {
      const exporter = ExportService();
      if (selected.length == 1) {
        await exporter.sharePdf(
          selected.first,
          shareOrigin: shareOriginFor(context),
        );
      } else {
        await exporter.shareDocuments(
          selected,
          shareOrigin: shareOriginFor(context),
        );
      }
    } catch (e) {
      if (mounted) _message(_readable(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _mergeSelected() async {
    if (_selected.length < 2) return;
    try {
      final merged = await ref
          .read(documentRepositoryProvider)
          .mergeDocuments(_selected.toList());
      for (final id in _selected.toList()) {
        await ref.read(documentRepositoryProvider).moveToTrash(id);
      }
      AppHaptics.success();
      setState(_selected.clear);
      bumpLibrary(ref);
      if (mounted) context.push('/library/document/${merged.id}');
    } catch (e) {
      if (mounted) _message(_readable(e));
    }
  }

  Future<void> _shareOne(Document document) async {
    if (kIsWeb) {
      _message('Share is available on device.');
      return;
    }
    setState(() {
      _working = true;
      _workingLabel = 'Preparing PDF…';
    });
    try {
      await const ExportService().sharePdf(
        document,
        shareOrigin: shareOriginFor(context),
      );
    } catch (e) {
      if (mounted) _message(_readable(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _documentMenu(Document document) async {
    if (_selecting) {
      _toggle(document);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset < 24 ? 28 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Share PDF'),
                onTap: () => Navigator.pop(context, 'share'),
              ),
              ListTile(
                leading: Icon(
                  document.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                ),
                title: Text(
                  document.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                ),
                onTap: () => Navigator.pop(context, 'favorite'),
              ),
              ListTile(
                leading: Icon(
                  document.isPrivate
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                ),
                title: Text(
                  document.isPrivate ? 'Remove from private' : 'Make private',
                ),
                onTap: () => Navigator.pop(context, 'private'),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: const Text('Move to folder'),
                onTap: () => Navigator.pop(context, 'move'),
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outlined),
                title: const Text('Select'),
                onTap: () => Navigator.pop(context, 'select'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Move to Trash'),
                onTap: () => Navigator.pop(context, 'trash'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'share':
        await _shareOne(document);
      case 'favorite':
        await ref
            .read(documentRepositoryProvider)
            .updateDocument(
              document.id,
              (current) => current.copyWith(isFavorite: !current.isFavorite),
            );
        bumpLibrary(ref);
      case 'private':
        await _togglePrivate(document);
      case 'move':
        setState(() => _selected.add(document.id));
        final folders =
            ref.read(foldersProvider).valueOrNull ?? const <Folder>[];
        await _moveSelected(folders);
      case 'select':
        _toggle(document);
      case 'trash':
        setState(() => _selected.add(document.id));
        await _deleteSelected([document]);
    }
  }

  Future<void> _togglePrivate(Document document) async {
    // Private documents are part of the free plan.
    if (!document.isPrivate) {
      final allowed = await ref
          .read(appLockProvider.notifier)
          .authenticateForPrivate();
      if (!allowed) {
        _message('Unlock the phone to mark a document private.');
        return;
      }
    }
    await ref
        .read(documentRepositoryProvider)
        .updateDocument(
          document.id,
          (current) => current.copyWith(isPrivate: !current.isPrivate),
        );
    bumpLibrary(ref);
    if (!document.isPrivate) {
      _message('Hidden in Private. Face ID opens that folder.');
    }
  }
}

// ---------------------------------------------------------------------------

class _LibraryItem {
  const _LibraryItem.folder(this.folder, this.scanCount) : document = null;
  const _LibraryItem.document(this.document) : folder = null, scanCount = 0;

  final Folder? folder;
  final Document? document;
  final int scanCount;

  String get key =>
      folder != null ? 'folder-${folder!.id}' : 'doc-${document!.id}';
}

/// Back button and folder name when the user is inside a folder.
class _FolderHeader extends StatelessWidget {
  const _FolderHeader({
    super.key,
    required this.title,
    required this.scanCount,
    required this.onBack,
  });

  final String title;
  final int scanCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 12, 10),
      child: Row(
        children: [
          TactileIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'All documents',
            color: theme.colorScheme.onSurface,
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  scanCount == 0
                      ? 'Tap the scan button to add pages here'
                      : '$scanCount scan${scanCount == 1 ? '' : 's'} in this folder',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    super.key,
    required this.count,
    required this.onCancel,
    required this.onSelectAll,
    required this.onMove,
    required this.onShare,
    required this.onDelete,
    this.onMerge,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onMove;
  final VoidCallback onShare;
  final VoidCallback? onMerge;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(Brand.radiusCard),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onCancel,
            tooltip: 'Cancel',
            color: theme.colorScheme.onPrimary,
          ),
          Text(
            '$count selected',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSelectAll,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('Select all'),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share PDF',
            onPressed: onShare,
            color: theme.colorScheme.onPrimary,
          ),
          if (onMerge != null)
            IconButton(
              icon: const Icon(Icons.merge_type_rounded),
              tooltip: 'Merge',
              onPressed: onMerge,
              color: theme.colorScheme.onPrimary,
            ),
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: 'Move to folder',
            onPressed: onMove,
            color: theme.colorScheme.onPrimary,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Move to Trash',
            onPressed: onDelete,
            color: theme.colorScheme.onPrimary,
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.gridView, required this.onChanged});

  final bool gridView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget half(IconData icon, bool active, String tooltip, bool value) {
      return PressableScale(
        onPressed: active ? null : () => onChanged(value),
        enabled: !active,
        haptic: AppHaptic.selection,
        scale: Tactile.pressScaleIcon,
        overlay: false,
        minSize: 0,
        tooltip: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.white
            : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(Icons.grid_view_rounded, gridView, 'Show as grid', true),
          half(Icons.view_agenda_rounded, !gridView, 'Show as list', false),
        ],
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.count,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final Folder folder;
  final int count;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PressableScale(
      onPressed: onOpen,
      onLongPress: () =>
          _folderMenu(context, onRename: onRename, onDelete: onDelete),
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      overlay: false,
      minSize: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PaperSheet(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: scheme.primaryContainer),
                  Center(
                    child: Icon(
                      Icons.folder_rounded,
                      size: 64,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            folder.name,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            count == 0 ? 'Empty' : '$count scan${count == 1 ? '' : 's'}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.count,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final Folder folder;
  final int count;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PressableScale(
      onPressed: onOpen,
      onLongPress: () =>
          _folderMenu(context, onRename: onRename, onDelete: onDelete),
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
              SizedBox(
                width: 56,
                height: 74,
                child: PaperSheet(
                  radius: 9,
                  lift: 0.6,
                  child: ColoredBox(
                    color: scheme.primaryContainer,
                    child: Icon(
                      Icons.folder_rounded,
                      color: scheme.primary,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      count == 0
                          ? 'Empty'
                          : '$count scan${count == 1 ? '' : 's'}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _folderMenu(
  BuildContext context, {
  required VoidCallback onRename,
  required VoidCallback onDelete,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline_rounded),
            title: const Text('Rename'),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Delete folder'),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (action == 'rename') onRename();
  if (action == 'delete') onDelete();
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 190),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 52,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text('Nothing in $name yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap the scan button to add pages to this folder.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.index,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onToggle,
    required this.onLongPress,
  });

  final Document document;
  final int index;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PressableScale(
      onPressed: onTap,
      onLongPress: onLongPress,
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      overlay: false,
      minSize: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PaperSheet(
              selected: selected,
              stacked: document.pageCount > 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'document-${document.id}',
                    child: PageThumbnail(
                      path: document.pages.isEmpty
                          ? null
                          : document.pages.first.path,
                      cacheWidth: 420,
                      seed: document.id + index,
                    ),
                  ),
                  if (document.pageCount > 1)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _PageBadge(count: document.pageCount),
                    ),
                  if (document.isFavorite || document.isPrivate)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (document.isPrivate)
                            const Icon(Icons.lock_rounded, size: 16),
                          if (document.isFavorite)
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Brand.amber,
                            ),
                        ],
                      ),
                    ),
                  if (selecting)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _SelectionDot(selected: selected),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            document.title,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            formatScanTime(document.createdAt),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.index,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onToggle,
    required this.onLongPress,
  });

  final Document document;
  final int index;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.white
            : scheme.surface,
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        boxShadow: theme.brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Brand.ink.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: PressableScale(
                onPressed: onTap,
                onLongPress: onLongPress,
                haptic: AppHaptic.impactLight,
                scale: Tactile.pressScaleCard,
                minSize: 0,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 74,
                      child: PaperSheet(
                        radius: 9,
                        lift: 0.6,
                        child: Hero(
                          tag: 'document-${document.id}',
                          child: PageThumbnail(
                            path: document.pages.isEmpty
                                ? null
                                : document.pages.first.path,
                            cacheWidth: 168,
                            seed: document.id + index,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.layers_rounded,
                                size: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  '${document.pageCount} page'
                                  '${document.pageCount == 1 ? '' : 's'}'
                                  ' · ${formatScanTime(document.createdAt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selecting)
              _SelectionDot(selected: selected)
            else
              TactileIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: 'More',
                color: scheme.onSurfaceVariant,
                onPressed: onLongPress,
              ),
          ],
        ),
      ),
    );
  }
}

class _PageBadge extends StatelessWidget {
  const _PageBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Brand.ink.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_rounded, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : Colors.white.withValues(alpha: 0.9),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outline,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Brand.ink.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 17, color: scheme.onPrimary)
          : null,
    );
  }
}

/// The empty library.
///
/// This used to be three grey rectangles, on the one screen every new customer
/// sees first. The illustration set drawn for onboarding was only ever shown
/// during onboarding — so it earns its keep here instead.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onNewFolder});

  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        // The docked scan button floats over this area, and the hint was
        // running underneath it. Clearing its full height plus the bar.
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 190),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 210,
              child: HeroStage(
                // The disc is a fixed pale blue in the onboarding art, which
                // would burn a hole in a dark library. Everything else in the
                // composition — navy phone, white chips — carries over.
                discColor: theme.brightness == Brightness.light
                    ? const Color(0xFFEDF2FB)
                    : theme.colorScheme.surfaceContainerHigh,
                centre: const ScanningPhone(),
                chips: const [
                  HeroChip(
                    x: 0.10,
                    y: 0.30,
                    icon: Icons.picture_as_pdf_rounded,
                    color: Brand.pdfRed,
                    label: 'PDF',
                  ),
                  HeroChip(
                    x: 0.90,
                    y: 0.36,
                    icon: Icons.auto_fix_high_rounded,
                    color: Brand.accent,
                  ),
                  HeroChip(
                    x: 0.11,
                    y: 0.72,
                    icon: Icons.image_rounded,
                    color: Brand.imageGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your first scan starts here',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Point the camera at a page. The edges are found, the '
              'page is straightened and cleaned up, and it lands here — '
              'without ever leaving your phone.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 17,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap the scan button',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: onNewFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Or create a folder'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 130),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 28,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Text('No matches', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Nothing named “$query”, and no saved text matches.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Today, 11:33 AM" on the same day, otherwise a short date and time.
String formatScanTime(DateTime at, [DateTime? now]) {
  final local = at.toLocal();
  final today = now ?? DateTime.now();
  if (DateUtils.isSameDay(local, today)) {
    return 'Today, ${DateFormat.jm().format(local)}';
  }
  final yesterday = today.subtract(const Duration(days: 1));
  if (DateUtils.isSameDay(local, yesterday)) {
    return 'Yesterday, ${DateFormat.jm().format(local)}';
  }
  return DateFormat('MMM d, h:mm a').format(local);
}

/// Keeps the clock readable once the list scrolls under it.
class _StatusBarScrim extends StatelessWidget {
  const _StatusBarScrim({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.paddingOf(context).top,
          child: ColoredBox(color: color),
        ),
      ],
    );
  }
}

/// How many free scans are left, read from [ScanQuota], or that Pro is on.
class _FreeScansLine extends StatelessWidget {
  const _FreeScansLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
