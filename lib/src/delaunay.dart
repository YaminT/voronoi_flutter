import 'dart:typed_data';
import 'dart:ui';

import 'delaunator.dart' show triangulate;
import 'orient.dart';

/// The Delaunay triangulation of a set of points, after d3-delaunay.
///
/// Triangles are stored in flat lists. Triangle `t` has the corners
/// `triangles[3 * t]`, `triangles[3 * t + 1]` and `triangles[3 * t + 2]`,
/// and its edge `e` runs from `triangles[e]` to the next corner of the
/// same triangle. [halfedges] gives the same edge seen from the neighbour
/// triangle.
class Delaunay {
  /// Triangulates [points], a flat list `x0, y0, x1, y1, ...`.
  ///
  /// The list is not copied. After changing its values, call [update].
  Delaunay(this.points) {
    _check();
    _init();
  }

  /// Triangulates a list of points.
  factory Delaunay.from(Iterable<Offset> points) {
    return Delaunay(
      Float64List.fromList([
        for (final p in points) ...[p.dx, p.dy],
      ]),
    );
  }

  /// The coordinates `x0, y0, x1, y1, ...` of the input points.
  final Float64List points;

  late Uint32List _triangles;
  late Int32List _halfedges;
  late Uint32List _hull;
  late Int32List _inedges;
  Uint32List? _collinear;

  /// Point indices of the triangles, three per triangle.
  /// Empty if there are no triangles (see [collinear]).
  Uint32List get triangles => _triangles;

  /// For every edge `e` of [triangles], the opposite edge in the neighbour
  /// triangle, or -1 if `e` is on the [hull].
  Int32List get halfedges => _halfedges;

  /// Indices of the points on the convex hull, in order.
  Uint32List get hull => _hull;

  /// For every point, an edge of [triangles] that ends at it, or -1 if the
  /// point is not part of a triangle. For hull points it is an edge on the
  /// hull, so `halfedges[inedges[i]]` is -1.
  Int32List get inedges => _inedges;

  /// Set when there are no triangles because the points lie on one line (or
  /// there are fewer than three different points): the different points in
  /// order along the line. Otherwise null. [hull] is the same list then.
  Uint32List? get collinear => _collinear;

  /// Number of points.
  int get length => points.length ~/ 2;

  /// Triangulates again after the values of [points] were changed.
  void update() {
    _check();
    _init();
  }

  void _check() {
    if (points.length.isOdd) {
      throw ArgumentError.value(points.length, 'points', 'must have x and y');
    }
    for (final value in points) {
      if (!value.isFinite) {
        throw ArgumentError.value(value, 'points', 'must be finite');
      }
    }
  }

  void _init() {
    final result = triangulate(points);
    _triangles = result.triangles;
    _halfedges = result.halfedges;
    _hull = result.hull;
    _collinear = null;

    if (_triangles.isEmpty) {
      _collinear = _hull;
    } else if (_allFlat()) {
      _collinear = _hull = _alongLine();
      _triangles = Uint32List(0);
      _halfedges = Int32List(0);
    }

    // Edges that end at a point. A hull edge is preferred, so that the
    // first neighbour of a hull point is on the hull.
    _inedges = Int32List(length)..fillRange(0, length, -1);
    for (var e = 0; e < _triangles.length; e++) {
      final p = _triangles[e % 3 == 2 ? e - 2 : e + 1];
      if (_halfedges[e] == -1 || _inedges[p] == -1) _inedges[p] = e;
    }
  }

  // True if no triangle has an area (checked exactly).
  bool _allFlat() {
    for (var i = 0; i < _triangles.length; i += 3) {
      final a = 2 * _triangles[i];
      final b = 2 * _triangles[i + 1];
      final c = 2 * _triangles[i + 2];
      final turn = orient2d(
        points[a],
        points[a + 1],
        points[b],
        points[b + 1],
        points[c],
        points[c + 1],
      );
      if (turn != 0) return false;
    }
    return true;
  }

  // The different points ordered along a line: by x, then by y.
  Uint32List _alongLine() {
    final ids = List.generate(length, (i) => i)
      ..sort((a, b) {
        final byX = _compare(points[2 * a], points[2 * b]);
        if (byX != 0) return byX;
        final byY = _compare(points[2 * a + 1], points[2 * b + 1]);
        return byY != 0 ? byY : a.compareTo(b);
      });
    final line = <int>[];
    for (final id in ids) {
      final same =
          line.isNotEmpty &&
          points[2 * id] == points[2 * line.last] &&
          points[2 * id + 1] == points[2 * line.last + 1];
      if (!same) line.add(id);
    }
    return Uint32List.fromList(line);
  }
}

// Unlike double.compareTo, treats 0.0 and -0.0 as equal.
int _compare(double a, double b) => a < b ? -1 : (a > b ? 1 : 0);
