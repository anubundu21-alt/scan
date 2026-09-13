import 'package:pdf/pdf.dart';

/// How a scan is fitted onto a PDF page.
enum PdfPageSize {
  fit,
  a4,
  letter;

  String get label => switch (this) {
    PdfPageSize.fit => 'Match the scan',
    PdfPageSize.a4 => 'A4',
    PdfPageSize.letter => 'Letter',
  };

  String get shortLabel => switch (this) {
    PdfPageSize.fit => 'Fit',
    PdfPageSize.a4 => 'A4',
    PdfPageSize.letter => 'Letter',
  };

  PdfPageFormat get format => switch (this) {
    PdfPageSize.fit => PdfPageFormat.a4, // placeholder; fit uses image aspect
    PdfPageSize.a4 => PdfPageFormat.a4,
    PdfPageSize.letter => PdfPageFormat.letter,
  };
}

/// How large the embedded page images are.
enum PdfQuality {
  good,
  small;

  String get label => switch (this) {
    PdfQuality.good => 'Good',
    PdfQuality.small => 'Smaller file',
  };

  int get maxEdge => this == PdfQuality.good ? 2400 : 1400;

  int get jpegQuality => this == PdfQuality.good ? 88 : 72;
}

class PdfExportOptions {
  const PdfExportOptions({
    this.pageSize = PdfPageSize.fit,
    this.quality = PdfQuality.good,
    this.password,
    this.pageIndexes,
    this.searchable = false,
  });

  final PdfPageSize pageSize;
  final PdfQuality quality;
  final String? password;

  /// Null means every page. Used by "export selected pages".
  final List<int>? pageIndexes;

  /// Invisible OCR text so the PDF can be searched and copied.
  final bool searchable;

  PdfExportOptions copyWith({
    PdfPageSize? pageSize,
    PdfQuality? quality,
    String? password,
    bool clearPassword = false,
    List<int>? pageIndexes,
    bool clearPages = false,
    bool? searchable,
  }) {
    return PdfExportOptions(
      pageSize: pageSize ?? this.pageSize,
      quality: quality ?? this.quality,
      password: clearPassword ? null : (password ?? this.password),
      pageIndexes: clearPages ? null : (pageIndexes ?? this.pageIndexes),
      searchable: searchable ?? this.searchable,
    );
  }
}
