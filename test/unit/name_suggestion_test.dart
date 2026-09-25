import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/library/presentation/name_scan_dialog.dart';

void main() {
  test('a suggestion replaces the default word and keeps the date', () {
    expect(
      withSuggestedName('Scan 09/23 19:53', 'Invoice'),
      'Invoice 09/23 19:53',
    );
  });

  test('a second suggestion swaps the first instead of stacking', () {
    expect(
      withSuggestedName('Invoice 09/23 19:53', 'Receipt'),
      'Receipt 09/23 19:53',
    );
  });

  test('an empty name becomes the suggestion', () {
    expect(withSuggestedName('  ', 'ID'), 'ID');
  });

  test('a custom name is kept after the suggestion', () {
    expect(withSuggestedName('Acme March', 'Invoice'), 'Invoice Acme March');
  });
}
