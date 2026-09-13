import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/imaging/raster.dart';

void main() {
  group('Raster.rotatedClockwise', () {
    test('swaps size and moves the left column to the top row', () {
      // 2×1: red then blue, left to right.
      final src = Raster.fromPixels(
        2,
        1,
        Uint8List.fromList([
          220, 20, 20, // red
          20, 20, 220, // blue
        ]),
      );

      final rotated = src.rotatedClockwise();
      expect(rotated.width, 1);
      expect(rotated.height, 2);
      // Left (red) becomes the top pixel.
      expect(rotated.pixels[0], 220);
      expect(rotated.pixels[1], 20);
      expect(rotated.pixels[2], 20);
      // Right (blue) becomes the bottom pixel.
      expect(rotated.pixels[3], 20);
      expect(rotated.pixels[4], 20);
      expect(rotated.pixels[5], 220);
    });

    test('four turns restore the original pixels', () {
      final src = Raster.fromPixels(
        3,
        2,
        Uint8List.fromList([
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
          16,
          17,
          18,
        ]),
      );
      final restored = src.rotatedTurns(4);
      expect(restored.width, src.width);
      expect(restored.height, src.height);
      expect(restored.pixels, src.pixels);
    });
  });
}
