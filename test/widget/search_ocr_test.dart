import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/library/presentation/documents_view.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';

void main() {
  testWidgets('search matches saved OCR text', (tester) async {
    final repo = WebDemoRepository(seedSampleData: true);
    final docs = await repo.getAllDocuments();
    await repo.setOcrText(docs.first.id, 'unique zebra invoice');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: DocumentsView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byType(TextField),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), 'zebra');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(find.text(docs.first.title), findsWidgets);
    expect(find.text('No matches'), findsNothing);
  });
}
