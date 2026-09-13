import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:scan2/features/library/data/document_storage.dart';
import 'package:scan2/features/library/data/document_store.dart';
import 'package:scan2/features/library/domain/page_stamp.dart';

void main() {
  late Directory tempRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('scan2_store_test');
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  /// A fresh store over the same directory — i.e. the next app launch.
  DocumentStore newStore() =>
      DocumentStore(storage: DocumentStorage(overrideRoot: tempRoot));

  String makeSourceImage(String name) {
    final file = File(p.join(tempRoot.path, name));
    file.writeAsBytesSync(List<int>.filled(64, 7));
    return file.path;
  }

  test('documents survive a restart', () async {
    final first = newStore();
    final doc = await first.createDocumentFromScans([
      makeSourceImage('a.jpg'),
      makeSourceImage('b.jpg'),
    ], title: 'Tax return');
    expect(doc.pageCount, 2);

    // Reopen from disk, as the app would on next launch.
    final reopened = await newStore().getAllDocuments();
    expect(reopened, hasLength(1));
    expect(reopened.single.title, 'Tax return');
    expect(reopened.single.pageCount, 2);
    for (final page in reopened.single.pagePaths) {
      expect(File(page).existsSync(), isTrue, reason: '$page missing');
    }
  });

  test(
    'page paths are stored relative, so a moved container still resolves',
    () async {
      final store = newStore();
      await store.createDocumentFromScans([makeSourceImage('a.jpg')]);

      final manifest = File(
        p.join(tempRoot.path, 'documents', 'library.json'),
      ).readAsStringSync();
      // iOS reassigns the container path between installs; an absolute path
      // baked into the manifest would dangle after the next build.
      expect(manifest, isNot(contains(tempRoot.path)));
      expect(manifest, contains('page_000.jpg'));
    },
  );

  test('adding pages appends without overwriting existing ones', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([makeSourceImage('a.jpg')]);
    final updated = await store.addPages(doc.id, [makeSourceImage('b.jpg')]);

    expect(updated!.pageCount, 2);
    expect(updated.pagePaths.toSet(), hasLength(2));
    expect(File(updated.pagePaths[0]).existsSync(), isTrue);
    expect(File(updated.pagePaths[1]).existsSync(), isTrue);
  });

  test(
    'deleting a document removes its files and its manifest entry',
    () async {
      final store = newStore();
      final doc = await store.createDocumentFromScans([
        makeSourceImage('a.jpg'),
      ]);
      final pagePath = doc.pagePaths.first;

      await store.deleteDocument(doc.id);
      expect(await store.getAllDocuments(), isEmpty);
      expect(File(pagePath).existsSync(), isFalse);
      expect((await newStore().getAllDocuments()), isEmpty);
    },
  );

  test('deleting the last page moves the scan to Trash', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([makeSourceImage('a.jpg')]);
    await store.deletePage(documentId: doc.id, pagePath: doc.pagePaths.first);
    expect(await store.getAllDocuments(), isEmpty);
    expect(await store.getTrashDocuments(), hasLength(1));
  });

  test('ids keep increasing across restarts', () async {
    final first = newStore();
    final a = await first.createDocumentFromScans([makeSourceImage('a.jpg')]);

    final second = newStore();
    final b = await second.createDocumentFromScans([makeSourceImage('b.jpg')]);

    expect(
      b.id,
      greaterThan(a.id),
      reason: 'a reused id would make two documents share a page directory',
    );
  });

  test('a corrupt manifest recovers the pages already on disk', () async {
    final store = newStore();
    await store.createDocumentFromScans([makeSourceImage('a.jpg')]);

    File(
      p.join(tempRoot.path, 'documents', 'library.json'),
    ).writeAsStringSync('{ this is not json');

    final recovered = await newStore().getAllDocuments();
    expect(recovered, hasLength(1));
    expect(recovered.single.pageCount, 1);
  });

  test('renaming persists', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([makeSourceImage('a.jpg')]);
    await store.renameDocument(doc.id, 'Passport');

    final reopened = await newStore().getAllDocuments();
    expect(reopened.single.title, 'Passport');
  });

  test('folders persist and hold documents across restarts', () async {
    final store = newStore();
    final taxes = await store.createFolder('Taxes');
    final receipts = await store.createFolder('Receipts');
    final doc = await store.createDocumentFromScans([
      makeSourceImage('a.jpg'),
    ], title: 'Return');

    await store.moveDocuments(documentIds: [doc.id], folderId: taxes.id);

    final reopened = newStore();
    final folders = await reopened.getFolders();
    expect(folders.map((f) => f.name), ['Receipts', 'Taxes']);
    final docs = await reopened.getAllDocuments();
    expect(docs.single.folderId, taxes.id);
    expect(docs.single.folderId, isNot(receipts.id));
  });

  test('deleting a folder leaves the scans on the home list', () async {
    final store = newStore();
    final folder = await store.createFolder('Work');
    final doc = await store.createDocumentFromScans([makeSourceImage('a.jpg')]);
    await store.moveDocuments(documentIds: [doc.id], folderId: folder.id);

    await store.deleteFolder(folder.id);

    expect(await store.getFolders(), isEmpty);
    expect((await store.getAllDocuments()).single.folderId, isNull);

    final reopened = await newStore().getAllDocuments();
    expect(reopened.single.folderId, isNull);
  });

  test('moving a scan out of a folder clears folderId', () async {
    final store = newStore();
    final folder = await store.createFolder('Keep');
    final doc = await store.createDocumentFromScans([makeSourceImage('a.jpg')]);
    await store.moveDocuments(documentIds: [doc.id], folderId: folder.id);
    await store.moveDocuments(documentIds: [doc.id], folderId: null);

    expect((await store.getAllDocuments()).single.folderId, isNull);
  });

  test('a new scan can be filed into a folder as it is created', () async {
    final store = newStore();
    final folder = await store.createFolder('Taxes');
    final doc = await store.createDocumentFromScans([
      makeSourceImage('a.jpg'),
    ], folderId: folder.id);

    expect(doc.folderId, folder.id);
    expect((await newStore().getAllDocuments()).single.folderId, folder.id);
  });

  test('trash hides a scan and restore brings it back', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([
      makeSourceImage('a.jpg'),
    ], title: 'Keep me');
    await store.moveToTrash(doc.id);

    expect(await store.getAllDocuments(), isEmpty);
    expect((await store.getTrashDocuments()).single.title, 'Keep me');

    await store.restoreFromTrash(doc.id);
    expect((await store.getAllDocuments()).single.title, 'Keep me');
    expect(await store.getTrashDocuments(), isEmpty);

    final reopened = newStore();
    expect((await reopened.getAllDocuments()).single.title, 'Keep me');
  });

  test('empty trash deletes files for good', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([makeSourceImage('a.jpg')]);
    final pagePath = doc.pagePaths.first;
    await store.moveToTrash(doc.id);
    await store.emptyTrash();

    expect(await store.getTrashDocuments(), isEmpty);
    expect(File(pagePath).existsSync(), isFalse);
  });

  test('merge copies pages into a new scan', () async {
    final store = newStore();
    final a = await store.createDocumentFromScans([makeSourceImage('a.jpg')]);
    final b = await store.createDocumentFromScans([
      makeSourceImage('b.jpg'),
      makeSourceImage('c.jpg'),
    ]);
    final merged = await store.mergeDocuments([a.id, b.id]);
    expect(merged.pageCount, 3);
    expect(await store.getAllDocuments(), hasLength(3));
  });

  test('split after a page makes a second scan', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([
      makeSourceImage('a.jpg'),
      makeSourceImage('b.jpg'),
      makeSourceImage('c.jpg'),
    ]);
    final created = await store.splitAfter(documentId: doc.id, afterIndex: 0);
    expect(created.pageCount, 2);
    expect((await store.getDocument(doc.id))!.pageCount, 1);
  });

  test('ocr text and id-card flag persist', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([
      makeSourceImage('a.jpg'),
    ], isIdCard: true);
    await store.setOcrText(doc.id, 'INVOICE 2043');

    final reopened = await newStore().getAllDocuments();
    expect(reopened.single.isIdCard, isTrue);
    expect(reopened.single.ocrText, 'INVOICE 2043');
  });

  test('reorderPages persists the new order', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([
      makeSourceImage('a.jpg'),
      makeSourceImage('b.jpg'),
      makeSourceImage('c.jpg'),
    ]);
    final original = [...doc.pagePaths];
    await store.reorderPages(doc.id, 0, 2);
    final moved = (await store.getDocument(doc.id))!;
    expect(moved.pagePaths.toSet(), original.toSet());
    expect(moved.pagePaths.first, isNot(original.first));

    final reopened = await newStore().getDocument(doc.id);
    expect(reopened!.pagePaths, moved.pagePaths);
  });

  test('setPageStamps persist across restart and survive merge', () async {
    final store = newStore();
    final a = await store.createDocumentFromScans([makeSourceImage('a.jpg')]);
    final stampFile = File(p.join(tempRoot.path, 'sig.png'));
    stampFile.writeAsBytesSync(List<int>.filled(32, 9));
    await store.setPageStamps(
      documentId: a.id,
      pagePath: a.pagePaths.first,
      stamps: [
        PageStamp(
          imagePath: stampFile.path,
          nx: 0.5,
          ny: 0.6,
          nw: 0.3,
          nh: 0.2,
          caption: 'Alex · 28 Aug 2026',
        ),
      ],
    );

    final reopened = (await newStore().getDocument(a.id))!;
    expect(reopened.pages.first.stamps, hasLength(1));
    expect(reopened.pages.first.stamps.first.caption, 'Alex · 28 Aug 2026');

    final b = await store.createDocumentFromScans([makeSourceImage('b.jpg')]);
    final merged = await store.mergeDocuments([a.id, b.id]);
    expect(merged.pages.first.stamps, hasLength(1));
    expect(merged.pages.first.stamps.first.caption, 'Alex · 28 Aug 2026');
  });

  test('setPageStamps bakes ink into the page so a saved file shows it', () async {
    final store = newStore();
    final page = img.Image(width: 120, height: 160);
    for (var y = 0; y < 160; y++) {
      for (var x = 0; x < 120; x++) {
        page.setPixelRgb(x, y, 40, 100, 200);
      }
    }
    final source = File(p.join(tempRoot.path, 'page.jpg'));
    source.writeAsBytesSync(img.encodeJpg(page, quality: 95));
    final doc = await store.createDocumentFromScans([source.path]);

    final sig = img.Image(width: 30, height: 16);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 30; x++) {
        sig.setPixelRgb(x, y, 0, 0, 0);
      }
    }
    final stampFile = File(p.join(tempRoot.path, 'real_sig.png'));
    stampFile.writeAsBytesSync(img.encodePng(sig));

    await store.setPageStamps(
      documentId: doc.id,
      pagePath: doc.pagePaths.first,
      stamps: [
        PageStamp(
          imagePath: stampFile.path,
          nx: 0.55,
          ny: 0.75,
          nw: 0.3,
          nh: 0.12,
        ),
      ],
    );

    final saved = (await store.getDocument(doc.id))!;
    expect(saved.pages.first.stamps, isEmpty, reason: 'ink is in the JPEG');
    final baked = img.decodeImage(File(saved.pages.first.path).readAsBytesSync())!;
    final ink = baked.getPixel(80, 130);
    expect(ink.r.toInt(), lessThan(60), reason: 'saved page must show the signature');
    final paper = baked.getPixel(10, 10);
    expect(paper.b.toInt(), greaterThan(140), reason: 'the page is not a white box');

    await store.rotatePageClockwise(
      documentId: doc.id,
      pagePath: saved.pages.first.path,
    );
    final turned = img.decodeImage(
      File(saved.pages.first.path).readAsBytesSync(),
    )!;
    // 90° clockwise: (x, y) → (height - 1 - y, x) → (29, 80).
    final rotatedInk = turned.getPixel(29, 80);
    expect(
      rotatedInk.r.toInt(),
      lessThan(60),
      reason: 'rotating a signed page must keep the ink',
    );
    expect(turned.getPixel(149, 10).b.toInt(), greaterThan(140));
  });

  test('a page the compositor cannot read keeps stamps for export', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([
      makeSourceImage('not_an_image.jpg'),
    ]);
    final stampFile = File(p.join(tempRoot.path, 'keep.png'));
    stampFile.writeAsBytesSync(img.encodePng(img.Image(width: 8, height: 8)));
    await store.setPageStamps(
      documentId: doc.id,
      pagePath: doc.pagePaths.first,
      stamps: [
        PageStamp(
          imagePath: stampFile.path,
          nx: 0.2,
          ny: 0.2,
          nw: 0.3,
          nh: 0.2,
        ),
      ],
    );
    final saved = (await store.getDocument(doc.id))!;
    expect(
      saved.pages.first.stamps,
      isNotEmpty,
      reason: 'do not wipe stamps after a no-op bake',
    );
  });

  test('favorite, tags, private and hash persist', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([
      makeSourceImage('a.jpg'),
    ]);
    expect(doc.contentHash, isNotNull);
    await store.updateDocument(
      doc.id,
      (current) => current.copyWith(
        isFavorite: true,
        isPrivate: true,
        tags: const ['tax', '2026'],
        category: 'invoice',
      ),
    );

    final reopened = (await newStore().getDocument(doc.id))!;
    expect(reopened.isFavorite, isTrue);
    expect(reopened.isPrivate, isTrue);
    expect(reopened.tags, ['tax', '2026']);
    expect(reopened.category, 'invoice');
    expect(reopened.contentHash, doc.contentHash);
  });

  test('copyAsIdCard writes a hidden IDs copy that survives restart', () async {
    final store = newStore();
    final doc = await store.createDocumentFromScans([
      makeSourceImage('license.jpg'),
    ], title: 'Scan 09/13 08:01');
    final copy = await store.copyAsIdCard(doc.id);

    expect(copy.isIdCard, isTrue);
    expect(copy.hideFromLibrary, isTrue);
    expect(copy.autoFiled, isTrue);
    expect(copy.pageCount, 1);
    expect(File(copy.pagePaths.first).existsSync(), isTrue);
    expect(copy.pagePaths.first, isNot(doc.pagePaths.first));

    final reopened = await newStore().getAllDocuments();
    expect(reopened, hasLength(2));
    final savedCopy = reopened.firstWhere((d) => d.id == copy.id);
    expect(savedCopy.isIdCard, isTrue);
    expect(savedCopy.hideFromLibrary, isTrue);
    expect(File(savedCopy.pagePaths.first).existsSync(), isTrue);
  });
}
