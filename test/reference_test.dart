import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_flutter/voronoi_flutter.dart';

import 'reference/grid_voronoi.dart';
import 'support.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 0, 100, 100);

  test('the reference matches Voronoi on random points', () {
    final points = randomPoints(50, bounds, 1);
    final a = Voronoi(points, bounds);
    final b = GridVoronoi(points, bounds);
    for (var i = 0; i < points.length; i++) {
      expect(a.cells[i].neighbors, b.cells[i].neighbors);
      expect(a.cells[i].area, closeTo(b.cells[i].area, 1e-9));
    }
  });

  test('helpers: exact orientation and circumcircle', () {
    const a = Offset(0, 0), b = Offset(4, 0), c = Offset(0, 4);
    expect(exactOrient(a, b, c), 1);
    expect(exactOrient(a, c, b), -1);
    expect(exactOrient(a, b, const Offset(8, 0)), 0);
    // The last point is one ulp above the line y = x.
    expect(
      exactOrient(
        const Offset(0.1, 0.1),
        const Offset(0.2, 0.2),
        const Offset(0.3, 0.30000000000000004),
      ),
      1,
    );
    expect(
      inCircumcircle(a, b, c, const Offset(4, 4)),
      isFalse,
    ); // on the circle
    expect(inCircumcircle(a, b, c, const Offset(2, 2)), isTrue);
    expect(inCircumcircle(a, b, c, const Offset(2, 1)), isTrue);
    expect(inCircumcircle(a, c, b, const Offset(2, 1)), isTrue);
    expect(inCircumcircle(a, b, c, const Offset(5, 5)), isFalse);
    expect(polygonArea([a, b, const Offset(4, 4), const Offset(0, 4)]), 16);
  });
}
