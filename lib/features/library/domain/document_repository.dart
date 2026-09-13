import 'package:scan2/features/camera/domain/quad_detector.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/folder.dart';
import 'package:scan2/features/library/domain/page_stamp.dart';

/// Everything the UI needs from the document library.
///
/// The library screens used to hold the store as `dynamic` and cast at each
/// call site, which meant a renamed method failed at runtime instead of at
/// compile time. One interface, two implementations: on-disk on mobile, and
/// in-memory for the browser demo where there is no file system.
abstract class DocumentRepository {
  Future<List<Document>> getAllDocuments();

  Future<Document?> getDocument(int id);

  /// Imports scanner output as a new document.
  Future<Document> createDocumentFromScans(
    List<String> sourcePaths, {
    String? title,
    bool edgesAlreadyApplied = false,
    int? folderId,
    bool isIdCard = false,
  });

  /// Appends pages to an existing document.
  Future<Document?> addPages(int documentId, List<String> sourcePaths);

  /// Overwrites one page's image, e.g. after crop and enhance.
  Future<Document?> replacePageBytes({
    required int documentId,
    required String pagePath,
    required List<int> bytes,
    Quad? quad,
    ScanAdjustments? adjustments,
  });

  Future<Document?> findDocumentByPagePath(String pagePath);

  Future<void> renameDocument(int id, String title);

  /// Applies a local edit (favorite, tags, private, category, hash, OCR).
  Future<Document?> updateDocument(
    int id,
    Document Function(Document current) apply,
  );

  /// Hides the scan in Trash for 30 days.
  Future<void> moveToTrash(int id);

  Future<void> restoreFromTrash(int id);

  /// Deletes files for good. Used by Empty Trash and expired items.
  Future<void> deleteDocument(int id);

  Future<void> emptyTrash();

  Future<List<Document>> getTrashDocuments();

  Future<void> deletePage({required int documentId, required String pagePath});

  Future<void> setOcrText(int id, String text);

  /// Moves one page inside the same scan.
  Future<Document?> reorderPages(int documentId, int oldIndex, int newIndex);

  /// Turns a page 90° clockwise. Updates the finished JPEG when one exists.
  Future<Document?> rotatePageClockwise({
    required int documentId,
    required String pagePath,
  });

  /// Replaces the signatures on one page.
  Future<Document?> setPageStamps({
    required int documentId,
    required String pagePath,
    required List<PageStamp> stamps,
  });

  /// Copies every page from [sourceIds] into a new scan.
  Future<Document> mergeDocuments(List<int> sourceIds);

  /// Second library entry for the IDs drawer: same pages, marked as an ID card.
  Future<Document> copyAsIdCard(int sourceId);

  /// Pages after [afterIndex] become a new scan. The original keeps the rest.
  Future<Document> splitAfter({
    required int documentId,
    required int afterIndex,
  });

  /// Each page becomes its own scan. The original goes to Trash.
  Future<List<Document>> splitAll(int documentId);

  Future<List<Folder>> getFolders();

  Future<Folder> createFolder(String name);

  Future<void> renameFolder(int id, String name);

  /// Removes the folder. Scans inside it stay in the library, unfiled.
  Future<void> deleteFolder(int id);

  /// Moves scans into [folderId], or back to the home list when it is null.
  Future<void> moveDocuments({
    required Iterable<int> documentIds,
    int? folderId,
  });
}
