import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/features/camera/domain/quad_detector.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';
import 'package:scan2/features/library/data/document_store.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/document_repository.dart';
import 'package:scan2/features/library/domain/folder.dart';
import 'package:scan2/features/library/domain/page_stamp.dart';
import 'package:scan2/features/library/domain/smart_folder.dart';

/// In-memory library used for the browser demo, where there is no file system
/// to persist to and no camera to scan with.
class WebDemoRepository implements DocumentRepository {
  WebDemoRepository({bool seedSampleData = false}) {
    if (seedSampleData) _seed();
  }

  final List<Document> _documents = [];
  final List<Folder> _folders = [];
  int _nextId = 1;
  int _nextFolderId = 1;

  /// Sample documents for the browser demo, where there is no camera to
  /// produce any. Page thumbnails fall back to the drawn stand-in.
  void _seed() {
    const titles = [
      'Rental agreement',
      'Passport',
      'Invoice 2043',
      'Hotel receipt',
      'Insurance policy',
      'Bank statement',
    ];
    const pageCounts = [4, 1, 2, 1, 9, 3];
    final now = DateTime.now();

    for (var i = 0; i < titles.length; i++) {
      _documents.add(
        Document(
          id: _nextId++,
          title: titles[i],
          createdAt: now.subtract(Duration(days: i * 3, hours: i * 5)),
          pages: [
            for (var p = 0; p < pageCounts[i]; p++)
              ScanPage(path: 'demo_${i}_$p'),
          ],
        ),
      );
    }
    _documents.insert(
      0,
      Document(
        id: _nextId++,
        title: 'Offer letter.pdf',
        createdAt: now,
        pages: [ScanPage(path: 'demo_pdf_0')],
        importedFromPdf: true,
      ),
    );
  }

  @override
  Future<List<Document>> getAllDocuments() async => List.unmodifiable([
    for (final doc in _documents)
      if (!doc.isTrashed) doc,
  ]);

  @override
  Future<Document?> getDocument(int id) async {
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
    final doc = Document(
      id: _nextId++,
      title: title ?? 'Demo scan',
      createdAt: DateTime.now(),
      pages: List.generate(
        sourcePaths.isEmpty ? 1 : sourcePaths.length,
        (i) => ScanPage(path: 'demo_page_$i'),
      ),
      folderId: folderId,
      edgesAlreadyApplied: edgesAlreadyApplied,
      isIdCard: isIdCard,
    );
    _documents.insert(0, doc);
    return doc;
  }

  @override
  Future<Document?> addPages(int documentId, List<String> sourcePaths) async {
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return null;
    final doc = _documents[index];
    final updated = doc.copyWith(
      pages: [
        ...doc.pages,
        for (var i = 0; i < sourcePaths.length; i++)
          ScanPage(path: 'demo_page_${doc.pageCount + i}'),
      ],
    );
    _documents[index] = updated;
    return updated;
  }

  @override
  Future<Document?> replacePageBytes({
    required int documentId,
    required String pagePath,
    required List<int> bytes,
    Quad? quad,
    ScanAdjustments? adjustments,
  }) async => getDocument(documentId);

  @override
  Future<Document?> findDocumentByPagePath(String pagePath) async {
    for (final doc in _documents) {
      if (doc.pagePaths.contains(pagePath)) return doc;
    }
    return null;
  }

  @override
  Future<Document?> updateDocument(
    int id,
    Document Function(Document current) apply,
  ) async {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return null;
    final updated = apply(_documents[index]);
    _documents[index] = updated;
    return updated;
  }

  @override
  Future<void> renameDocument(int id, String title) async {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index != -1) {
      _documents[index] = _documents[index].copyWith(title: title);
    }
  }

  @override
  Future<void> moveToTrash(int id) async {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index != -1) {
      _documents[index] = _documents[index].copyWith(deletedAt: DateTime.now());
    }
  }

  @override
  Future<void> restoreFromTrash(int id) async {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index != -1) {
      _documents[index] = _documents[index].copyWith(clearDeleted: true);
    }
  }

  @override
  Future<void> emptyTrash() async {
    _documents.removeWhere((d) => d.isTrashed);
  }

  @override
  Future<List<Document>> getTrashDocuments() async => List.unmodifiable([
    for (final doc in _documents)
      if (doc.isTrashed) doc,
  ]);

  @override
  Future<void> deleteDocument(int id) async {
    _documents.removeWhere((d) => d.id == id);
  }

  @override
  Future<void> setOcrText(int id, String text) async {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index != -1) {
      _documents[index] = _documents[index].copyWith(ocrText: text);
    }
  }

  @override
  Future<Document?> reorderPages(
    int documentId,
    int oldIndex,
    int newIndex,
  ) async {
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return null;
    final doc = _documents[index];
    if (oldIndex < 0 || oldIndex >= doc.pageCount) return doc;
    final pages = [...doc.pages];
    final page = pages.removeAt(oldIndex);
    pages.insert(newIndex.clamp(0, pages.length), page);
    final updated = doc.copyWith(pages: pages);
    _documents[index] = updated;
    return updated;
  }

  @override
  Future<Document?> rotatePageClockwise({
    required int documentId,
    required String pagePath,
  }) async {
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return null;
    final doc = _documents[index];
    final pages = [
      for (final page in doc.pages)
        if (page.path == pagePath)
          page.copyWith(
            quad: page.quad?.rotatedClockwise(),
            adjustments: page.adjustments.copyWith(
              rotationTurns: (page.adjustments.rotationTurns + 1) % 4,
            ),
            stamps: [for (final stamp in page.stamps) stamp.rotatedClockwise()],
          )
        else
          page,
    ];
    final updated = doc.copyWith(pages: pages);
    _documents[index] = updated;
    return updated;
  }

  @override
  Future<Document?> setPageStamps({
    required int documentId,
    required String pagePath,
    required List<PageStamp> stamps,
  }) async {
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return null;
    final doc = _documents[index];
    final updated = doc.copyWith(
      pages: [
        for (final page in doc.pages)
          if (page.path == pagePath) page.copyWith(stamps: stamps) else page,
      ],
    );
    _documents[index] = updated;
    return updated;
  }

  @override
  Future<Document> mergeDocuments(List<int> sourceIds) async {
    final sources = [
      for (final id in sourceIds)
        for (final doc in _documents)
          if (doc.id == id && !doc.isTrashed) doc,
    ];
    if (sources.length < 2) {
      throw StateError('Pick at least two scans to merge.');
    }
    final pages = [for (final doc in sources) ...doc.pages];
    final merged = Document(
      id: _nextId++,
      title: 'Merged scan',
      createdAt: DateTime.now(),
      pages: pages,
    );
    _documents.insert(0, merged);
    return merged;
  }

  @override
  Future<Document> copyAsIdCard(int sourceId) async {
    final index = _documents.indexWhere((d) => d.id == sourceId);
    if (index == -1) throw StateError('That scan is gone.');
    final source = _documents[index];
    if (source.isTrashed) throw StateError('That scan is gone.');
    final copy = Document(
      id: _nextId++,
      title: 'ID card',
      createdAt: DateTime.now(),
      pages: source.pages,
      isIdCard: true,
      hideFromLibrary: true,
      autoFiled: true,
      category: 'id',
      contentHash: source.contentHash,
      ocrText: source.ocrText,
    );
    _documents.insert(0, copy);
    return copy;
  }

  @override
  Future<Document> splitAfter({
    required int documentId,
    required int afterIndex,
  }) async {
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) throw StateError('That scan is gone.');
    final doc = _documents[index];
    if (afterIndex < 0 || afterIndex >= doc.pageCount - 1) {
      throw StateError('Nothing to split after that page.');
    }
    final kept = doc.pages.sublist(0, afterIndex + 1);
    final rest = doc.pages.sublist(afterIndex + 1);
    _documents[index] = doc.copyWith(pages: kept);
    final created = Document(
      id: _nextId++,
      title: '${doc.title} (2)',
      createdAt: DateTime.now(),
      pages: rest,
      folderId: doc.folderId,
    );
    _documents.insert(0, created);
    return created;
  }

  @override
  Future<List<Document>> splitAll(int documentId) async {
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) throw StateError('That scan is gone.');
    final doc = _documents[index];
    if (doc.pageCount < 2)
      throw StateError('Need more than one page to split.');
    final created = <Document>[];
    for (var i = 0; i < doc.pageCount; i++) {
      final piece = Document(
        id: _nextId++,
        title: '${doc.title} (${i + 1})',
        createdAt: DateTime.now(),
        pages: [doc.pages[i]],
        folderId: doc.folderId,
      );
      _documents.insert(0, piece);
      created.add(piece);
    }
    await moveToTrash(documentId);
    return created;
  }

  @override
  Future<void> deletePage({
    required int documentId,
    required String pagePath,
  }) async {
    final index = _documents.indexWhere((d) => d.id == documentId);
    if (index == -1) return;
    final doc = _documents[index];
    final remaining = doc.pages.where((page) => page.path != pagePath).toList();
    if (remaining.isEmpty) {
      await moveToTrash(documentId);
    } else {
      _documents[index] = doc.copyWith(pages: remaining);
    }
  }

  @override
  Future<List<Folder>> getFolders() async => List.unmodifiable(_folders);

  @override
  Future<Folder> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Folder name is empty');
    final folder = Folder(
      id: _nextFolderId++,
      name: trimmed,
      createdAt: DateTime.now(),
    );
    _folders.add(folder);
    return folder;
  }

  @override
  Future<void> renameFolder(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = _folders.indexWhere((f) => f.id == id);
    if (index != -1) {
      _folders[index] = _folders[index].copyWith(name: trimmed);
    }
  }

  @override
  Future<void> deleteFolder(int id) async {
    _folders.removeWhere((f) => f.id == id);
    for (var i = 0; i < _documents.length; i++) {
      if (_documents[i].folderId == id) {
        _documents[i] = _documents[i].copyWith(clearFolder: true);
      }
    }
  }

  @override
  Future<void> moveDocuments({
    required Iterable<int> documentIds,
    int? folderId,
  }) async {
    if (folderId != null && !_folders.any((f) => f.id == folderId)) {
      throw StateError('That folder is no longer here.');
    }
    for (final id in documentIds) {
      final index = _documents.indexWhere((d) => d.id == id);
      if (index == -1) continue;
      _documents[index] = folderId == null
          ? _documents[index].copyWith(clearFolder: true)
          : _documents[index].copyWith(folderId: folderId);
    }
  }
}

/// Bumps whenever the library changes, so screens watching it rebuild.
final libraryRevisionProvider = StateProvider<int>((ref) => 0);

void bumpLibrary(WidgetRef ref) {
  ref.read(libraryRevisionProvider.notifier).state++;
}

/// The app's document library.
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  if (kIsWeb) return WebDemoRepository(seedSampleData: true);
  final store = DocumentStore();
  ref.onDispose(store.close);
  return store;
});

/// The library contents.
///
/// Held in a provider rather than created inline in a `FutureBuilder`: a
/// future built during `build` is a *new* future on every rebuild, which resets
/// the builder to its loading state. Typing in the library's search field
/// would flash a spinner over the results on every keystroke.
final documentsProvider = FutureProvider<List<Document>>((ref) {
  ref.watch(libraryRevisionProvider);
  return ref.watch(documentRepositoryProvider).getAllDocuments();
});

final trashProvider = FutureProvider<List<Document>>((ref) {
  ref.watch(libraryRevisionProvider);
  return ref.watch(documentRepositoryProvider).getTrashDocuments();
});

final foldersProvider = FutureProvider<List<Folder>>((ref) {
  ref.watch(libraryRevisionProvider);
  return ref.watch(documentRepositoryProvider).getFolders();
});

/// Folder currently open on Documents. Null means the home list.
///
/// Held here rather than only in the screen: the docked scan button lives in
/// the shell, and a new capture has to know which folder was open.
final openFolderIdProvider = StateProvider<int?>((ref) => null);

/// Pro smart folder open from the drawer. Null means the home list.
///
/// Held here so the side menu can set it and Documents can filter.
final smartFolderProvider = StateProvider<SmartFolder?>((ref) => null);

/// A single document by id.
final documentProvider = FutureProvider.family<Document?, int>((ref, id) {
  ref.watch(libraryRevisionProvider);
  return ref.watch(documentRepositoryProvider).getDocument(id);
});
