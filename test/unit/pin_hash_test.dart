import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/settings/domain/pin_hash.dart';

void main() {
  test('the same PIN hashes the same way', () {
    expect(hashPin('1234'), hashPin('1234'));
    expect(hashPin('1234'), isNot(hashPin('1235')));
    expect(hashPin('1234'), isNot('1234'));
  });
}
