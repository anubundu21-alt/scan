import 'package:flutter/foundation.dart';
import 'package:scan2/features/camera/domain/quad_detector.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';
import 'package:scan2/features/library/domain/ocr_layout.dart';
import 'package:scan2/features/library/domain/page_stamp.dart';

/// One page of a document.
///
/// [path] is the finished image — cropped, enhanced, and what the library,
/// PDF export and sharing all use. [originalPath] is the untouched capture it
/// was derived from.
///
/// Keeping both is what makes editing non-destructive. Re-cropping an already
/// cropped and sharpened JPEG compounds the losses of every previous pass and
/// cannot widen a crop that was taken too tight; re-deriving from the original
/// each time always produces the same quality, and lets the crop screen
/// reopen with the exact edges and filter that were last applied.
@immutable
class ScanPage {
  const ScanPage({
    required this.path,
    this.originalPath,
    this.quad,
    this.adjustments = const ScanAdjustments(),
    this.stamps = const [],
  });

  final String path;
  final String? originalPath;

  /// Crop applied to [originalPath], in normalized coordinates. Null when the
  /// page was never cropped (an import, or a native scan already cropped by
  /// VisionKit).
  final Quad? quad;

  final ScanAdjustments adjustments;

  /// Signatures placed on this page. Composited at export, not in the JPEG.
  final List<PageStamp> stamps;

  bool get hasSignature => stamps.isNotEmpty;

  /// The image edits should be re-derived from.
  String get editSource => originalPath ?? path;

  /// Whether the original is still available to re-edit from.
  bool get canReedit => originalPath != null;

  ScanPage copyWith({
    String? path,
    String? originalPath,
    Quad? quad,
    ScanAdjustments? adjustments,
    List<PageStamp>? stamps,
  }) {
    return ScanPage(
      path: path ?? this.path,
      originalPath: originalPath ?? this.originalPath,
      quad: quad ?? this.quad,
      adjustments: adjustments ?? this.adjustments,
      stamps: stamps ?? this.stamps,
    );
  }
}

@immutable
class Document {
  const Document({
    required this.id,
    required this.title,
    required this.createdAt,
    this.pages = const [],
    this.folderId,
    this.edgesAlreadyApplied = false,
    this.deletedAt,
    this.ocrText,
    this.isIdCard = false,
    this.importedFromPdf = false,
    this.tags = const [],
    this.isFavorite = false,
    this.isPrivate = false,
    this.category,
    this.contentHash,
    this.ocrBlocks = const [],
    this.ocrLanguage,
    this.autoFiled = false,
    this.hideFromLibrary = false,
  });

  static const trashRetention = Duration(days: 30);

  final int id;
  final String title;
  final DateTime createdAt;
  final List<ScanPage> pages;
  final int? folderId;

  /// True when pages came from the native auto-edge scanner and are already
  /// perspective-cropped.
  final bool edgesAlreadyApplied;

  /// When set, the scan is in Trash rather than the library.
  final DateTime? deletedAt;

  /// Concatenated text from on-device OCR, used by home search.
  final String? ocrText;

  /// Front + back of a card, kept as one two-page scan.
  final bool isIdCard;

  /// Came from Files as a PDF, not the camera or Photos.
  ///
  /// Sign PDF lists these. Camera scans stay out of that list.
  final bool importedFromPdf;

  /// User-applied labels. Used by smart folders and search.
  final List<String> tags;

  final bool isFavorite;

  /// Hidden from the main library until the Private smart folder is opened.
  final bool isPrivate;

  /// Auto or manual category: receipt, invoice, id, contract, statement…
  final String? category;

  /// SHA-256 of the first page, for duplicate detection.
  final String? contentHash;

  /// Word boxes from OCR, used to keep a searchable PDF's layout.
  final List<OcrBlock> ocrBlocks;

  /// Language last used for OCR on this document.
  final String? ocrLanguage;

  /// True after Pro auto-file has already classified this scan.
  final bool autoFiled;

  /// Hidden from All documents; still listed in the IDs smart folder.
  final bool hideFromLibrary;

  /// Shown under Sign PDF: an uploaded file, or an older upload that was
  /// rasterised as-is (original filter, kept source). Not a camera scan.
  bool get isPdfForSigning {
    if (importedFromPdf) return true;
    if (isIdCard || edgesAlreadyApplied || pages.isEmpty) return false;
    return pages.every(
      (page) =>
          page.originalPath != null &&
          page.adjustments.filter == ScanFilter.original,
    );
  }

  bool get isTrashed => deletedAt != null;

  bool get trashExpired {
    final deleted = deletedAt;
    if (deleted == null) return false;
    return DateTime.now().difference(deleted) >= trashRetention;
  }

  int get pageCount => pages.length;

  List<String> get pagePaths => [for (final page in pages) page.path];

  ScanPage? pageAt(String path) {
    for (final page in pages) {
      if (page.path == path) return page;
    }
    return null;
  }

  Document copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    List<ScanPage>? pages,
    int? folderId,
    bool clearFolder = false,
    bool? edgesAlreadyApplied,
    DateTime? deletedAt,
    bool clearDeleted = false,
    String? ocrText,
    bool clearOcr = false,
    bool? isIdCard,
    bool? importedFromPdf,
    List<String>? tags,
    bool? isFavorite,
    bool? isPrivate,
    String? category,
    bool clearCategory = false,
    String? contentHash,
    bool clearHash = false,
    List<OcrBlock>? ocrBlocks,
    String? ocrLanguage,
    bool clearOcrLanguage = false,
    bool? autoFiled,
    bool? hideFromLibrary,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      pages: pages ?? this.pages,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      edgesAlreadyApplied: edgesAlreadyApplied ?? this.edgesAlreadyApplied,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
      ocrText: clearOcr ? null : (ocrText ?? this.ocrText),
      isIdCard: isIdCard ?? this.isIdCard,
      importedFromPdf: importedFromPdf ?? this.importedFromPdf,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      isPrivate: isPrivate ?? this.isPrivate,
      category: clearCategory ? null : (category ?? this.category),
      contentHash: clearHash ? null : (contentHash ?? this.contentHash),
      ocrBlocks: ocrBlocks ?? this.ocrBlocks,
      ocrLanguage: clearOcrLanguage ? null : (ocrLanguage ?? this.ocrLanguage),
      autoFiled: autoFiled ?? this.autoFiled,
      hideFromLibrary: hideFromLibrary ?? this.hideFromLibrary,
    );
  }
}
