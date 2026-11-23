import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_flutter/voronoi_flutter.dart';

import 'support.dart';

const bounds = Rect.fromLTWH(0, 0, 1000, 1000);

double nearestDistance(List<Offset> points, Offset query) =>
    points.map((p) => (p - query).distanceSquared).reduce(min);

// Compares by distance, never by index: ties are possible.
void expectNearest(Delaunay d, List<Offset> points, Offset query, int start) {
  final found = d.find(query, start);
  expect(
    (points[found] - query).distanceSquared,
    closeTo(nearestDistance(points, query), 1e-9),
    reason: 'query $query from $start',
  );
}

List<Offset> queries(int count, int seed) {
  final random = Random(seed);
  return [
    for (var i = 0; i < count; i++)
      // Inside the bounds for most, far outside for the rest.
      i.isEven
          ? Offset(random.nextDouble() * 1000, random.nextDouble() * 1000)
          : Offset(
              random.nextDouble() * 7000 - 3000,
              random.nextDouble() * 7000 - 3000,
            ),
  ];
}

void main() {
  group('neighbors', () {
    test('are symmetric and are the points that share a triangle', () {
      final d = Delaunay.from(randomPoints(300, bounds, 1));
      final shared = List.generate(300, (_) => <int>{});
      for (var t = 0; t < d.triangles.length; t += 3) {
        for (var a = 0; a < 3; a++) {
          for (var b = 0; b < 3; b++) {
            if (a != b) shared[d.triangles[t + a]].add(d.triangles[t + b]);
          }
        }
      }
      for (var i = 0; i < 300; i++) {
        final list = d.neighbors(i).toList();
        expect(list.toSet().length, list.length, reason: 'repeats for $i');
        expect(list.toSet(), shared[i]);
        for (final j in list) {
          expect(d.neighbors(j), contains(i));
        }
      }
    });

    test('on a grid', () {
      final d = Delaunay.from([
        for (var y = 0; y < 8; y++)
          for (var x = 0; x < 8; x++) Offset(x * 1.0, y * 1.0),
      ]);
      for (var i = 0; i < 64; i++) {
        final list = d.neighbors(i).toList();
        for (final j in list) {
          expect(d.neighbors(j), contains(i));
        }
        expect(list.toSet().length, list.length);
      }
      // The point at (3, 3) touches at least its four sides.
      expect(
        d.neighbors(3 * 8 + 3),
        containsAll([2 * 8 + 3, 4 * 8 + 3, 3 * 8 + 2, 3 * 8 + 4]),
      );
    });

    test('equal points have none', () {
      final points = randomPoints(20, bounds, 2);
      final d = Delaunay.from([...points, points[0], points[5]]);
      expect(d.neighbors(20), isEmpty);
      expect(d.neighbors(21), isEmpty);
      expect(d.neighbors(0), isNotEmpty);
    });

    test('on a line: the previous and the next point', () {
      final xs = [4, 1, 7, 3, 9, 0, 5];
      final d = Delaunay.from([for (final x in xs) Offset(x * 2.0, x * 1.0)]);
      final line = d.collinear!;
      for (var k = 0; k < line.length; k++) {
        expect(d.neighbors(line[k]).toSet(), {
          if (k > 0) line[k - 1],
          if (k < line.length - 1) line[k + 1],
        });
      }
    });

    test('1 and 2 points', () {
      expect(Delaunay.from(const [Offset(1, 1)]).neighbors(0), isEmpty);
      final two = Delaunay.from(const [Offset(1, 1), Offset(2, 2)]);
      expect(two.neighbors(0), [1]);
      expect(two.neighbors(1), [0]);
    });

    test('a bad index throws', () {
      final d = Delaunay.from(randomPoints(5, bounds, 1));
      expect(() => d.neighbors(5).toList(), throwsRangeError);
      expect(() => d.neighbors(-1).toList(), throwsRangeError);
    });
  });

  group('find', () {
    test('random points, from the first point and from every tenth', () {
      final points = randomPoints(300, bounds, 3);
      final d = Delaunay.from(points);
      for (final q in queries(2000, 4)) {
        expectNearest(d, points, q, 0);
      }
      for (final q in queries(300, 5)) {
        for (var start = 0; start < 300; start += 10) {
          expectNearest(d, points, q, start);
        }
      }
    });

    test('a grid', () {
      final points = [
        for (var y = 0; y < 10; y++)
          for (var x = 0; x < 10; x++) Offset(x * 100.0, y * 100.0),
      ];
      final d = Delaunay.from(points);
      for (final q in queries(500, 6)) {
        expectNearest(d, points, q, 0);
        expectNearest(d, points, q, 55);
      }
    });

    test('a line', () {
      final points = [for (var i = 0; i < 40; i++) Offset(i * 10.0, i * 5.0)]
        ..shuffle(Random(7));
      final d = Delaunay.from(points);
      expect(d.collinear, isNotNull);
      for (final q in queries(500, 8)) {
        for (var start = 0; start < 40; start += 7) {
          expectNearest(d, points, q, start);
        }
      }
    });

    test('equal points, also as the start', () {
      final points = randomPoints(100, bounds, 9);
      final all = [...points, ...points];
      final d = Delaunay.from(all);
      for (final q in queries(300, 10)) {
        expectNearest(d, all, q, 0);
        expectNearest(d, all, q, 100);
        expectNearest(d, all, q, 150);
        expectNearest(d, all, q, 199);
      }
    });

    test('no points, one point, and no number', () {
      expect(Delaunay.from(const []).find(const Offset(1, 1)), -1);
      expect(Delaunay.from(const [Offset(5, 5)]).find(const Offset(1, 1)), 0);
      final d = Delaunay.from(randomPoints(10, bounds, 1));
      expect(d.find(const Offset(double.nan, 1)), -1);
    });

    test('a bad start throws', () {
      final d = Delaunay.from(randomPoints(10, bounds, 1));
      expect(() => d.find(Offset.zero, 10), throwsRangeError);
    });
  });
}
