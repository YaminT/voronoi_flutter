import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_flutter/voronoi_flutter.dart';

void main() {
  final voronoi = Voronoi([
    const Offset(25, 50),
    const Offset(75, 50),
  ], const Rect.fromLTWH(0, 0, 100, 100));
  const style = VoronoiStyle(
    colors: [Color(0xFFFF0000), Color(0xFF0000FF)],
    borderWidth: 0,
    showSites: false,
  );

  testWidgets('renders each cell in its color', (tester) async {
    await tester.runAsync(() async {
      final image = await voronoiToImage(voronoi, style: style);
      final data = (await image.toByteData())!;
      int pixel(int x, int y) {
        final i = (y * 100 + x) * 4;
        return data.getUint8(i) << 16 | data.getUint8(i + 2);
      }

      expect(image.width, 100);
      expect(pixel(10, 10), 0xFF0000); // left cell: red
      expect(pixel(90, 90), 0x0000FF); // right cell: blue
    });
  });

  testWidgets('bounds that do not start at (0, 0)', (tester) async {
    await tester.runAsync(() async {
      final shifted = Voronoi([
        const Offset(-75, 0),
        const Offset(-25, 0),
      ], const Rect.fromLTRB(-100, -50, 0, 50));
      final image = await voronoiToImage(shifted, style: style);
      final data = (await image.toByteData())!;
      expect(image.width, 100);
      expect(image.height, 100);
      expect(data.getUint8(0), 0xFF); // top left: red
      expect(data.getUint8((99 * 4) + 2), 0xFF); // top right: blue
    });
  });

  test('empty colors are rejected', () {
    expect(
      () => paintVoronoi(
        Canvas(PictureRecorder()),
        voronoi,
        style: const VoronoiStyle(colors: []),
      ),
      throwsArgumentError,
    );
  });
}
