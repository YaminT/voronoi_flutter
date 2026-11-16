import 'dart:math';
import 'dart:ui';

import 'package:voronoi_flutter/src/voronoi_cell.dart';

/// A Voronoi diagram of [sites], clipped to [bounds].
///
/// Each cell starts as the whole bounding rectangle and is cut by the
/// bisector line between its site and every other site. A grid is used so
/// only sites nearby are checked.
class GridVoronoi {
  GridVoronoi(List<Offset> sites, this.bounds)
    : sites = List.unmodifiable(sites),
      cells = [] {
    for (final s in this.sites) {
      if (!s.isFinite) throw ArgumentError.value(s, 'sites', 'must be finite');
    }
    if (bounds.isEmpty || !bounds.isFinite) {
      throw ArgumentError.value(
        bounds,
        'bounds',
        'must be finite and not empty',
      );
    }
    _buildGrid();
    for (var i = 0; i < this.sites.length; i++) {
      cells.add(_buildCell(i));
    }
  }

  /// Random sites inside [bounds].
  factory GridVoronoi.random(int count, Rect bounds, {int? seed}) {
    final random = Random(seed);
    final points = List.generate(
      count,
      (_) => Offset(
        bounds.left + random.nextDouble() * bounds.width,
        bounds.top + random.nextDouble() * bounds.height,
      ),
    );
    return GridVoronoi(points, bounds);
  }

  final List<Offset> sites;
  final Rect bounds;

  /// One cell per site, in the same order as [sites].
  final List<VoronoiCell> cells;

  // Sites are put in a grid so a cell only looks at sites nearby.
  late final double _gridSize;
  late final Offset _gridOrigin;
  late final int _columns;
  late final int _rows;
  late final List<List<int>> _grid;

  /// Index of the site closest to [point].
  int nearest(Offset point) {
    if (sites.isEmpty) throw StateError('The diagram has no sites.');
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < sites.length; i++) {
      final d = (sites[i] - point).distanceSquared;
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  /// Cell that contains [point].
  VoronoiCell cellAt(Offset point) => cells[nearest(point)];

  /// One step of Lloyd relaxation: moves every site to the centroid of its
  /// cell. Repeating this makes the cells more even.
  GridVoronoi relax() {
    return GridVoronoi([for (final c in cells) c.centroid], bounds);
  }

  VoronoiCell _buildCell(int index) {
    final site = sites[index];

    // Corners of the rectangle, and which site made each edge (-1 = border).
    var polygon = <Offset>[
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomRight,
      bounds.bottomLeft,
    ];
    var owners = <int>[-1, -1, -1, -1];

    var radiusSquared = _farthestCorner(site, polygon);

    final column = _column(site);
    final row = _row(site);
    final maxRing = max(_columns, _rows);

    // Visit the grid ring by ring, starting at the cell of the site.
    for (var ring = 0; ring <= maxRing; ring++) {
      // Everything in this ring is at least this far away.
      final minDistance = (ring - 1) * _gridSize;
      if (ring > 1 && minDistance * minDistance / 4 > radiusSquared) break;

      for (final j in _sitesInRing(column, row, ring)) {
        if (j == index) continue;
        final other = sites[j];
        final distanceSquared = (other - site).distanceSquared;

        // Same position: the first one keeps the cell, the other gets none.
        if (distanceSquared == 0) {
          if (j < index) return _emptyCell(index);
          continue;
        }

        // The bisector is farther than every corner, so it cuts nothing.
        if (distanceSquared / 4 > radiusSquared) continue;

        final result = _clip(polygon, owners, site, other, j);
        polygon = result.polygon;
        owners = result.owners;
        if (polygon.isEmpty) return _emptyCell(index);
        radiusSquared = _farthestCorner(site, polygon);
      }
    }

    return VoronoiCell(
      index: index,
      site: site,
      polygon: polygon,
      neighbors: owners.where((o) => o >= 0).toSet().toList()..sort(),
    );
  }

  void _buildGrid() {
    if (sites.isEmpty) {
      _gridSize = 1;
      _gridOrigin = Offset.zero;
      _columns = 1;
      _rows = 1;
      _grid = [[]];
      return;
    }
    var box = Rect.fromPoints(sites.first, sites.first);
    for (final s in sites) {
      box = Rect.fromLTRB(
        min(box.left, s.dx),
        min(box.top, s.dy),
        max(box.right, s.dx),
        max(box.bottom, s.dy),
      );
    }
    final n = sites.length;
    _gridOrigin = box.topLeft;
    _gridSize = max(
      max(sqrt(box.width * box.height / n), max(box.width, box.height) / n),
      1e-9,
    );
    _columns = (box.width / _gridSize).floor() + 1;
    _rows = (box.height / _gridSize).floor() + 1;
    _grid = List.generate(_columns * _rows, (_) => <int>[]);
    for (var i = 0; i < n; i++) {
      _grid[_row(sites[i]) * _columns + _column(sites[i])].add(i);
    }
  }

  int _column(Offset p) =>
      ((p.dx - _gridOrigin.dx) / _gridSize).floor().clamp(0, _columns - 1);

  int _row(Offset p) =>
      ((p.dy - _gridOrigin.dy) / _gridSize).floor().clamp(0, _rows - 1);

  /// Sites in the grid cells at distance [ring] from (column, row).
  Iterable<int> _sitesInRing(int column, int row, int ring) sync* {
    for (var r = row - ring; r <= row + ring; r++) {
      if (r < 0 || r >= _rows) continue;
      final onEdgeRow = r == row - ring || r == row + ring;
      // Inner rows only have their left and right end in this ring.
      final step = onEdgeRow || ring == 0 ? 1 : 2 * ring;
      for (var c = column - ring; c <= column + ring; c += step) {
        if (c < 0 || c >= _columns) continue;
        yield* _grid[r * _columns + c];
      }
    }
  }

  VoronoiCell _emptyCell(int index) => VoronoiCell(
    index: index,
    site: sites[index],
    polygon: const [],
    neighbors: const [],
  );

  double _farthestCorner(Offset site, List<Offset> polygon) {
    var farthest = 0.0;
    for (final p in polygon) {
      farthest = max(farthest, (p - site).distanceSquared);
    }
    return farthest;
  }

  /// A cut that passes through a corner leaves two equal points. Dropping
  /// the first one (and its edge) keeps sites that only touch at a corner
  /// from being counted as neighbours.
  ({List<Offset> polygon, List<int> owners}) _removeZeroEdges(
    List<Offset> polygon,
    List<int> owners,
  ) {
    final tolerance = 1e-9 * max(bounds.width, bounds.height);
    final keptPolygon = <Offset>[];
    final keptOwners = <int>[];
    for (var i = 0; i < polygon.length; i++) {
      final next = polygon[(i + 1) % polygon.length];
      if ((polygon[i] - next).distance > tolerance) {
        keptPolygon.add(polygon[i]);
        keptOwners.add(owners[i]);
      }
    }
    return (polygon: keptPolygon, owners: keptOwners);
  }

  /// Keeps the part of [polygon] that is closer to [site] than to [other].
  /// Edges created by the cut are marked with [otherIndex].
  ({List<Offset> polygon, List<int> owners}) _clip(
    List<Offset> polygon,
    List<int> owners,
    Offset site,
    Offset other,
    int otherIndex,
  ) {
    final middle = (site + other) / 2;
    final direction = other - site;

    // Negative or zero means: on the side of [site].
    double side(Offset p) =>
        (p.dx - middle.dx) * direction.dx + (p.dy - middle.dy) * direction.dy;

    final newPolygon = <Offset>[];
    final newOwners = <int>[];

    for (var i = 0; i < polygon.length; i++) {
      final current = polygon[i];
      final next = polygon[(i + 1) % polygon.length];
      final currentSide = side(current);
      final nextSide = side(next);
      final currentInside = currentSide <= 0;
      final nextInside = nextSide <= 0;

      if (currentInside) {
        newPolygon.add(current);
        newOwners.add(owners[i]);
      }
      if (currentInside != nextInside) {
        final t = currentSide / (currentSide - nextSide);
        final crossing = current + (next - current) * t;
        newPolygon.add(crossing);
        // Leaving the cell: the next edge runs along the bisector.
        // Entering the cell: the next edge is the rest of the old edge.
        newOwners.add(currentInside ? otherIndex : owners[i]);
      }
    }

    return _removeZeroEdges(newPolygon, newOwners);
  }
}
