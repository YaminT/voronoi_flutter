import 'package:flutter/material.dart';

import 'voronoi.dart';
import 'voronoi_cell.dart';

/// Draws a Voronoi diagram that fills the available space.
///
/// [sites] use unit coordinates: (0, 0) is the top left and (1, 1) the
/// bottom right, so the diagram keeps its shape when the widget is resized.
class VoronoiView extends StatefulWidget {
  const VoronoiView({
    super.key,
    required this.sites,
    this.colors = _defaultColors,
    this.borderColor = Colors.white,
    this.borderWidth = 2,
    this.siteColor = Colors.black87,
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

  static const _defaultColors = [
    Color(0xFF8ECAE6),
    Color(0xFF219EBC),
    Color(0xFFFFB703),
    Color(0xFFFB8500),
    Color(0xFFB5E48C),
    Color(0xFFF4A6C0),
  ];

  @override
  State<VoronoiView> createState() => _VoronoiViewState();
}

class _VoronoiViewState extends State<VoronoiView> {
  Voronoi? _voronoi;
  List<Offset>? _lastSites;
  Size? _lastSize;

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
            painter: _VoronoiPainter(voronoi, widget),
          ),
        );
      },
    );
  }
}

class _VoronoiPainter extends CustomPainter {
  _VoronoiPainter(this.voronoi, this.view);

  final Voronoi voronoi;
  final VoronoiView view;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = view.borderWidth
      ..color = view.borderColor;

    for (final cell in voronoi.cells) {
      final path = cell.toPath();
      fill.color = view.colors[cell.index % view.colors.length];
      canvas.drawPath(path, fill);
      canvas.drawPath(path, border);
    }

    if (view.showSites) {
      final dot = Paint()..color = view.siteColor;
      for (final site in voronoi.sites) {
        canvas.drawCircle(site, view.siteRadius, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_VoronoiPainter old) =>
      old.voronoi != voronoi ||
      old.view.colors != view.colors ||
      old.view.borderColor != view.borderColor ||
      old.view.borderWidth != view.borderWidth ||
      old.view.siteColor != view.siteColor ||
      old.view.siteRadius != view.siteRadius ||
      old.view.showSites != view.showSites;
}
