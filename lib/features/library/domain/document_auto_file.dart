import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/document_organizer.dart';
import 'package:scan2/features/library/domain/document_repository.dart';

/// Result of filing a scan into Private or IDs from on-device OCR.
class AutoFileOutcome {
  const AutoFileOutcome({
    required this.kind,
    this.idCopy,
    this.message,
  });

  final IdentityKind kind;
  final Document? idCopy;
  final String? message;
}

/// Files passports into Private and ID cards into the IDs drawer.
class DocumentAutoFile {
  const DocumentAutoFile();

  static const _organizer = DocumentOrganizer();

  Future<AutoFileOutcome> apply({
    required DocumentRepository repository,
    required Document document,
    required String text,
    required bool isPro,
  }) async {
    if (!isPro || document.autoFiled || document.importedFromPdf) {
      return const AutoFileOutcome(kind: IdentityKind.none);
    }

    final kind = _organizer.detectIdentity(text);
    if (kind == IdentityKind.none && text.trim().isEmpty) {
      return const AutoFileOutcome(kind: IdentityKind.none);
    }

    await repository.updateDocument(document.id, (current) {
      var next = current.copyWith(
        autoFiled: true,
        ocrText: (current.ocrText == null || current.ocrText!.isEmpty)
            ? text
            : current.ocrText,
        category: current.category ?? _organizer.categorize(text),
      );
      if (kind == IdentityKind.passport) {
        next = next.copyWith(isPrivate: true, category: 'id');
        if (DocumentOrganizer.isGenericTitle(next.title)) {
          next = next.copyWith(title: 'Passport');
        }
      } else if (kind == IdentityKind.idCard) {
        if (DocumentOrganizer.isGenericTitle(next.title)) {
          next = next.copyWith(title: 'ID card');
        }
        if (!current.isIdCard) {
          next = next.copyWith(clearCategory: true);
        }
      }
      return next;
    });

    Document? copy;
    if (kind == IdentityKind.idCard && !document.isIdCard) {
      copy = await repository.copyAsIdCard(document.id);
    }

    return AutoFileOutcome(
      kind: kind,
      idCopy: copy,
      message: switch (kind) {
        IdentityKind.passport => 'Saved to Private documents',
        IdentityKind.idCard when copy != null => 'Saved a copy to IDs',
        IdentityKind.idCard || IdentityKind.none => null,
      },
    );
  }
}
