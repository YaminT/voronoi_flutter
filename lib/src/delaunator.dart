// Delaunay triangulation by sweep-hull, ported from Delaunator
// (https://github.com/mapbox/delaunator).
import 'dart:math';
import 'dart:typed_data';

import 'orient.dart';

/// Triangles are listed as point indices, three per triangle. `halfedges[e]`
/// is the opposite edge of edge `e` in the neighbouring triangle, or -1 on
/// the hull. `hull` holds the points of the convex hull in order.
typedef Triangulation = ({
  Uint32List triangles,
  Int32List halfedges,
  Uint32List hull,
});

/// [coords] is x0, y0, x1, y1, ... Of equal points the lowest index is used.
/// Points on one line give no triangles; the hull is the line in order.
Triangulation triangulate(Float64List coords) => _Triangulator(coords).run();

const _epsilon = 2.220446049250313e-16;

class _Triangulator {
  _Triangulator(this.coords)
    : n = coords.length ~/ 2,
      _triangles = Uint32List(max(coords.length ~/ 2 * 2 - 5, 0) * 3),
      _halfedges = Int32List(max(coords.length ~/ 2 * 2 - 5, 0) * 3),
      _hashSize = max(sqrt(coords.length ~/ 2).ceil(), 1),
      _hullPrev = Uint32List(coords.length ~/ 2),
      _hullNext = Uint32List(coords.length ~/ 2),
      _hullTri = Uint32List(coords.length ~/ 2),
      _dists = Float64List(coords.length ~/ 2),
      _ids = List.generate(coords.length ~/ 2, (i) => i) {
    _hullHash = Int32List(_hashSize)..fillRange(0, _hashSize, -1);
  }

  final Float64List coords;
  final int n;
  final Uint32List _triangles;
  final Int32List _halfedges;
  final int _hashSize;
  final Uint32List _hullPrev;
  final Uint32List _hullNext;
  final Uint32List _hullTri;
  final Float64List _dists;
  final List<int> _ids;
  late final Int32List _hullHash;
  final _edgeStack = Uint32List(512);

  var _trianglesLength = 0;
  var _hullStart = 0;
  var _cx = 0.0;
  var _cy = 0.0;

  Triangulation run() {
    if (n == 0) return _line();

    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < n; i++) {
      minX = min(minX, coords[2 * i]);
      minY = min(minY, coords[2 * i + 1]);
      maxX = max(maxX, coords[2 * i]);
      maxY = max(maxY, coords[2 * i + 1]);
    }

    // Seed triangle: a point near the center, its closest point, and the
    // third point that makes the smallest circumcircle with them.
    final i0 = _closestTo((minX + maxX) / 2, (minY + maxY) / 2, -1);
    final i0x = coords[2 * i0];
    final i0y = coords[2 * i0 + 1];
    var i1 = _closestTo(i0x, i0y, i0, skipEqual: true);
    if (i1 == -1) return _line();
    var i1x = coords[2 * i1];
    var i1y = coords[2 * i1 + 1];

    var i2 = -1;
    var minRadius = double.infinity;
    for (var i = 0; i < n; i++) {
      if (i == i0 || i == i1) continue;
      final r = _circumradius(
        i0x,
        i0y,
        i1x,
        i1y,
        coords[2 * i],
        coords[2 * i + 1],
      );
      if (r < minRadius) {
        i2 = i;
        minRadius = r;
      }
    }
    if (minRadius == double.infinity) return _line();
    var i2x = coords[2 * i2];
    var i2y = coords[2 * i2 + 1];

    if (orient2d(i0x, i0y, i1x, i1y, i2x, i2y) < 0) {
      (i1, i2) = (i2, i1);
      (i1x, i2x) = (i2x, i1x);
      (i1y, i2y) = (i2y, i1y);
    }

    _setCenter(i0x, i0y, i1x, i1y, i2x, i2y);
    for (var i = 0; i < n; i++) {
      _dists[i] = _distance(coords[2 * i], coords[2 * i + 1], _cx, _cy);
    }
    _ids.sort((a, b) {
      final byDistance = _compare(_dists[a], _dists[b]);
      if (byDistance != 0) return byDistance;
      final byX = _compare(coords[2 * a], coords[2 * b]);
      if (byX != 0) return byX;
      final byY = _compare(coords[2 * a + 1], coords[2 * b + 1]);
      return byY != 0 ? byY : a.compareTo(b);
    });

    // The seed triangle is the first hull.
    _hullStart = i0;
    var hullSize = 3;
    _hullNext[i0] = _hullPrev[i2] = i1;
    _hullNext[i1] = _hullPrev[i0] = i2;
    _hullNext[i2] = _hullPrev[i1] = i0;
    _hullTri[i0] = 0;
    _hullTri[i1] = 1;
    _hullTri[i2] = 2;
    _hullHash[_hashKey(i0x, i0y)] = i0;
    _hullHash[_hashKey(i1x, i1y)] = i1;
    _hullHash[_hashKey(i2x, i2y)] = i2;
    _addTriangle(i0, i1, i2, -1, -1, -1);

    double previousX = double.nan, previousY = double.nan;
    for (final i in _ids) {
      final x = coords[2 * i];
      final y = coords[2 * i + 1];

      // Skip points equal to the one before. The sort puts the lowest index first.
      if ((x - previousX).abs() <= _epsilon &&
          (y - previousY).abs() <= _epsilon) {
        continue;
      }
      previousX = x;
      previousY = y;
      if (i == i0 || i == i1 || i == i2) continue;

      // Find an edge of the hull that the point can see.
      var start = 0;
      final key = _hashKey(x, y);
      for (var j = 0; j < _hashSize; j++) {
        start = _hullHash[(key + j) % _hashSize];
        if (start != -1 && start != _hullNext[start]) break;
      }
      if (start == -1) start = _hullStart;
      start = _hullPrev[start];

      var e = start;
      var q = _hullNext[e];
      while (_orient(x, y, e, q) >= 0) {
        e = q;
        if (e == start) {
          e = -1;
          break;
        }
        q = _hullNext[e];
      }
      if (e == -1) continue;

      var t = _addTriangle(e, i, _hullNext[e], -1, -1, _hullTri[e]);
      _hullTri[i] = _legalize(t + 2);
      _hullTri[e] = t;
      hullSize++;

      // Walk forward along the hull, adding triangles.
      var next = _hullNext[e];
      q = _hullNext[next];
      while (_orient(x, y, next, q) < 0) {
        t = _addTriangle(next, i, q, _hullTri[i], -1, _hullTri[next]);
        _hullTri[i] = _legalize(t + 2);
        _hullNext[next] = next;
        hullSize--;
        next = q;
        q = _hullNext[next];
      }

      // Walk backward from the other side.
      if (e == start) {
        q = _hullPrev[e];
        while (_orient(x, y, q, e) < 0) {
          t = _addTriangle(q, i, e, -1, _hullTri[e], _hullTri[q]);
          _legalize(t + 2);
          _hullTri[q] = t;
          _hullNext[e] = e;
          hullSize--;
          e = q;
          q = _hullPrev[e];
        }
      }

      _hullStart = _hullPrev[i] = e;
      _hullNext[e] = _hullPrev[next] = i;
      _hullNext[i] = next;
      _hullHash[_hashKey(x, y)] = i;
      _hullHash[_hashKey(coords[2 * e], coords[2 * e + 1])] = e;
    }

    final hull = Uint32List(hullSize);
    var e = _hullStart;
    for (var i = 0; i < hullSize; i++) {
      hull[i] = e;
      e = _hullNext[e];
    }
    return (
      triangles: Uint32List.sublistView(_triangles, 0, _trianglesLength),
      halfedges: Int32List.sublistView(_halfedges, 0, _trianglesLength),
      hull: hull,
    );
  }

  // Index of the point closest to (x, y); the lowest index wins a tie.
  int _closestTo(double x, double y, int skip, {bool skipEqual = false}) {
    var best = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < n; i++) {
      if (i == skip) continue;
      final d = _distance(coords[2 * i], coords[2 * i + 1], x, y);
      if (skipEqual && d == 0) continue;
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  // All points on one line (or fewer than three): no triangles.
  Triangulation _line() {
    for (var i = 0; i < n; i++) {
      final dx = coords[2 * i] - coords[0];
      _dists[i] = dx != 0 ? dx : coords[2 * i + 1] - coords[1];
    }
    _ids.sort((a, b) {
      final byPosition = _compare(_dists[a], _dists[b]);
      return byPosition != 0 ? byPosition : a.compareTo(b);
    });
    final hull = <int>[];
    var previous = -double.infinity;
    for (final id in _ids) {
      if (_dists[id] > previous) {
        hull.add(id);
        previous = _dists[id];
      }
    }
    return (
      triangles: Uint32List(0),
      halfedges: Int32List(0),
      hull: Uint32List.fromList(hull),
    );
  }

  double _orient(double x, double y, int a, int b) => orient2d(
    x,
    y,
    coords[2 * a],
    coords[2 * a + 1],
    coords[2 * b],
    coords[2 * b + 1],
  );

  int _hashKey(double x, double y) {
    final angle = _pseudoAngle(x - _cx, y - _cy);
    return (angle * _hashSize).floor() % _hashSize;
  }

  // Flips edges that break the Delaunay condition. Returns the edge that
  // ends up on the left of the first one.
  int _legalize(int a) {
    var i = 0;
    var ar = 0;
    while (true) {
      final b = _halfedges[a];

      //           pl                    pl
      //          /||\                  /  \
      //       al/ || \bl            al/    \a
      //        /  ||  \              /      \
      //       /  a||b  \    flip    /___ar___\
      //     p0\   ||   /p1   =>   p0\---bl---/p1
      //        \  ||  /              \      /
      //       ar\ || /br             b\    /br
      //          \||/                  \  /
      //           pr                    pr
      final a0 = a - a % 3;
      ar = a0 + (a + 2) % 3;

      if (b == -1) {
        if (i == 0) break;
        a = _edgeStack[--i];
        continue;
      }

      final b0 = b - b % 3;
      final al = a0 + (a + 1) % 3;
      final bl = b0 + (b + 2) % 3;
      final p0 = _triangles[ar];
      final pr = _triangles[a];
      final pl = _triangles[al];
      final p1 = _triangles[bl];

      if (_inCircle(p0, pr, pl, p1)) {
        _triangles[a] = p1;
        _triangles[b] = p0;
        final hbl = _halfedges[bl];

        // The flipped edge was on the hull; fix the reference to it.
        if (hbl == -1) {
          var e = _hullStart;
          do {
            if (_hullTri[e] == bl) {
              _hullTri[e] = a;
              break;
            }
            e = _hullPrev[e];
          } while (e != _hullStart);
        }
        _link(a, hbl);
        _link(b, _halfedges[ar]);
        _link(ar, bl);

        final br = b0 + (b + 1) % 3;
        if (i < _edgeStack.length) _edgeStack[i++] = br;
      } else {
        if (i == 0) break;
        a = _edgeStack[--i];
      }
    }
    return ar;
  }

  bool _inCircle(int a, int b, int c, int p) {
    final px = coords[2 * p], py = coords[2 * p + 1];
    final dx = coords[2 * a] - px, dy = coords[2 * a + 1] - py;
    final ex = coords[2 * b] - px, ey = coords[2 * b + 1] - py;
    final fx = coords[2 * c] - px, fy = coords[2 * c + 1] - py;
    final ap = dx * dx + dy * dy;
    final bp = ex * ex + ey * ey;
    final cp = fx * fx + fy * fy;
    return dx * (ey * cp - bp * fy) -
            dy * (ex * cp - bp * fx) +
            ap * (ex * fy - ey * fx) <
        0;
  }

  void _link(int a, int b) {
    _halfedges[a] = b;
    if (b != -1) _halfedges[b] = a;
  }

  int _addTriangle(int i0, int i1, int i2, int a, int b, int c) {
    final t = _trianglesLength;
    _triangles[t] = i0;
    _triangles[t + 1] = i1;
    _triangles[t + 2] = i2;
    _link(t, a);
    _link(t + 1, b);
    _link(t + 2, c);
    _trianglesLength += 3;
    return t;
  }

  void _setCenter(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
  ) {
    final dx = bx - ax, dy = by - ay;
    final ex = cx - ax, ey = cy - ay;
    final bl = dx * dx + dy * dy;
    final cl = ex * ex + ey * ey;
    final d = 0.5 / (dx * ey - dy * ex);
    _cx = ax + (ey * bl - dy * cl) * d;
    _cy = ay + (dx * cl - ex * bl) * d;
  }
}

// Grows with the real angle, without trigonometry. Range 0 to 1.
double _pseudoAngle(double dx, double dy) {
  final total = dx.abs() + dy.abs();
  if (total == 0) return 0;
  final p = dx / total;
  return (dy > 0 ? 3 - p : 1 + p) / 4;
}

double _distance(double ax, double ay, double bx, double by) {
  final dx = ax - bx, dy = ay - by;
  return dx * dx + dy * dy;
}

// Squared circumradius; infinite or NaN for points on one line.
double _circumradius(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
) {
  final dx = bx - ax, dy = by - ay;
  final ex = cx - ax, ey = cy - ay;
  final bl = dx * dx + dy * dy;
  final cl = ex * ex + ey * ey;
  final d = 0.5 / (dx * ey - dy * ex);
  final x = (ey * bl - dy * cl) * d;
  final y = (dx * cl - ex * bl) * d;
  return x * x + y * y;
}

// Unlike double.compareTo, treats 0.0 and -0.0 as equal.
int _compare(double a, double b) => a < b ? -1 : (a > b ? 1 : 0);
