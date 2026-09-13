import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/features/camera/domain/document_quad_detector.dart';
import 'package:scan2/features/camera/domain/quad_detector.dart';

void main() {
  group('Quad', () {
    test('centered has inset corners', () {
      const q = Quad.centered();
      expect(q.topLeft.dx, lessThan(0.2));
      expect(q.bottomRight.dx, greaterThan(0.8));
    });

    test('isClearlyInset is false for a full-bleed native crop', () {
      expect(const Quad.fullFrame().isClearlyInset, isFalse);
    });

    test('isClearlyInset is true for a page sitting inside the frame', () {
      const q = Quad(
        topLeft: Offset(0.18, 0.16),
        topRight: Offset(0.84, 0.15),
        bottomRight: Offset(0.88, 0.86),
        bottomLeft: Offset(0.14, 0.84),
      );
      expect(q.isClearlyInset, isTrue);
      expect(q.areaRatio, lessThan(0.88));
    });

    test('lerp moves corners', () {
      const a = Quad.centered();
      final b = a.copyWith(topLeft: const Offset(0.2, 0.2));
      final mid = a.lerp(b, 0.5);
      expect(mid.topLeft.dx, closeTo(0.16, 0.001));
    });

    test('rotatedClockwise maps the old bottom-left to the new top-left', () {
      const q = Quad(
        topLeft: Offset(0.1, 0.2),
        topRight: Offset(0.8, 0.2),
        bottomRight: Offset(0.8, 0.9),
        bottomLeft: Offset(0.1, 0.9),
      );
      final rotated = q.rotatedClockwise();
      expect(rotated.topLeft.dx, closeTo(0.1, 1e-9));
      expect(rotated.topLeft.dy, closeTo(0.1, 1e-9));
      expect(rotated.topRight.dx, closeTo(0.8, 1e-9));
      expect(rotated.topRight.dy, closeTo(0.1, 1e-9));
      expect(rotated.bottomRight.dx, closeTo(0.8, 1e-9));
      expect(rotated.bottomRight.dy, closeTo(0.8, 1e-9));
      expect(rotated.bottomLeft.dx, closeTo(0.1, 1e-9));
      expect(rotated.bottomLeft.dy, closeTo(0.8, 1e-9));
    });

    test('four clockwise turns restore the original quad', () {
      const q = Quad.centered();
      expect(q.rotatedTurns(4), q);
      expect(const Quad.fullFrame().rotatedClockwise(), const Quad.fullFrame());
    });
  });

  group('DocumentQuadDetector', () {
    test('finds a bright rectangle on a dark background', () {
      const w = 80;
      const h = 100;
      final lum = Uint8List(w * h);

      // Dark background
      for (var i = 0; i < lum.length; i++) {
        lum[i] = 20;
      }
      // Bright document rectangle
      for (var y = 20; y < 80; y++) {
        for (var x = 15; x < 65; x++) {
          lum[y * w + x] = 220;
        }
      }

      final result = const DocumentQuadDetector().detect(lum, w, h);
      expect(result, isNotNull);
      expect(result!.corners.length, 4);
      expect(result.confidence, greaterThan(0.2));

      // Corners should roughly sit near the rectangle.
      final xs = result.corners.map((c) => c.dx).toList()..sort();
      final ys = result.corners.map((c) => c.dy).toList()..sort();
      expect(xs.first, lessThan(0.35));
      expect(xs.last, greaterThan(0.65));
      expect(ys.first, lessThan(0.35));
      expect(ys.last, greaterThan(0.65));
    });

    test('returns null on uniform noise-free image', () {
      const w = 64;
      const h = 64;
      final lum = Uint8List(w * h);
      for (var i = 0; i < lum.length; i++) {
        lum[i] = 128;
      }
      final result = const DocumentQuadDetector().detect(lum, w, h);
      expect(result, isNull);
    });
  });
}
