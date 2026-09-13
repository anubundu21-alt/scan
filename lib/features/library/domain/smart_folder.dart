import 'package:flutter/material.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/document_organizer.dart';

/// Virtual folders built from document metadata, not a user-named group.
enum SmartFolder {
  favorites,
  private,
  recent,
  receipts,
  invoices,
  ids,
  untagged,
  duplicates;

  /// Folders that earn a drawer row. Receipts, invoices, untagged and
  /// duplicates are unused or overlap All documents / IDs.
  static const inDrawer = [favorites, private, ids];

  String get label => switch (this) {
    SmartFolder.favorites => 'Favorites',
    SmartFolder.private => 'Private',
    SmartFolder.recent => 'Recent',
    SmartFolder.receipts => 'Receipts',
    SmartFolder.invoices => 'Invoices',
    SmartFolder.ids => 'IDs',
    SmartFolder.untagged => 'Untagged',
    SmartFolder.duplicates => 'Duplicates',
  };

  String get drawerSubtitle => switch (this) {
    SmartFolder.favorites => 'Starred scans',
    SmartFolder.private => 'Hidden, Face ID to open',
    SmartFolder.recent => 'Last 7 days',
    SmartFolder.receipts => 'Auto category',
    SmartFolder.invoices => 'Auto category',
    SmartFolder.ids => 'Cards and IDs',
    SmartFolder.untagged => 'No tags yet',
    SmartFolder.duplicates => 'Same first page',
  };

  IconData get icon => switch (this) {
    SmartFolder.favorites => Icons.star_rounded,
    SmartFolder.private => Icons.lock_rounded,
    SmartFolder.recent => Icons.schedule_rounded,
    SmartFolder.receipts => Icons.receipt_long_rounded,
    SmartFolder.invoices => Icons.request_quote_rounded,
    SmartFolder.ids => Icons.badge_rounded,
    SmartFolder.untagged => Icons.label_off_rounded,
    SmartFolder.duplicates => Icons.copy_all_rounded,
  };

  List<Document> filter(List<Document> documents) {
    switch (this) {
      case SmartFolder.favorites:
        return [
          for (final doc in documents)
            if (doc.isFavorite) doc,
        ];
      case SmartFolder.private:
        return [
          for (final doc in documents)
            if (doc.isPrivate) doc,
        ];
      case SmartFolder.recent:
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        return [
          for (final doc in documents)
            if (doc.createdAt.isAfter(cutoff)) doc,
        ];
      case SmartFolder.receipts:
        return [
          for (final doc in documents)
            if (doc.category == 'receipt') doc,
        ];
      case SmartFolder.invoices:
        return [
          for (final doc in documents)
            if (doc.category == 'invoice') doc,
        ];
      case SmartFolder.ids:
        return [
          for (final doc in documents)
            if (doc.category == 'id' || doc.isIdCard) doc,
        ];
      case SmartFolder.untagged:
        return [
          for (final doc in documents)
            if (doc.tags.isEmpty) doc,
        ];
      case SmartFolder.duplicates:
        return const DocumentOrganizer().duplicatesAmong(documents);
    }
  }
}
