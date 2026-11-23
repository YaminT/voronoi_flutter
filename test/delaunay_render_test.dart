import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_flutter/voronoi_flutter.dart';

import 'support.dart';

const bounds = Rect.fromLTWH(100, 200, 800, 500);

Rect boundsOf(List<Offset> points) {
  final xs = points.map((p) => p.dx), ys = points.map((p) => p.dy);
  return Rect.fromLTRB(
    xs.reduce(min),
    ys.reduce(min),
    xs.reduce(max),
    ys.reduce(max),
  );
}

void expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 1e-3));
  expect(actual.top, closeTo(expected.top, 1e-3));
  expect(actual.right, closeTo(expected.right, 1e-3));
  expect(actual.bottom, closeTo(expected.bottom, 1e-3));
}

void main() {
  final points = randomPoints(100, bounds, 1);
  final d = Delaunay.from(points);

  group('polygons', () {
    test('triangles have three corners from triangles', () {
      final polygons = d.trianglePolygons().toList();
      expect(polygons.length, d.triangles.length ~/ 3);
      for (var t = 0; t < polygons.length; t++) {
        expect(polygons[t], [
          for (var k = 0; k < 3; k++) points[d.triangles[3 * t + k]],
        ]);
        expect(d.trianglePolygon(t), polygons[t]);
      }
    });

    test('the hull has the corners of hull in order', () {
      expect(d.hullPolygon(), [for (final i in d.hull) points[i]]);
    });

    test('a bad triangle index throws', () {
      expect(() => d.trianglePolygon(-1), throwsRangeError);
      expect(
        () => d.trianglePolygon(d.triangles.length ~/ 3),
        throwsRangeError,
      );
    });
  });

  group('paths', () {
    test('renderTriangle holds the middle of the triangle', () {
      for (var t = 0; t < d.triangles.length ~/ 3; t += 7) {
        final corners = d.trianglePolygon(t);
        final middle = (corners[0] + corners[1] + corners[2]) / 3;
        final path = d.renderTriangle(t);
        expect(path.contains(middle), isTrue);
        expectRect(path.getBounds(), boundsOf(corners));
      }
    });

    test('renderHull and render cover the points', () {
      expectRect(d.renderHull().getBounds(), boundsOf(points));
      expectRect(d.render().getBounds(), boundsOf(points));
    });

    test('render has one line for every inner edge, and the hull', () {
      final inner = (d.triangles.length - d.hull.length) ~/ 2;
      expect(d.render().computeMetrics().length, inner + 1);
    });

    test('renderPoints draws a circle around every point', () {
      final path = d.renderPoints(null, 5);
      expect(path.computeMetrics().length, 100);
      expectRect(path.getBounds(), boundsOf(points).inflate(5));
      expectRect(d.renderPoints().getBounds(), boundsOf(points).inflate(2));
    });

    test('a given path is added to and returned', () {
      final path = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      expect(identical(d.render(path), path), isTrue);
      expect(identical(d.renderHull(path), path), isTrue);
      expect(identical(d.renderTriangle(0, path), path), isTrue);
      expect(identical(d.renderPoints(path), path), isTrue);
      final all = boundsOf(points)
          .inflate(2)
          .expandToInclude(const Rect.fromLTWH(0, 0, 10, 10));
      expectRect(path.getBounds(), all);
    });
  });

  group('no triangles', () {
    test('lines and tiny inputs do not throw', () {
      for (final n in [0, 1, 2, 5]) {
        final line = Delaunay.from([
          for (var i = 0; i < n; i++) Offset(i * 3.0, i * 1.0),
        ]);
        expect(line.trianglePolygons(), isEmpty);
        expect(line.hullPolygon().length, n);
        expect(line.render, returnsNormally);
        expect(line.renderHull, returnsNormally);
        expect(line.renderPoints, returnsNormally);
        expect(() => line.renderTriangle(0), throwsRangeError);
      }
    });

    test('a line is drawn from its first to its last point', () {
      final line = Delaunay.from([
        for (var i = 0; i < 5; i++) Offset(i * 3.0, i * 1.0),
      ]);
      expectRect(line.render().getBounds(), const Rect.fromLTRB(0, 0, 12, 4));
    });
  });
}
