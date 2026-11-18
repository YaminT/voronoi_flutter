import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_flutter/src/orient.dart';

import 'support.dart';

// orient2d is negative for a left turn; exactOrient is 1 for a left turn.
int sign(Offset a, Offset b, Offset c) =>
    -orient2d(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy).sign.toInt();

void main() {
  test('left, right and straight', () {
    const a = Offset(0, 0), b = Offset(4, 0);
    expect(sign(a, b, const Offset(0, 4)), 1);
    expect(sign(a, b, const Offset(0, -4)), -1);
    expect(sign(a, b, const Offset(9, 0)), 0);
  });

  test('nearly collinear triples agree with exact arithmetic', () {
    final random = Random(1);
    for (final scale in [1.0, 1e-3, 1e6]) {
      for (var i = 0; i < 7000; i++) {
        final a = Offset(
          random.nextDouble() * scale,
          random.nextDouble() * scale,
        );
        final b = Offset(
          random.nextDouble() * scale,
          random.nextDouble() * scale,
        );
        final t = random.nextDouble();
        var c = a + (b - a) * t;
        final nudge = [0.0, 1.0, -1.0][random.nextInt(3)] * scale * 1.1e-16;
        c = random.nextBool() ? c.translate(nudge, 0) : c.translate(0, nudge);
        expect(sign(a, b, c), exactOrient(a, b, c), reason: '$a $b $c');
      }
    }
  });

  test('exactly collinear grid points give zero', () {
    for (var i = 0; i < 20; i++) {
      for (var j = 0; j < 20; j++) {
        final a = Offset(i * 0.5, i * 0.25);
        final b = Offset(j * 0.5 + 1, j * 0.25 + 0.5);
        final c = Offset((i + j) * 0.5 + 2, (i + j) * 0.25 + 1);
        if (exactOrient(a, b, c) == 0) {
          expect(orient2d(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy), 0);
        }
      }
    }
    expect(orient2d(0.5, 0.5, 12, 12, 24, 24), 0);
    expect(orient2d(0.1, 0.1, 0.2, 0.2, 0.3, 0.3), 0);
  });

  test('swapping two points flips the sign', () {
    final random = Random(2);
    for (var i = 0; i < 2000; i++) {
      final a = Offset(random.nextDouble(), random.nextDouble());
      final b = Offset(random.nextDouble(), random.nextDouble());
      final c = a + (b - a) * random.nextDouble();
      expect(sign(a, b, c), -sign(b, a, c));
      expect(sign(a, b, c), -sign(a, c, b));
    }
  });
}
