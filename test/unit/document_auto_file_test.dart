import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/library/domain/document_auto_file.dart';
import 'package:scan2/features/library/domain/document_organizer.dart';
import 'package:scan2/features/library/domain/smart_folder.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';

void main() {
  const autoFile = DocumentAutoFile();

  test('free plan does not auto-file a passport', () async {
    final repo = WebDemoRepository();
    final doc = await repo.createDocumentFromScans(['a.jpg'], title: 'Scan 09/13 08:01');
    final outcome = await autoFile.apply(
      repository: repo,
      document: doc,
      text: 'PASSPORT\nGovernment of India',
      isPro: false,
    );
    expect(outcome.kind, IdentityKind.none);
    final saved = (await repo.getDocument(doc.id))!;
    expect(saved.isPrivate, isFalse);
    expect(saved.autoFiled, isFalse);
  });

  test('Pro files a passport into Private', () async {
    final repo = WebDemoRepository();
    final doc = await repo.createDocumentFromScans(['a.jpg'], title: 'Scan 09/13 08:01');
    final outcome = await autoFile.apply(
      repository: repo,
      document: doc,
      text: 'PASSPORT\nUnited States of America',
      isPro: true,
    );
    expect(outcome.kind, IdentityKind.passport);
    expect(outcome.message, 'Saved to Private documents');
    expect(outcome.idCopy, isNull);

    final saved = (await repo.getDocument(doc.id))!;
    expect(saved.isPrivate, isTrue);
    expect(saved.autoFiled, isTrue);
    expect(saved.title, 'Passport');
    expect(saved.category, 'id');
    expect(SmartFolder.private.filter([saved]).single.id, doc.id);
    expect(await repo.getAllDocuments(), hasLength(1));
  });

  test('Pro saves a second ID copy for the IDs drawer', () async {
    final repo = WebDemoRepository();
    final doc = await repo.createDocumentFromScans(['a.jpg'], title: 'Scan 09/13 08:01');
    final outcome = await autoFile.apply(
      repository: repo,
      document: doc,
      text: 'DRIVING LICENCE\nDate of birth 12/03/1991',
      isPro: true,
    );
    expect(outcome.kind, IdentityKind.idCard);
    expect(outcome.message, 'Saved a copy to IDs');
    expect(outcome.idCopy, isNotNull);

    final original = (await repo.getDocument(doc.id))!;
    expect(original.isPrivate, isFalse);
    expect(original.hideFromLibrary, isFalse);
    expect(original.isIdCard, isFalse);
    expect(original.autoFiled, isTrue);
    expect(original.title, 'ID card');
    expect(original.category, isNull);

    final copy = outcome.idCopy!;
    expect(copy.isIdCard, isTrue);
    expect(copy.hideFromLibrary, isTrue);
    expect(copy.category, 'id');
    expect(copy.title, 'ID card');

    final all = await repo.getAllDocuments();
    expect(all, hasLength(2));
    expect(
      SmartFolder.ids.filter(all).map((d) => d.id),
      contains(copy.id),
    );
    expect(SmartFolder.ids.filter(all).map((d) => d.id), isNot(contains(doc.id)));
  });

  test('does not copy an ID-card tool scan again', () async {
    final repo = WebDemoRepository();
    final doc = await repo.createDocumentFromScans(
      ['a.jpg'],
      title: 'ID',
      isIdCard: true,
    );
    final outcome = await autoFile.apply(
      repository: repo,
      document: doc,
      text: 'Identity card',
      isPro: true,
    );
    expect(outcome.idCopy, isNull);
    expect(await repo.getAllDocuments(), hasLength(1));
    expect((await repo.getDocument(doc.id))!.autoFiled, isTrue);
  });

  test('empty OCR does not lock the scan as filed', () async {
    final repo = WebDemoRepository();
    final doc = await repo.createDocumentFromScans(['a.jpg']);
    final outcome = await autoFile.apply(
      repository: repo,
      document: doc,
      text: '   ',
      isPro: true,
    );
    expect(outcome.kind, IdentityKind.none);
    expect((await repo.getDocument(doc.id))!.autoFiled, isFalse);
  });
}
