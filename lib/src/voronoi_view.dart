import 'package:flutter/widgets.dart';

import 'voronoi.dart';
import 'voronoi_cell.dart';
import 'voronoi_painter.dart';

/// Draws a Voronoi diagram that fills the available space.
///
/// [sites] use unit coordinates: (0, 0) is the top left and (1, 1) the
/// bottom right, so the diagram keeps its shape when the widget is resized.
/// Pass a new list when the sites change; changing the same list is not noticed.
class VoronoiView extends StatefulWidget {
  const VoronoiView({
    super.key,
    required this.sites,
    this.colors = VoronoiStyle.defaultColors,
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = 2,
    this.siteColor = const Color(0xDD000000),
    this.siteRadius = 3,
    this.showSites = true,
    this.onCellTap,
  });

  final List<Offset> sites;

  /// Cell colors, picked by cell index (repeats if there are more cells).
  final List<Color> colors;

  final Color borderColor;
  final double borderWidth;
  final Color siteColor;
  final double siteRadius;
  final bool showSites;

  /// Called with the tapped cell.
  final ValueChanged<VoronoiCell>? onCellTap;

  @override
  State<VoronoiView> createState() => _VoronoiViewState();
}

class _VoronoiViewState extends State<VoronoiView> {
  Voronoi? _voronoi;
  List<Offset>? _lastSites;
  Size? _lastSize;

  // Same style object while the settings stay the same, so repaint is skipped.
  VoronoiStyle? _cachedStyle;

  VoronoiStyle get _style {
    final w = widget;
    final c = _cachedStyle;
    if (c == null ||
        c.colors != w.colors ||
        c.borderColor != w.borderColor ||
        c.borderWidth != w.borderWidth ||
        c.siteColor != w.siteColor ||
        c.siteRadius != w.siteRadius ||
        c.showSites != w.showSites) {
      _cachedStyle = VoronoiStyle(
        colors: w.colors,
        borderColor: w.borderColor,
        borderWidth: w.borderWidth,
        siteColor: w.siteColor,
        siteRadius: w.siteRadius,
        showSites: w.showSites,
      );
    }
    return _cachedStyle!;
  }

  Voronoi _diagram(Size size) {
    final changed =
        _voronoi == null ||
        !identical(_lastSites, widget.sites) ||
        _lastSize != size;
    if (changed) {
      final points = [
        for (final s in widget.sites)
          Offset(s.dx * size.width, s.dy * size.height),
      ];
      _voronoi = Voronoi(points, Offset.zero & size);
      _lastSites = widget.sites;
      _lastSize = size;
    }
    return _voronoi!;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || widget.sites.isEmpty) {
          return const SizedBox.shrink();
        }
        final voronoi = _diagram(size);

        return GestureDetector(
          onTapDown: widget.onCellTap == null
              ? null
              : (details) =>
                    widget.onCellTap!(voronoi.cellAt(details.localPosition)),
          child: CustomPaint(
            size: size,
            painter: _VoronoiPainter(voronoi, _style),
          ),
        );
      },
    );
  }
}

class _VoronoiPainter extends CustomPainter {
  _VoronoiPainter(this.voronoi, this.style);

  final Voronoi voronoi;
  final VoronoiStyle style;

  @override
  void paint(Canvas canvas, Size size) =>
      paintVoronoi(canvas, voronoi, style: style);

  @override
  bool shouldRepaint(_VoronoiPainter old) =>
      old.voronoi != voronoi || old.style != style;
}
