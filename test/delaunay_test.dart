import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_flutter/src/delaunator.dart';
import 'package:voronoi_flutter/src/orient.dart';

import 'support.dart';

const bounds = Rect.fromLTWH(0, 0, 1000, 1000);

Float64List flat(List<Offset> points) => Float64List.fromList([
  for (final p in points) ...[p.dx, p.dy],
]);

int next(int e) => e % 3 == 2 ? e - 2 : e + 1;

void main() {
  for (final n in [3, 4, 10, 100, 1000]) {
    group('random points, n = $n', () {
      for (var seed = 1; seed <= 20; seed++) {
        test('seed $seed', () {
          final points = randomPoints(n, bounds, seed);
          checkProperties(points, triangulate(flat(points)));
        });
      }
    });
  }

  test('20,000 random points', () {
    final points = randomPoints(20000, bounds, 1);
    checkProperties(points, triangulate(flat(points)));
  });

  test('the same input gives the same result', () {
    final coords = flat(randomPoints(500, bounds, 3));
    final a = triangulate(coords);
    final b = triangulate(coords);
    expect(b.triangles, a.triangles);
    expect(b.halfedges, a.halfedges);
    expect(b.hull, a.hull);
  });

  group('equal points', () {
    test('only the lowest index is used', () {
      final points = randomPoints(60, bounds, 5);
      for (final list in [
        [...points, ...points],
        [...points.reversed, ...points],
        [points[7], ...points, points[3], points[7]],
      ]) {
        final result = triangulate(flat(list));
        final used = result.triangles.toSet();
        for (var i = 0; i < list.length; i++) {
          final first = list.indexOf(list[i]);
          if (first != i) expect(used.contains(i), isFalse, reason: 'index $i');
        }
        expect(used.length, 60);
        checkProperties(list, result, distinctOnly: true);
      }
    });

    test('a duplicate of a seed point', () {
      final points = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(0, 10),
        const Offset(10, 10),
        const Offset(5, 5),
      ];
      for (final list in [
        [...points, ...points],
        [...points.reversed, ...points],
      ]) {
        final result = triangulate(flat(list));
        for (var i = 0; i < list.length; i++) {
          if (list.indexOf(list[i]) != i) {
            expect(result.triangles.contains(i), isFalse);
          }
        }
        checkProperties(list, result, distinctOnly: true);
      }
    });
  });

  group('no triangles', () {
    test('0, 1 and 2 points', () {
      expect(triangulate(Float64List(0)).hull, isEmpty);
      expect(triangulate(Float64List.fromList([1, 2])).hull, [0]);
      final two = triangulate(Float64List.fromList([1, 2, 3, 4]));
      expect(two.hull, [0, 1]);
      expect(two.triangles, isEmpty);
      expect(two.halfedges, isEmpty);
    });

    test('all points equal', () {
      final result = triangulate(Float64List.fromList([1, 1, 1, 1, 1, 1]));
      expect(result.hull, [0]);
      expect(result.triangles, isEmpty);
    });

    test('points on a line are ordered along it', () {
      final xs = [5, 2, 9, 0, 7, 3];
      final result = triangulate(
        flat([for (final x in xs) Offset(x * 0.5, x * 0.25)]),
      );
      expect(result.triangles, isEmpty);
      expect([for (final i in result.hull) xs[i]], [0, 2, 3, 5, 7, 9]);
    });

    test('vertical line', () {
      final result = triangulate(
        flat([
          for (final y in [3.0, 1.0, 2.0]) Offset(4, y),
        ]),
      );
      expect(result.hull, [1, 2, 0]);
    });
  });

  test('a square gives two triangles', () {
    final result = triangulate(
      flat([
        const Offset(0, 0),
        const Offset(1, 0),
        const Offset(1, 1),
        const Offset(0, 1),
      ]),
    );
    expect(result.triangles.length, 6);
    expect(result.hull.length, 4);
  });

  test('a grid', () {
    final points = [
      for (var y = 0; y < 10; y++)
        for (var x = 0; x < 10; x++) Offset(x * 1.0, y * 1.0),
    ];
    final result = triangulate(flat(points));
    expect(result.triangles.length ~/ 3, 162);
    checkProperties(points, result, grid: true);
  });

  test('100,000 random points', () {
    final points = randomPoints(100000, bounds, 1);
    final watch = Stopwatch()..start();
    final result = triangulate(flat(points));
    // ignore: avoid_print
    print('TIME 100000 points: ${watch.elapsedMilliseconds} ms');
    expect(result.triangles.length, greaterThan(0));
  });
}

void checkProperties(
  List<Offset> points,
  Triangulation result, {
  bool distinctOnly = false,
  bool grid = false,
}) {
  final t = result.triangles;
  final h = result.halfedges;
  final hull = result.hull;
  final distinct = points.toSet().length;
  final used = t.toSet();

  // Edges: twins point back, share their ends, and only the hull has none.
  var open = 0;
  for (var e = 0; e < t.length; e++) {
    final twin = h[e];
    if (twin == -1) {
      open++;
      continue;
    }
    expect(h[twin], e);
    expect(t[twin], t[next(e)]);
    expect(t[next(twin)], t[e]);
  }
  expect(open, hull.length);

  // Euler's formula: 2n - 2 - hull triangles. Points on a hull edge
  // (a grid) are used but not hull corners, so only check without them.
  if (!grid) {
    expect(used.length, distinct);
    expect(t.length ~/ 3, 2 * distinct - 2 - hull.length);
  }

  // Every triangle turns the same way and has an area.
  final turns = <int>{};
  for (var i = 0; i < t.length; i += 3) {
    final a = points[t[i]], b = points[t[i + 1]], c = points[t[i + 2]];
    turns.add(orient2d(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy).sign.toInt());
  }
  expect(turns.length, 1);
  expect(turns.single, isNot(0));

  // Empty circumcircle: no opposite vertex of a shared edge is inside.
  for (var e = 0; e < t.length; e++) {
    final twin = h[e];
    if (twin == -1) continue;
    final a = points[t[e]], b = points[t[next(e)]];
    final c = points[t[next(next(e))]], d = points[t[next(next(twin))]];
    expect(inCircumcircle(a, b, c, d), isFalse, reason: 'edge $e');
  }
  if (points.length <= 100) {
    for (var i = 0; i < t.length; i += 3) {
      final a = points[t[i]], b = points[t[i + 1]], c = points[t[i + 2]];
      for (final p in points) {
        expect(inCircumcircle(a, b, c, p), isFalse, reason: 'triangle $i');
      }
    }
  }

  // Hull: convex, contains all points, and the triangles fill it.
  // orient2d is negative for a left turn, exactOrient is positive.
  final wrongTurn = turns.single;
  final corners = [for (final i in hull) points[i]];
  for (var i = 0; i < corners.length; i++) {
    final a = corners[i];
    final b = corners[(i + 1) % corners.length];
    final c = corners[(i + 2) % corners.length];
    expect(exactOrient(a, b, c), isNot(wrongTurn));
    for (final p in points) {
      expect(exactOrient(a, b, p), isNot(wrongTurn), reason: 'point $p');
    }
  }
  var area = 0.0;
  for (var i = 0; i < t.length; i += 3) {
    area += polygonArea([points[t[i]], points[t[i + 1]], points[t[i + 2]]]);
  }
  expect(area, closeTo(polygonArea(corners), 1e-9 * polygonArea(corners)));
}
