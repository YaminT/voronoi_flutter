import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_flutter/voronoi_flutter.dart';

void main() {
  testWidgets('tap reports the cell under the finger', (tester) async {
    VoronoiCell? tapped;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: VoronoiView(
              sites: const [Offset(0.25, 0.5), Offset(0.75, 0.5)],
              onCellTap: (cell) => tapped = cell,
            ),
          ),
        ),
      ),
    );

    final box = tester.getTopLeft(find.byType(VoronoiView));
    await tester.tapAt(box + const Offset(170, 50));
    expect(tapped?.index, 1);
  });
}
