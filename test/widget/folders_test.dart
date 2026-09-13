import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/library/presentation/documents_view.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('home can create a folder from the New folder button', (
    tester,
  ) async {
    final repo = WebDemoRepository(seedSampleData: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [documentRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: DocumentsView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('New folder'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byTooltip('New folder'), findsOneWidget);
    await tester.tap(find.byTooltip('New folder'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Taxes',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Taxes'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Taxes'), findsWidgets);
    expect(await repo.getFolders(), hasLength(1));
    expect((await repo.getFolders()).single.name, 'Taxes');
  });
}
