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
  late Int32List _hullIndex;
  late Int32List _linePosition;
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

  /// Indices of the points that share an edge with point [i].
  ///
  /// For points on a line these are the previous and the next one. A point
  /// that is equal to an earlier point has none.
  Iterable<int> neighbors(int i) sync* {
    RangeError.checkValueInInterval(i, 0, length - 1, 'i');
    final line = _collinear;
    if (line != null) {
      final k = _linePosition[i];
      if (k > 0) yield line[k - 1];
      if (k != -1 && k < line.length - 1) yield line[k + 1];
      return;
    }

    final first = _inedges[i];
    if (first == -1) return;
    var e = first;
    var previous = -1;
    do {
      yield previous = _triangles[e];
      e = e % 3 == 2 ? e - 2 : e + 1;
      if (_triangles[e] != i) return;
      e = _halfedges[e];
      if (e == -1) {
        // On the hull: the fan is open, so add the next hull point.
        final p = _hull[(_hullIndex[i] + 1) % _hull.length];
        if (p != previous) yield p;
        return;
      }
    } while (e != first);
  }

  /// Index of the point closest to [point], or -1 if there are no points.
  ///
  /// The search walks from the point [start] towards [point] along the edges
  /// of the triangulation, so a [start] near [point] makes it fast.
  int find(Offset point, [int start = 0]) {
    if (length == 0 || point.dx.isNaN || point.dy.isNaN) return -1;
    RangeError.checkValueInInterval(start, 0, length - 1, 'start');
    if (_collinear != null) return _findOnLine(point, start);

    var i = start;
    int c;
    while ((c = _step(i, point)) != i && c != start) {
      i = c;
    }
    return c;
  }

  // The neighbour of [i] closest to [point] if it is closer than [i].
  int _step(int i, Offset point) {
    if (_inedges[i] == -1) return (i + 1) % length;
    var best = i;
    var bestDistance = _distance(i, point);
    final first = _inedges[i];
    var e = first;
    do {
      final t = _triangles[e];
      final d = _distance(t, point);
      if (d < bestDistance) {
        bestDistance = d;
        best = t;
      }
      e = e % 3 == 2 ? e - 2 : e + 1;
      if (_triangles[e] != i) break;
      e = _halfedges[e];
      if (e == -1) {
        final p = _hull[(_hullIndex[i] + 1) % _hull.length];
        if (p != t && _distance(p, point) < bestDistance) return p;
        break;
      }
    } while (e != first);
    return best;
  }

  // On a line the distance only gets smaller until the closest point.
  int _findOnLine(Offset point, int start) {
    final line = _collinear!;
    var k = _linePosition[start];
    if (k == -1) k = 0;
    var best = _distance(line[k], point);
    while (true) {
      final before = k > 0 ? _distance(line[k - 1], point) : double.infinity;
      final after = k < line.length - 1
          ? _distance(line[k + 1], point)
          : double.infinity;
      if (before < best && before <= after) {
        k--;
        best = before;
      } else if (after < best) {
        k++;
        best = after;
      } else {
        return line[k];
      }
    }
  }

  double _distance(int i, Offset point) {
    final dx = point.dx - points[2 * i];
    final dy = point.dy - points[2 * i + 1];
    return dx * dx + dy * dy;
  }

  /// Adds the edges of the triangulation, including the hull, to [path].
  /// Without [path] a new one is made. The path is returned.
  Path render([Path? path]) {
    path ??= Path();
    for (var i = 0; i < _halfedges.length; i++) {
      final j = _halfedges[i];
      if (j < i) continue;
      path
        ..moveTo(points[2 * _triangles[i]], points[2 * _triangles[i] + 1])
        ..lineTo(points[2 * _triangles[j]], points[2 * _triangles[j] + 1]);
    }
    return renderHull(path);
  }

  /// Adds the outline of the convex hull to [path] (see [render]).
  Path renderHull([Path? path]) {
    path ??= Path();
    if (_hull.isEmpty) return path;
    return path..addPolygon(hullPolygon(), true);
  }

  /// Adds triangle [t] to [path] (see [render]).
  Path renderTriangle(int t, [Path? path]) {
    return (path ?? Path())..addPolygon(trianglePolygon(t), true);
  }

  /// Adds a circle of [radius] for every point to [path] (see [render]).
  Path renderPoints([Path? path, double radius = 2]) {
    path ??= Path();
    for (var i = 0; i < length; i++) {
      path.addOval(
        Rect.fromCircle(
          center: Offset(points[2 * i], points[2 * i + 1]),
          radius: radius,
        ),
      );
    }
    return path;
  }

  /// The corners of the convex hull in order. Unlike d3, the first corner
  /// is not repeated at the end.
  List<Offset> hullPolygon() => [for (final i in _hull) _point(i)];

  /// The corners of triangle [t], which is made of the point indices
  /// `triangles[3 * t]` to `triangles[3 * t + 2]`.
  List<Offset> trianglePolygon(int t) {
    RangeError.checkValueInInterval(t, 0, _triangles.length ~/ 3 - 1, 't');
    return [for (var k = 0; k < 3; k++) _point(_triangles[3 * t + k])];
  }

  /// All triangles as lists of corners.
  Iterable<List<Offset>> trianglePolygons() sync* {
    for (var t = 0; t < _triangles.length ~/ 3; t++) {
      yield trianglePolygon(t);
    }
  }

  Offset _point(int i) => Offset(points[2 * i], points[2 * i + 1]);

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

    _hullIndex = Int32List(length)..fillRange(0, length, -1);
    for (var k = 0; k < _hull.length; k++) {
      _hullIndex[_hull[k]] = k;
    }
    _linePosition = Int32List(length)..fillRange(0, length, -1);
    final line = _collinear;
    if (line != null) {
      for (var k = 0; k < line.length; k++) {
        _linePosition[line[k]] = k;
      }
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
