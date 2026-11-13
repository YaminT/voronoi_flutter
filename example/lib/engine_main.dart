// Draws a Voronoi diagram with the Flutter engine only (dart:ui).
// No widgets, no framework binding.
//
//   flutter run -t lib/engine_main.dart
import 'dart:math';
import 'dart:ui';

import 'package:voronoi_flutter/voronoi_flutter.dart';

final _random = Random();
final _sites = List.generate(
  40,
  (_) => Offset(_random.nextDouble(), _random.nextDouble()),
);

Voronoi? _voronoi;
Size? _lastSize;
int? _selected;

void main() {
  final dispatcher = PlatformDispatcher.instance;
  dispatcher.onPointerDataPacket = _onPointer;
  dispatcher.onBeginFrame = (_) {};
  dispatcher.onDrawFrame = _draw;
  dispatcher.scheduleFrame();
}

void _onPointer(PointerDataPacket packet) {
  for (final data in packet.data) {
    if (data.change != PointerChange.down || _voronoi == null) continue;
    _selected = _voronoi!.nearest(Offset(data.physicalX, data.physicalY));
  }
  PlatformDispatcher.instance.scheduleFrame();
}

void _draw() {
  final view = PlatformDispatcher.instance.implicitView;
  if (view == null) return;
  final size = view.physicalSize;

  // Sites are in unit coordinates; the diagram is rebuilt when the size changes.
  if (_voronoi == null || _lastSize != size) {
    final points = [
      for (final s in _sites) Offset(s.dx * size.width, s.dy * size.height),
    ];
    _voronoi = Voronoi(points, Offset.zero & size);
    _lastSize = size;
  }

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
  paintVoronoi(
    canvas,
    _voronoi!,
    style: const VoronoiStyle(borderWidth: 4, siteRadius: 8),
    highlight: {?_selected},
  );

  final scene =
      (SceneBuilder()..addPicture(Offset.zero, recorder.endRecording()))
          .build();
  view.render(scene);
  scene.dispose();
}
