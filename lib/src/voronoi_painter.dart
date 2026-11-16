import 'dart:ui';

import 'voronoi.dart';

/// Colors and sizes used when drawing a diagram.
class VoronoiStyle {
  const VoronoiStyle({
    this.colors = defaultColors,
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = 2,
    this.siteColor = const Color(0xDD000000),
    this.siteRadius = 3,
    this.showSites = true,
  });

  /// Cell colors, picked by cell index (repeats if there are more cells).
  final List<Color> colors;
  final Color borderColor;
  final double borderWidth;
  final Color siteColor;
  final double siteRadius;
  final bool showSites;

  static const defaultColors = [
    Color(0xFF8ECAE6),
    Color(0xFF219EBC),
    Color(0xFFFFB703),
    Color(0xFFFB8500),
    Color(0xFFB5E48C),
    Color(0xFFF4A6C0),
  ];
}

/// Draws [voronoi] on [canvas]. Uses only `dart:ui`, so it works without
/// the widget layer (for example straight on the engine's scene).
///
/// Cells listed in [highlight] are drawn in [highlightColor].
void paintVoronoi(
  Canvas canvas,
  Voronoi voronoi, {
  VoronoiStyle style = const VoronoiStyle(),
  Set<int> highlight = const {},
  Color highlightColor = const Color(0xFFE63946),
}) {
  if (style.colors.isEmpty) {
    throw ArgumentError.value(
      style.colors,
      'style.colors',
      'must not be empty',
    );
  }
  final fill = Paint()..style = PaintingStyle.fill;
  final border = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = style.borderWidth
    ..color = style.borderColor;

  for (final cell in voronoi.cells) {
    final path = cell.toPath();
    fill.color = highlight.contains(cell.index)
        ? highlightColor
        : style.colors[cell.index % style.colors.length];
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  if (style.showSites) {
    final dot = Paint()..color = style.siteColor;
    for (final site in voronoi.sites) {
      canvas.drawCircle(site, style.siteRadius, dot);
    }
  }
}

/// Records the diagram into a [Picture]. The top left of the bounds
/// is drawn at (0, 0).
Picture voronoiToPicture(
  Voronoi voronoi, {
  VoronoiStyle style = const VoronoiStyle(),
}) {
  final bounds = voronoi.bounds;
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & bounds.size);
  canvas.translate(-bounds.left, -bounds.top);
  paintVoronoi(canvas, voronoi, style: style);
  return recorder.endRecording();
}

/// Renders the diagram into an [Image] the size of the bounds, for example
/// to save it as a PNG.
Future<Image> voronoiToImage(
  Voronoi voronoi, {
  VoronoiStyle style = const VoronoiStyle(),
}) {
  final picture = voronoiToPicture(voronoi, style: style);
  return picture.toImage(
    voronoi.bounds.width.ceil(),
    voronoi.bounds.height.ceil(),
  );
}
