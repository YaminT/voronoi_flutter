import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_flutter/voronoi_flutter.dart';

import 'support.dart';

const bounds = Rect.fromLTWH(0, 0, 1000, 1000);

void main() {
  group('construction', () {
    test('from offsets and from a flat list agree', () {
      final points = randomPoints(50, bounds, 1);
      final a = Delaunay.from(points);
      final b = Delaunay(
        Float64List.fromList([
          for (final p in points) ...[p.dx, p.dy],
        ]),
      );
      expect(a.triangles, b.triangles);
      expect(a.length, 50);
      expect(a.points.length, 100);
    });

    test('update after moving the points equals a new Delaunay', () {
      final d = Delaunay.from(randomPoints(200, bounds, 2));
      final moved = randomPoints(200, bounds, 3);
      for (var i = 0; i < 200; i++) {
        d.points[2 * i] = moved[i].dx;
        d.points[2 * i + 1] = moved[i].dy;
      }
      d.update();
      final fresh = Delaunay.from(moved);
      expect(d.triangles, fresh.triangles);
      expect(d.halfedges, fresh.halfedges);
      expect(d.hull, fresh.hull);
      expect(d.inedges, fresh.inedges);
    });

    test('bad input throws', () {
      expect(() => Delaunay(Float64List(3)), throwsArgumentError);
      expect(
        () => Delaunay(Float64List.fromList([0, double.nan])),
        throwsArgumentError,
      );
      expect(
        () => Delaunay(Float64List.fromList([double.infinity, 0])),
        throwsArgumentError,
      );
      final d = Delaunay.from(const [Offset(0, 0)]);
      d.points[0] = double.nan;
      expect(d.update, throwsArgumentError);
    });
  });

  group('no triangles', () {
    test('0, 1, 2 and 3 collinear points', () {
      for (final n in [0, 1, 2, 3]) {
        final d = Delaunay.from([
          for (var i = 0; i < n; i++) Offset(i * 2.0, i * 1.0),
        ]);
        expect(d.triangles, isEmpty);
        expect(d.halfedges, isEmpty);
        expect(d.collinear, [for (var i = 0; i < n; i++) i]);
        expect(d.hull, d.collinear);
        expect(d.inedges, everyElement(-1));
      }
    });

    for (final (name, make) in <(String, Offset Function(int))>[
      ('horizontal', (i) => Offset(i * 1.0, 5)),
      ('vertical', (i) => Offset(5, i * 1.0)),
      ('diagonal', (i) => Offset(i * 1.0, i * 1.0)),
      ('slope 0.5', (i) => Offset(i * 0.5, i * 0.25)),
    ]) {
      test('50 points on a $name line', () {
        final points = [for (var i = 0; i < 50; i++) make(i)];
        final d = Delaunay.from((points.toList()..shuffle()));
        expect(d.triangles, isEmpty);
        final ordered = [for (final i in d.collinear!) d.points[2 * i]];
        final sorted = [...ordered]..sort();
        // Along the line: by x, or by y if all x are equal.
        if (name == 'vertical') {
          final ys = [for (final i in d.collinear!) d.points[2 * i + 1]];
          expect(ys, [...ys]..sort());
        } else {
          expect(ordered, sorted);
        }
        expect(d.collinear!.length, 50);
        expect(d.hull, d.collinear);
      });
    }

    test('a line that is not exact in doubles still finishes', () {
      final d = Delaunay.from([
        for (var i = 0; i < 50; i++) Offset(i * 0.1, i * 0.3),
      ]);
      for (var e = 0; e < d.halfedges.length; e++) {
        final twin = d.halfedges[e];
        if (twin != -1) expect(d.halfedges[twin], e);
      }
      for (var i = 0; i < 50; i++) {
        expect(d.inedges[i] != -1 || d.collinear!.contains(i), isTrue);
      }
    });

    test('triangles that have no area switch to the line', () {
      // Found by search: exactly on one line, but Delaunator makes a triangle.
      final d = Delaunay(
        Float64List.fromList([
          0.15000000000000002,
          0.45000000000000007,
          0.7250000000000001,
          2.1750000000000003,
          0.07500000000000001,
          0.22500000000000003,
        ]),
      );
      expect(d.triangles, isEmpty);
      expect(d.collinear, [2, 0, 1]);
      expect(d.hull, [2, 0, 1]);
    });

    test('equal points on a flat line count once', () {
      final d = Delaunay(
        Float64List.fromList([
          0.7250000000000001,
          2.1750000000000003,
          0.275,
          0.8250000000000001,
          0.25,
          0.75,
          0.7250000000000001,
          2.1750000000000003,
          0.75,
          2.25,
        ]),
      );
      expect(d.triangles, isEmpty);
      expect(d.collinear, [2, 1, 0, 4]);
    });

    test('all points equal', () {
      final d = Delaunay.from(List.filled(5, const Offset(3, 4)));
      expect(d.triangles, isEmpty);
      expect(d.collinear, [0]);
      expect(d.inedges, everyElement(-1));
    });
  });

  group('triangulated', () {
    test('equal points: the lowest index keeps its place', () {
      final points = randomPoints(30, bounds, 4);
      final d = Delaunay.from([...points, ...points.reversed]);
      for (var i = 0; i < 30; i++) {
        expect(d.inedges[i], isNot(-1));
        expect(d.inedges[59 - i], -1);
      }
    });

    test('a square has two triangles', () {
      final d = Delaunay.from(const [
        Offset(0, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ]);
      expect(d.triangles.length, 6);
      expect(d.collinear, isNull);
    });

    test('a 10 x 10 grid has 162 triangles', () {
      final d = Delaunay.from([
        for (var y = 0; y < 10; y++)
          for (var x = 0; x < 10; x++) Offset(x * 1.0, y * 1.0),
      ]);
      expect(d.triangles.length ~/ 3, 162);
    });

    test('inedges end at the point; hull points have a hull edge', () {
      final d = Delaunay.from(randomPoints(300, bounds, 5));
      for (var i = 0; i < 300; i++) {
        final e = d.inedges[i];
        expect(d.triangles[e % 3 == 2 ? e - 2 : e + 1], i);
      }
      for (final i in d.hull) {
        expect(d.halfedges[d.inedges[i]], -1);
      }
    });

    test('the d3 loops for edges and triangles', () {
      final points = randomPoints(100, bounds, 6);
      final d = Delaunay.from(points);

      // Every inner edge once, then the hull.
      var edges = 0;
      for (var i = 0; i < d.halfedges.length; i++) {
        final j = d.halfedges[i];
        if (j < i) continue;
        edges++;
      }
      edges += d.hull.length;
      expect(edges, 3 * 100 - 3 - d.hull.length);

      var area = 0.0;
      for (var i = 0; i < d.triangles.length ~/ 3; i++) {
        area += polygonArea([
          points[d.triangles[i * 3]],
          points[d.triangles[i * 3 + 1]],
          points[d.triangles[i * 3 + 2]],
        ]);
      }
      expect(
        area,
        closeTo(polygonArea([for (final i in d.hull) points[i]]), 1e-6),
      );
    });
  });
}
