import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/document_organizer.dart';
import 'package:scan2/features/library/domain/smart_folder.dart';

void main() {
  const organizer = DocumentOrganizer();

  test('generic titles are the ones the app invented', () {
    expect(DocumentOrganizer.isGenericTitle('Scan 08/29 12:01'), isTrue);
    expect(DocumentOrganizer.isGenericTitle('Invoice 2043'), isFalse);
  });

  test('suggests a title from the first real line', () {
    expect(
      organizer.suggestTitle('INVOICE\nAcme Ltd\nAmount due 40'),
      'INVOICE',
    );
  });

  test('categorizes receipts and invoices', () {
    expect(organizer.categorize('Tax invoice amount due'), 'invoice');
    expect(organizer.categorize('Thank you for your purchase receipt'), 'receipt');
  });

  test('detects a passport before an ID card', () {
    expect(
      organizer.detectIdentity('PASSPORT\nUnited States of America\nDate of birth'),
      IdentityKind.passport,
    );
    expect(organizer.detectIdentity('P<UTOERIKSSON<<ANNA<MARIA'), IdentityKind.passport);
    expect(
      organizer.detectIdentity('REPUBLIC OF INDIA\nDriving Licence\nDL No'),
      IdentityKind.idCard,
    );
    expect(organizer.detectIdentity('Aadhaar number 1234 5678 9012'), IdentityKind.idCard);
    expect(organizer.detectIdentity('Date of birth 01/02/1990'), IdentityKind.none);
    expect(organizer.detectIdentity('Tax invoice amount due'), IdentityKind.none);
  });

  test('duplicate smart folder keeps only shared hashes', () {
    final docs = [
      Document(
        id: 1,
        title: 'A',
        createdAt: DateTime(2026, 1, 1),
        contentHash: 'aaa',
      ),
      Document(
        id: 2,
        title: 'B',
        createdAt: DateTime(2026, 1, 2),
        contentHash: 'aaa',
      ),
      Document(
        id: 3,
        title: 'C',
        createdAt: DateTime(2026, 1, 3),
        contentHash: 'bbb',
      ),
    ];
    final dupes = SmartFolder.duplicates.filter(docs);
    expect(dupes.map((d) => d.id), [1, 2]);
    expect(SmartFolder.favorites.filter(docs), isEmpty);
  });

  test('favorites and private folders filter metadata', () {
    final docs = [
      Document(
        id: 1,
        title: 'A',
        createdAt: DateTime(2026, 1, 1),
        isFavorite: true,
      ),
      Document(
        id: 2,
        title: 'B',
        createdAt: DateTime(2026, 1, 2),
        isPrivate: true,
      ),
    ];
    expect(SmartFolder.favorites.filter(docs).single.id, 1);
    expect(SmartFolder.private.filter(docs).single.id, 2);
  });
}
