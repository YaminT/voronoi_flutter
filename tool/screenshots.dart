// Makes the images in doc/.  Run: flutter test tool/screenshots.dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_flutter/voronoi_flutter.dart';

void main() {
  testWidgets('make screenshots', (tester) async {
    await tester.runAsync(() async {
      const bounds = Rect.fromLTWH(0, 0, 600, 400);
      const style = VoronoiStyle(borderWidth: 3, siteRadius: 5);

      var voronoi = Voronoi.random(30, bounds, seed: 7);
      await _save(voronoi, style, 'doc/random.png');

      for (var i = 0; i < 5; i++) {
        voronoi = voronoi.relax();
      }
      await _save(voronoi, style, 'doc/relaxed.png');
    });
  });
}

Future<void> _save(Voronoi voronoi, VoronoiStyle style, String path) async {
  final image = await voronoiToImage(voronoi, style: style);
  final bytes = await image.toByteData(format: ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}
