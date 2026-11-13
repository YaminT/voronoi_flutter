import 'dart:math';

import 'package:flutter/material.dart';
import 'package:voronoi_flutter/voronoi_flutter.dart';

void main() => runApp(const MaterialApp(home: ExamplePage()));

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final _random = Random();
  List<Offset> _sites = _randomSites(Random(), 40);
  int? _selected;

  static List<Offset> _randomSites(Random random, int count) => List.generate(
    count,
    (_) => Offset(random.nextDouble(), random.nextDouble()),
  );

  // Moves every site to the center of its cell, using a diagram of unit size.
  void _relax() {
    final unit = Voronoi(_sites, const Rect.fromLTWH(0, 0, 1, 1)).relax();
    setState(() => _sites = unit.sites);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selected == null ? 'Voronoi' : 'Cell $_selected'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: VoronoiView(
          sites: _sites,
          onCellTap: (cell) => setState(() => _selected = cell.index),
        ),
      ),
      persistentFooterButtons: [
        TextButton(
          onPressed: () => setState(() => _sites = _randomSites(_random, 40)),
          child: const Text('New points'),
        ),
        TextButton(onPressed: _relax, child: const Text('Relax')),
      ],
    );
  }
}
