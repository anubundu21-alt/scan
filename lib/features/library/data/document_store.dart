import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:scan2/features/camera/domain/quad_detector.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';
import 'package:scan2/features/library/data/document_storage.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/document_organizer.dart';
import 'package:scan2/features/library/domain/document_repository.dart';
import 'package:scan2/features/library/domain/folder.dart';
import 'package:scan2/features/library/domain/ocr_layout.dart';
import 'package:scan2/features/library/domain/page_editor.dart';
import 'package:scan2/features/library/domain/page_stamp.dart';
import 'package:scan2/features/library/domain/stamp_compositor.dart';

/// On-disk document library.
///
/// Pages live under `<appDocuments>/documents/<docId>/` and a single JSON
/// manifest alongside them records titles, page order, crop quads and filter
/// settings.
///
/// Page locations are persisted *relative* to the documents root and resolved
/// on load. iOS reassigns the application container path between installs and
/// upgrades, so absolute paths written today become dangling references after
/// the next TestFlight build — every thumbnail in the library would come back
/// as a broken-image icon.
class DocumentStore implements DocumentRepository {
  DocumentStore({DocumentStorage? storage})
    : _storage = storage ?? DocumentStorage();

  static const _manifestName = 'library.json';
  static const _manifestVersion = 5;
  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.heic'};

  final DocumentStorage _storage;
  final PageEditor _editor = const PageEditor();

  final List<Document> _documents = [];
  final List<Folder> _folders = [];
  int _nextId = 1;
  int _nextFolderId = 1;
  bool _loaded = false;

  /// Serialises manifest writes so two saves cannot interleave.
  Future<void> _writeChain = Future.value();

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = File(p.join(await _storage.rootPath(), _manifestName));
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return;
      await _restore(raw);
    } catch (e) {
      // A corrupt manifest must not cost the user their library; the page
      // files are still on disk and can be adopted directly.
      debugPrint('Library manifest unreadable, rebuilding from disk: $e');
      await _rebuildFromDisk();
    }
  }

  Future<void> _restore(Map<String, dynamic> raw) async {
    final root = await _storage.rootPath();
    final documents = raw['documents'];
    if (documents is! List) return;

    for (final entry in documents) {
      if (entry is! Map) continue;
      final id = entry['id'];
      if (id is! int) continue;

      final pages = <ScanPage>[];
      final rawPages = entry['pages'];
      if (rawPages is List) {
        for (final rawPage in rawPages) {
          final page = _pageFromJson(rawPage, root);
          if (page != null) pages.add(page);
        }
      }
      if (pages.isEmpty) continue;

      final rawFolderId = entry['folderId'];
      _documents.add(
        Document(
          id: id,
          title: entry['title'] as String? ?? 'Scan',
          createdAt:
              DateTime.tryParse(entry['createdAt'] as String? ?? '') ??
              DateTime.now(),
          pages: pages,
          folderId: rawFolderId is int ? rawFolderId : null,
          edgesAlreadyApplied: entry['edgesAlreadyApplied'] as bool? ?? false,
          deletedAt: DateTime.tryParse(entry['deletedAt'] as String? ?? ''),
          ocrText: entry['ocrText'] as String?,
          isIdCard: entry['isIdCard'] as bool? ?? false,
          importedFromPdf: entry['importedFromPdf'] as bool? ?? false,
          tags: _stringList(entry['tags']),
          isFavorite: entry['isFavorite'] as bool? ?? false,
          isPrivate: entry['isPrivate'] as bool? ?? false,
          category: entry['category'] as String?,
          contentHash: entry['contentHash'] as String?,
          ocrBlocks: [
            for (final raw in (entry['ocrBlocks'] as List? ?? const []))
              ?OcrBlock.fromJson(raw),
          ],
          ocrLanguage: entry['ocrLanguage'] as String?,
          autoFiled: entry['autoFiled'] as bool? ?? false,
          hideFromLibrary: entry['hideFromLibrary'] as bool? ?? false,
        ),
      );
    }

    _restoreFolders(raw);

    _documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final storedNext = raw['nextId'];
    _nextId = storedNext is int && storedNext > _highestId()
        ? storedNext
        : _highestId() + 1;
    final storedFolderNext = raw['nextFolderId'];
    _nextFolderId =
        storedFolderNext is int && storedFolderNext > _highestFolderId()
        ? storedFolderNext
        : _highestFolderId() + 1;

    _dropDanglingFolderIds();
    await _purgeExpiredTrash();
  }

  void _restoreFolders(Map<String, dynamic> raw) {
    final folders = raw['folders'];
    if (folders is! List) return;
    for (final entry in folders) {
      if (entry is! Map) continue;
      final id = entry['id'];
      if (id is! int) continue;
      final name = (entry['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      _folders.add(
        Folder(
          id: id,
          name: name,
          createdAt:
              DateTime.tryParse(entry['createdAt'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    }
    _folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  void _dropDanglingFolderIds() {
    final known = {for (final folder in _folders) folder.id};
    for (var i = 0; i < _documents.length; i++) {
      final folderId = _documents[i].folderId;
      if (folderId != null && !known.contains(folderId)) {
        _documents[i] = _documents[i].copyWith(clearFolder: true);
      }
    }
  }

  ScanPage? _pageFromJson(Object? raw, String root) {
    // v1 manifests stored each page as a bare relative path string.
    if (raw is String) return ScanPage(path: p.join(root, raw));
    if (raw is! Map) return null;

    final relative = raw['path'];
    if (relative is! String) return null;

    final originalRelative = raw['original'];
    return ScanPage(
      path: p.join(root, relative),
      originalPath: originalRelative is String
          ? p.join(root, originalRelative)
          : null,
      quad: _quadFromJson(raw['quad']),
      adjustments: _adjustmentsFromJson(raw['adjustments']),
      stamps: _stampsFromJson(raw['stamps'], root),
    );
  }

  static List<PageStamp> _stampsFromJson(Object? raw, String root) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        ?PageStamp.fromJson(
          entry,
          (rel) => p.isAbsolute(rel) ? rel : p.normalize(p.join(root, rel)),
        ),
    ];
  }

  static Quad? _quadFromJson(Object? raw) {
    if (raw is! List || raw.length != 8) return null;
    final v = [for (final n in raw) (n as num).toDouble()];
    return Quad(
      topLeft: Offset(v[0], v[1]),
      topRight: Offset(v[2], v[3]),
      bottomRight: Offset(v[4], v[5]),
      bottomLeft: Offset(v[6], v[7]),
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }

  Future<String?> _hashFirstPage(List<ScanPage> pages) async {
    if (pages.isEmpty) return null;
    final file = File(pages.first.path);
    if (!await file.exists()) return null;
    return const DocumentOrganizer().hashBytes(await file.readAsBytes());
  }

  static List<double> _quadToJson(Quad q) => [
    q.topLeft.dx,
    q.topLeft.dy,
    q.topRight.dx,
    q.topRight.dy,
    q.bottomRight.dx,
    q.bottomRight.dy,
    q.bottomLeft.dx,
    q.bottomLeft.dy,
  ];

  static ScanAdjustments _adjustmentsFromJson(Object? raw) {
    if (raw is! Map) return const ScanAdjustments();
    final filterIndex = raw['filter'];
    return ScanAdjustments(
      filter: filterIndex is int && filterIndex < ScanFilter.values.length
          ? ScanFilter.values[filterIndex]
          : ScanFilter.original,
      brightness: (raw['brightness'] as num?)?.toDouble() ?? 0,
      contrast: (raw['contrast'] as num?)?.toDouble() ?? 0,
      rotationTurns: (raw['rotationTurns'] as num?)?.toInt() ?? 0,
    );
  }

  /// Last-resort recovery: adopt whatever page files exist on disk.
  Future<void> _rebuildFromDisk() async {
    _documents.clear();
    _folders.clear();
    try {
      final root = Directory(await _storage.rootPath());
      if (!await root.exists()) return;

      for (final entity in root.listSync().whereType<Directory>()) {
        final id = int.tryParse(
          p.basename(entity.path).replaceFirst('doc_', ''),
        );
        if (id == null) continue;

        final files =
            entity
                .listSync()
                .whereType<File>()
                .map((f) => f.path)
                .where((path) => _imageExtensions.contains(p.extension(path)))
                .toList()
              ..sort();

        // Originals sit beside their page as `<name>.orig.jpg`; they are
        // sources, not pages in their own right.
        final pages = files
            .where((path) => !p.basename(path).contains('.orig.'))
            .map(
              (path) => ScanPage(
                path: path,
                originalPath: files.contains(_originalPathFor(path))
                    ? _originalPathFor(path)
                    : null,
              ),
            )
            .toList();
        if (pages.isEmpty) continue;

        _documents.add(
          Document(
            id: id,
            title: 'Recovered scan $id',
            createdAt: entity.statSync().modified,
            pages: pages,
          ),
        );
      }
      _documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _nextId = _highestId() + 1;
      await _persist();
    } catch (e) {
      debugPrint('Library recovery failed: $e');
    }
  }

  static String _originalPathFor(String pagePath) {
    final extension = p.extension(pagePath);
    return '${p.withoutExtension(pagePath)}.orig$extension';
  }

  int _highestId() =>
      _documents.fold<int>(0, (max, d) => d.id > max ? d.id : max);

  int _highestFolderId() =>
      _folders.fold<int>(0, (max, f) => f.id > max ? f.id : max);

  int? _validFolderId(int? folderId) {
    if (folderId == null) return null;
    return _folders.any((f) => f.id == folderId) ? folderId : null;
  }

  @override
  Future<List<Document>> getAllDocuments() async {
    await ensureLoaded();
    return List.unmodifiable([
      for (final doc in _documents)
        if (!doc.isTrashed) doc,
    ]);
  }

  @override
  Future<List<Document>> getTrashDocuments() async {
    await ensureLoaded();
    await _purgeExpiredTrash();
    return List.unmodifiable([
      for (final doc in _documents)
        if (doc.isTrashed) doc,
    ]);
  }

  @override
  Future<Document?> getDocument(int id) async {
    await ensureLoaded();
    for (final doc in _documents) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  @override
  Future<Document> createDocumentFromScans(
    List<String> sourcePaths, {
    String? title,
    bool edgesAlreadyApplied = false,
    int? folderId,
    bool isIdCard = false,
  }) async {
    if (sourcePaths.isEmpty) {
      throw ArgumentError('sourcePaths must not be empty');
    }
    await ensureLoaded();

    final now = DateTime.now();
    final id = _nextId++;
    final pages = <ScanPage>[];
    for (var i = 0; i < sourcePaths.length; i++) {
      pages.add(
        ScanPage(
          path: await _storage.importPage(
            documentId: 'doc_$id',
            index: i,
            sourcePath: sourcePaths[i],
          ),
        ),
      );
    }

    final doc = Document(
      id: id,
      title: title ?? defaultTitle(now),
      createdAt: now,
      pages: pages,
      folderId: _validFolderId(folderId),
      edgesAlreadyApplied: edgesAlreadyApplied,
      isIdCard: isIdCard,
      contentHash: await _hashFirstPage(pages),
    );
    _documents.insert(0, doc);
    await _persist();
    return doc;
  }

  /// Creates a document from pages that have already been processed.
  ///
  /// [processedBytes] is the finished image and [originalPaths] the capture it
  /// came from, so the crop screen can re-derive rather than re-edit a JPEG
  /// that has already been through the pipeline once.
  Future<Document> createProcessedDocument({
    required List<ProcessedPage> pages,
    String? title,
    int? folderId,
    bool isIdCard = false,
    bool importedFromPdf = false,
  }) async {
    if (pages.isEmpty) throw ArgumentError('pages must not be empty');
    await ensureLoaded();

    final now = DateTime.now();
    final id = _nextId++;
    final stored = <ScanPage>[];
    for (var i = 0; i < pages.length; i++) {
      stored.add(await _writeProcessedPage('doc_$id', i, pages[i]));
    }

    final doc = Document(
      id: id,
      title: title ?? defaultTitle(now),
      createdAt: now,
      pages: stored,
      folderId: _validFolderId(folderId),
      isIdCard: isIdCard,
      importedFromPdf: importedFromPdf,
      contentHash: pages.isEmpty
          ? null
          : const DocumentOrganizer().hashBytes(pages.first.bytes),
    );
    _documents.insert(0, doc);
    await _persist();
    return doc;
  }

  Future<ScanPage> _writeProcessedPage(
    String documentId,
    int index,
    ProcessedPage page,
  ) async {
    final pagePath = await _storage.importPage(
      documentId: documentId,
      index: index,
      sourcePath: page.originalPath,
    );
    // The import placed the original at the page slot; move it aside and put
    // the processed image in its place.
    final originalPath = _originalPathFor(pagePath);
    await File(pagePath).rename(originalPath);
    await _storage.writePageBytes(pagePath: pagePath, bytes: page.bytes);

    return ScanPage(
      path: pagePath,
      originalPath: originalPath,
      quad: page.quad,
      adjustments: page.adjustments,
    );
  }

  Future<ScanPage> _importPageCopy({
    required String documentId,
    required int index,
    required ScanPage page,
  }) async {
    return ScanPage(
      path: await _storage.importPage(
        documentId: documentId,
        index: index,
        sourcePath: page.path,
      ),
      originalPath: page.originalPath != null
          ? await _storage.importPage(
              documentId: documentId,
              index: 1000 + index,
              sourcePath: page.originalPath!,
            )
          : null,
      quad: page.quad,
      adjustments: page.adjustments,
      stamps: page.stamps,
    );
  }

  /// Appends already-processed pages to an existing document.
  Future<Document?> addProcessedPages(
    int documentId,
    List<ProcessedPage> pages,
  ) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return null;

    final existing = _documents[index];
    final added = <ScanPage>[];
    for (var i = 0; i < pages.length; i++) {
      added.add(
        await _writeProcessedPage(
          'doc_$documentId',
          existing.pageCount + i,
          pages[i],
        ),
      );
    }

    final updated = existing.copyWith(pages: [...existing.pages, ...added]);
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<Document?> addPages(int documentId, List<String> sourcePaths) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return null;

    final existing = _documents[index];
    final added = <ScanPage>[];
    for (var i = 0; i < sourcePaths.length; i++) {
      added.add(
        ScanPage(
          path: await _storage.importPage(
            documentId: 'doc_$documentId',
            index: existing.pageCount + i,
            sourcePath: sourcePaths[i],
          ),
        ),
      );
    }

    final updated = existing.copyWith(pages: [...existing.pages, ...added]);
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<Document?> replacePageBytes({
    required int documentId,
    required String pagePath,
    required List<int> bytes,
    Quad? quad,
    ScanAdjustments? adjustments,
  }) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return null;

    await _storage.writePageBytes(pagePath: pagePath, bytes: bytes);

    final doc = _documents[index];
    final updated = doc.copyWith(
      pages: [
        for (final page in doc.pages)
          if (page.path == pagePath)
            page.copyWith(quad: quad, adjustments: adjustments)
          else
            page,
      ],
    );
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<Document?> findDocumentByPagePath(String pagePath) async {
    await ensureLoaded();
    for (final doc in _documents) {
      if (doc.pagePaths.contains(pagePath)) return doc;
    }
    return null;
  }

  @override
  Future<void> moveToTrash(int id) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(deletedAt: DateTime.now());
    await _persist();
  }

  @override
  Future<void> restoreFromTrash(int id) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(clearDeleted: true);
    await _persist();
  }

  @override
  Future<void> emptyTrash() async {
    await ensureLoaded();
    final ids = [
      for (final doc in _documents)
        if (doc.isTrashed) doc.id,
    ];
    for (final id in ids) {
      await deleteDocument(id);
    }
  }

  Future<void> _purgeExpiredTrash() async {
    final ids = [
      for (final doc in _documents)
        if (doc.trashExpired) doc.id,
    ];
    for (final id in ids) {
      await deleteDocument(id);
    }
  }

  @override
  Future<void> setOcrText(int id, String text) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(ocrText: text);
    await _persist();
  }

  @override
  Future<Document> mergeDocuments(List<int> sourceIds) async {
    await ensureLoaded();
    final sources = [
      for (final id in sourceIds)
        for (final doc in _documents)
          if (doc.id == id && !doc.isTrashed) doc,
    ];
    if (sources.length < 2) {
      throw StateError('Pick at least two scans to merge.');
    }

    final now = DateTime.now();
    final id = _nextId++;
    final stored = <ScanPage>[];
    var index = 0;
    for (final source in sources) {
      for (final page in source.pages) {
        stored.add(
          await _importPageCopy(
            documentId: 'doc_$id',
            index: index,
            page: page,
          ),
        );
        index++;
      }
    }

    final merged = Document(
      id: id,
      title: 'Merged ${defaultTitle(now)}',
      createdAt: now,
      pages: stored,
      folderId: sources.first.folderId,
      importedFromPdf: sources.every((doc) => doc.importedFromPdf),
    );
    _documents.insert(0, merged);
    await _persist();
    return merged;
  }

  @override
  Future<Document> splitAfter({
    required int documentId,
    required int afterIndex,
  }) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) throw StateError('That scan is gone.');
    final doc = _documents[index];
    if (afterIndex < 0 || afterIndex >= doc.pageCount - 1) {
      throw StateError('Nothing to split after that page.');
    }

    final kept = doc.pages.sublist(0, afterIndex + 1);
    final rest = doc.pages.sublist(afterIndex + 1);
    _documents[index] = doc.copyWith(pages: kept);

    final now = DateTime.now();
    final id = _nextId++;
    final stored = <ScanPage>[];
    for (var i = 0; i < rest.length; i++) {
      stored.add(
        await _importPageCopy(documentId: 'doc_$id', index: i, page: rest[i]),
      );
    }
    final created = Document(
      id: id,
      title: '${doc.title} (2)',
      createdAt: now,
      pages: stored,
      folderId: doc.folderId,
      importedFromPdf: doc.importedFromPdf,
    );
    _documents.insert(0, created);
    await _persist();
    return created;
  }

  @override
  Future<List<Document>> splitAll(int documentId) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) throw StateError('That scan is gone.');
    final doc = _documents[index];
    if (doc.pageCount < 2)
      throw StateError('Need more than one page to split.');

    final created = <Document>[];
    for (var i = 0; i < doc.pageCount; i++) {
      final page = doc.pages[i];
      final id = _nextId++;
      final stored = await _importPageCopy(
        documentId: 'doc_$id',
        index: 0,
        page: page,
      );
      final piece = Document(
        id: id,
        title: '${doc.title} (${i + 1})',
        createdAt: DateTime.now(),
        pages: [stored],
        folderId: doc.folderId,
        importedFromPdf: doc.importedFromPdf,
      );
      _documents.insert(0, piece);
      created.add(piece);
    }
    await moveToTrash(documentId);
    return created;
  }

  @override
  Future<Document> copyAsIdCard(int sourceId) async {
    await ensureLoaded();
    final source = await getDocument(sourceId);
    if (source == null || source.isTrashed) {
      throw StateError('That scan is gone.');
    }

    final now = DateTime.now();
    final id = _nextId++;
    final stored = <ScanPage>[];
    for (var i = 0; i < source.pages.length; i++) {
      stored.add(
        await _importPageCopy(
          documentId: 'doc_$id',
          index: i,
          page: source.pages[i],
        ),
      );
    }
    final copy = Document(
      id: id,
      title: 'ID card',
      createdAt: now,
      pages: stored,
      isIdCard: true,
      hideFromLibrary: true,
      autoFiled: true,
      category: 'id',
      contentHash: source.contentHash,
      ocrText: source.ocrText,
    );
    _documents.insert(0, copy);
    await _persist();
    return copy;
  }

  @override
  Future<Document?> updateDocument(
    int id,
    Document Function(Document current) apply,
  ) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return null;
    final updated = apply(_documents[index]);
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<void> renameDocument(int id, String title) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(title: title);
    await _persist();
  }

  @override
  Future<void> deleteDocument(int id) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents.removeAt(index);
    // Persist the removal before touching files, so a crash mid-delete leaves
    // orphaned files rather than entries pointing at nothing.
    await _persist();
    await _storage.deleteDocumentFiles('doc_$id');
  }

  @override
  Future<List<Folder>> getFolders() async {
    await ensureLoaded();
    return List.unmodifiable(_folders);
  }

  @override
  Future<Folder> createFolder(String name) async {
    await ensureLoaded();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name is empty');
    }
    final folder = Folder(
      id: _nextFolderId++,
      name: trimmed,
      createdAt: DateTime.now(),
    );
    _folders.add(folder);
    _folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    await _persist();
    return folder;
  }

  @override
  Future<void> renameFolder(int id, String name) async {
    await ensureLoaded();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = _folders.indexWhere((f) => f.id == id);
    if (index == -1) return;
    _folders[index] = _folders[index].copyWith(name: trimmed);
    _folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    await _persist();
  }

  @override
  Future<void> deleteFolder(int id) async {
    await ensureLoaded();
    final before = _folders.length;
    _folders.removeWhere((f) => f.id == id);
    if (_folders.length == before) return;
    for (var i = 0; i < _documents.length; i++) {
      if (_documents[i].folderId == id) {
        _documents[i] = _documents[i].copyWith(clearFolder: true);
      }
    }
    await _persist();
  }

  @override
  Future<void> moveDocuments({
    required Iterable<int> documentIds,
    int? folderId,
  }) async {
    await ensureLoaded();
    if (folderId != null && !_folders.any((f) => f.id == folderId)) {
      throw StateError('That folder is no longer here.');
    }
    var changed = false;
    for (final id in documentIds) {
      final index = _documents.indexWhere((d) => d.id == id);
      if (index == -1) continue;
      final doc = _documents[index];
      if (doc.folderId == folderId) continue;
      _documents[index] = folderId == null
          ? doc.copyWith(clearFolder: true)
          : doc.copyWith(folderId: folderId);
      changed = true;
    }
    if (changed) await _persist();
  }

  @override
  Future<void> deletePage({
    required int documentId,
    required String pagePath,
  }) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return;

    final doc = _documents[index];
    final removed = doc.pageAt(pagePath);
    final remaining = doc.pages.where((page) => page.path != pagePath).toList();
    if (remaining.isEmpty) {
      await moveToTrash(documentId);
      return;
    }

    _documents[index] = doc.copyWith(pages: remaining);
    await _persist();
    for (final path in [pagePath, removed?.originalPath]) {
      if (path == null) continue;
      try {
        await File(path).delete();
      } catch (_) {
        // Already gone; the manifest is the source of truth.
      }
    }
  }

  /// Reorders pages within a document.
  @override
  Future<Document?> reorderPages(
    int documentId,
    int oldIndex,
    int newIndex,
  ) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return null;

    final doc = _documents[index];
    if (oldIndex < 0 || oldIndex >= doc.pageCount) return doc;
    final pages = [...doc.pages];
    final page = pages.removeAt(oldIndex);
    pages.insert(newIndex.clamp(0, pages.length), page);

    final updated = doc.copyWith(pages: pages);
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<Document?> rotatePageClockwise({
    required int documentId,
    required String pagePath,
  }) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return null;

    final doc = _documents[index];
    final pageIndex = doc.pages.indexWhere((page) => page.path == pagePath);
    if (pageIndex == -1) return doc;

    final page = doc.pages[pageIndex];
    final file = File(page.path);
    if (await file.exists()) {
      final rotated = _editor.rotateClockwise(await file.readAsBytes());
      if (rotated != null) {
        await _storage.writePageBytes(pagePath: page.path, bytes: rotated);
      }
    }

    // When the original capture is still around, crop re-derives from it and
    // needs the extra turn recorded. Imports have no original — the JPEG we
    // just rotated *is* the source, so bumping rotationTurns would spin it
    // twice the next time crop opens.
    final nextTurns = page.originalPath == null
        ? page.adjustments.rotationTurns
        : (page.adjustments.rotationTurns + 1) % 4;

    final rotatedPage = page.copyWith(
      quad: page.quad?.rotatedClockwise(),
      adjustments: page.adjustments.copyWith(rotationTurns: nextTurns),
      stamps: [for (final stamp in page.stamps) stamp.rotatedClockwise()],
    );
    final pages = [...doc.pages];
    pages[pageIndex] = rotatedPage;
    final updated = doc.copyWith(pages: pages);
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<Document?> setPageStamps({
    required int documentId,
    required String pagePath,
    required List<PageStamp> stamps,
  }) async {
    await ensureLoaded();
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return null;

    final doc = _documents[index];
    final pages = <ScanPage>[];
    for (final page in doc.pages) {
      if (page.path != pagePath) {
        pages.add(page);
        continue;
      }
      pages.add(await _bakeStamps(page, stamps));
    }
    final updated = doc.copyWith(pages: pages);
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  /// Writes the signature into the page JPEG so the library, Photos, and the
  /// saved PDF all show ink.
  ///
  /// Stamps are cleared only when the baked file actually darkened. A no-op
  /// bake (HEIC the image package cannot read, missing overlay) used to wipe
  /// the metadata and leave an unsigned export.
  Future<ScanPage> _bakeStamps(ScanPage page, List<PageStamp> stamps) async {
    if (stamps.isEmpty) return page.copyWith(stamps: const []);
    final file = File(page.path);
    if (!file.existsSync()) return page.copyWith(stamps: stamps);

    final localized = await _localizeStamps(page, stamps);
    final original = file.readAsBytesSync();
    final baked = await const StampCompositor().paint(original, localized);
    final landed = localized.any(
      (stamp) => stampInkLanded(original: original, baked: baked, stamp: stamp),
    );
    if (!landed) return page.copyWith(stamps: localized);

    var outPath = page.path;
    final ext = p.extension(outPath).toLowerCase();
    if (ext != '.jpg' && ext != '.jpeg') {
      outPath = p.setExtension(outPath, '.jpg');
    }
    await _storage.writePageBytes(pagePath: outPath, bytes: baked);
    try {
      imageCache.evict(FileImage(File(page.path)));
      if (outPath != page.path) {
        imageCache.evict(FileImage(File(outPath)));
      }
    } catch (_) {}
    return page.copyWith(path: outPath, stamps: const []);
  }

  /// Keep stamp PNGs next to the page so an iOS container change cannot
  /// leave export pointing at a signatures/ path that no longer exists.
  Future<List<PageStamp>> _localizeStamps(
    ScanPage page,
    List<PageStamp> stamps,
  ) async {
    final dir = File(page.path).parent;
    final out = <PageStamp>[];
    for (var i = 0; i < stamps.length; i++) {
      final stamp = stamps[i];
      final src = File(stamp.imagePath);
      if (!src.existsSync()) {
        out.add(stamp);
        continue;
      }
      final dest = File(
        p.join(dir.path, 'stamp_${i}_${p.basename(stamp.imagePath)}'),
      );
      if (p.normalize(src.absolute.path) != p.normalize(dest.absolute.path)) {
        try {
          await src.copy(dest.path);
        } catch (_) {
          out.add(stamp);
          continue;
        }
      }
      out.add(stamp.copyWith(imagePath: dest.path));
    }
    return out;
  }

  Future<void> _persist() {
    // Chained rather than concurrent: a batch scan finishes several saves
    // within a frame, and interleaved writes corrupt the manifest.
    _writeChain = _writeChain.then((_) => _writeManifest());
    return _writeChain;
  }

  Future<void> _writeManifest() async {
    try {
      final root = await _storage.rootPath();
      String rel(String path) => p.relative(path, from: root);

      final payload = <String, dynamic>{
        'version': _manifestVersion,
        'nextId': _nextId,
        'nextFolderId': _nextFolderId,
        'folders': [
          for (final folder in _folders)
            {
              'id': folder.id,
              'name': folder.name,
              'createdAt': folder.createdAt.toIso8601String(),
            },
        ],
        'documents': [
          for (final doc in _documents)
            {
              'id': doc.id,
              'title': doc.title,
              'createdAt': doc.createdAt.toIso8601String(),
              if (doc.folderId != null) 'folderId': doc.folderId,
              'edgesAlreadyApplied': doc.edgesAlreadyApplied,
              if (doc.deletedAt != null)
                'deletedAt': doc.deletedAt!.toIso8601String(),
              if (doc.ocrText != null && doc.ocrText!.isNotEmpty)
                'ocrText': doc.ocrText,
              if (doc.isIdCard) 'isIdCard': true,
              if (doc.importedFromPdf) 'importedFromPdf': true,
              if (doc.tags.isNotEmpty) 'tags': doc.tags,
              if (doc.isFavorite) 'isFavorite': true,
              if (doc.isPrivate) 'isPrivate': true,
              if (doc.category != null) 'category': doc.category,
              if (doc.contentHash != null) 'contentHash': doc.contentHash,
              if (doc.ocrBlocks.isNotEmpty)
                'ocrBlocks': [
                  for (final block in doc.ocrBlocks) block.toJson(),
                ],
              if (doc.ocrLanguage != null) 'ocrLanguage': doc.ocrLanguage,
              if (doc.autoFiled) 'autoFiled': true,
              if (doc.hideFromLibrary) 'hideFromLibrary': true,
              'pages': [
                for (final page in doc.pages)
                  {
                    'path': rel(page.path),
                    if (page.originalPath != null)
                      'original': rel(page.originalPath!),
                    if (page.quad != null) 'quad': _quadToJson(page.quad!),
                    'adjustments': {
                      'filter': page.adjustments.filter.index,
                      'brightness': page.adjustments.brightness,
                      'contrast': page.adjustments.contrast,
                      'rotationTurns': page.adjustments.rotationTurns,
                    },
                    if (page.stamps.isNotEmpty)
                      'stamps': [
                        for (final stamp in page.stamps) stamp.toJson(rel),
                      ],
                  },
              ],
            },
        ],
      };

      // Write to a sibling then rename: a half-written manifest would cost the
      // user their whole library.
      final target = File(p.join(root, _manifestName));
      final temp = File('${target.path}.tmp');
      await temp.writeAsString(jsonEncode(payload), flush: true);
      await temp.rename(target.path);
    } catch (e) {
      debugPrint('Failed to save library manifest: $e');
    }
  }

  static String defaultTitle(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Scan ${two(now.month)}/${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}';
  }

  Future<void> close() async {
    await _writeChain;
  }
}

/// A captured page that has already been cropped and enhanced, along with the
/// settings used, so the edit can be reopened later.
@immutable
class ProcessedPage {
  const ProcessedPage({
    required this.originalPath,
    required this.bytes,
    this.quad,
    this.adjustments = const ScanAdjustments(),
  });

  final String originalPath;
  final Uint8List bytes;
  final Quad? quad;
  final ScanAdjustments adjustments;
}
