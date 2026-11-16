## 1.0.1

- Fix: sites that only touch at a corner were listed as neighbours, with duplicate corners in the polygon.
- Fix: `voronoiToImage` and `voronoiToPicture` now work for bounds that do not start at (0, 0).
- Clear `ArgumentError` for NaN or infinite sites and for empty bounds.
- `paintVoronoi` throws `ArgumentError` if `VoronoiStyle.colors` is empty.
- Docs: `isEmpty`, `VoronoiView.sites`.
- GitHub Actions CI.

## 1.0.0

- Voronoi diagram from a list of points, clipped to a rectangle.
- Nearest cell lookup, neighbours, Lloyd relaxation.
- `VoronoiView` widget.
- Engine-only drawing (`dart:ui`): `paintVoronoi`, `voronoiToPicture`, `voronoiToImage`.
- Updated for the current Flutter and Dart versions.
