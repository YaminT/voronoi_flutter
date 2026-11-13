import 'dart:ui';

/// One region of the diagram: every point closer to [site] than to any other site.
class VoronoiCell {
  VoronoiCell({
    required this.index,
    required this.site,
    required this.polygon,
    required this.neighbors,
  });

  /// Position of the site in the input list.
  final int index;

  final Offset site;

  /// Corners of the cell, in order. Empty if the site was a duplicate.
  final List<Offset> polygon;

  /// Indices of the sites that share an edge with this cell.
  final List<int> neighbors;

  bool get isEmpty => polygon.isEmpty;

  /// Area of the cell (shoelace formula).
  double get area => _signedArea().abs();

  /// Center of mass of the cell. Falls back to [site] for empty cells.
  Offset get centroid {
    final a = _signedArea();
    if (polygon.length < 3 || a.abs() < 1e-12) return site;
    var cx = 0.0;
    var cy = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final p = polygon[i];
      final q = polygon[(i + 1) % polygon.length];
      final cross = p.dx * q.dy - q.dx * p.dy;
      cx += (p.dx + q.dx) * cross;
      cy += (p.dy + q.dy) * cross;
    }
    return Offset(cx / (6 * a), cy / (6 * a));
  }

  /// A [Path] of the cell, ready to draw.
  Path toPath() {
    final path = Path();
    if (polygon.isEmpty) return path;
    path.moveTo(polygon.first.dx, polygon.first.dy);
    for (final p in polygon.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  double _signedArea() {
    var sum = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final p = polygon[i];
      final q = polygon[(i + 1) % polygon.length];
      sum += p.dx * q.dy - q.dx * p.dy;
    }
    return sum / 2;
  }
}
