import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_flutter/voronoi_flutter.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 0, 100, 100);

  test('one site gets the whole rectangle', () {
    final v = Voronoi([const Offset(30, 40)], bounds);
    expect(v.cells.single.area, closeTo(10000, 1e-9));
    expect(v.cells.single.neighbors, isEmpty);
  });

  test('two sites split the rectangle in half', () {
    final v = Voronoi([const Offset(25, 50), const Offset(75, 50)], bounds);
    expect(v.cells[0].area, closeTo(5000, 1e-9));
    expect(v.cells[1].area, closeTo(5000, 1e-9));
    expect(v.cells[0].neighbors, [1]);
    expect(v.cells[1].neighbors, [0]);
  });

  test('cell areas add up to the rectangle', () {
    final v = Voronoi.random(200, bounds, seed: 1);
    final total = v.cells.fold<double>(0, (sum, c) => sum + c.area);
    expect(total, closeTo(10000, 1e-6));
  });

  test('the cell found by cellAt contains the point', () {
    final v = Voronoi.random(50, bounds, seed: 2);
    final random = Random(3);
    for (var i = 0; i < 500; i++) {
      final p = Offset(random.nextDouble() * 100, random.nextDouble() * 100);
      final cell = v.cellAt(p);
      expect(cell.toPath().contains(p), isTrue);
    }
  });

  test('neighbours are symmetric', () {
    final v = Voronoi.random(100, bounds, seed: 4);
    for (final cell in v.cells) {
      for (final n in cell.neighbors) {
        expect(v.cells[n].neighbors, contains(cell.index));
      }
    }
  });

  test('duplicate sites: the second one gets an empty cell', () {
    final v = Voronoi([
      const Offset(10, 10),
      const Offset(10, 10),
      const Offset(80, 80),
    ], bounds);
    expect(v.cells[0].isEmpty, isFalse);
    expect(v.cells[1].isEmpty, isTrue);
    final total = v.cells.fold<double>(0, (sum, c) => sum + c.area);
    expect(total, closeTo(10000, 1e-6));
  });

  test('relax keeps the area and evens out the cells', () {
    var v = Voronoi.random(60, bounds, seed: 5);
    double spread(Voronoi d) {
      final areas = d.cells.map((c) => c.area).toList();
      final mean = areas.reduce((a, b) => a + b) / areas.length;
      return areas.map((a) => (a - mean) * (a - mean)).reduce((a, b) => a + b);
    }

    final before = spread(v);
    for (var i = 0; i < 10; i++) {
      v = v.relax();
    }
    expect(spread(v), lessThan(before));
    expect(v.cells.fold<double>(0, (s, c) => s + c.area), closeTo(10000, 1e-6));
  });

  test('nearest throws without sites', () {
    expect(() => Voronoi([], bounds).nearest(Offset.zero), throwsStateError);
  });

  test('sites on one line still fill the rectangle', () {
    final v = Voronoi([
      for (var i = 1; i < 20; i++) Offset(i * 5.0, 50),
    ], bounds);
    expect(v.cells.fold<double>(0, (s, c) => s + c.area), closeTo(10000, 1e-6));
  });

  test('sites outside the rectangle do not break the clipping', () {
    final v = Voronoi([
      const Offset(-50, 50),
      const Offset(50, 50),
      const Offset(150, 50),
    ], bounds);
    expect(v.cells.fold<double>(0, (s, c) => s + c.area), closeTo(10000, 1e-6));
    expect(v.cells[1].area, closeTo(10000, 1e-6));
  });
}
