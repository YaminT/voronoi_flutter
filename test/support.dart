import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

List<Offset> randomPoints(int count, Rect bounds, int seed) {
  final random = Random(seed);
  return List.generate(
    count,
    (_) => Offset(
      bounds.left + random.nextDouble() * bounds.width,
      bounds.top + random.nextDouble() * bounds.height,
    ),
  );
}

double polygonArea(List<Offset> points) {
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    final q = points[(i + 1) % points.length];
    sum += p.dx * q.dy - q.dx * p.dy;
  }
  return sum.abs() / 2;
}

/// Sign of the turn a -> b -> c, computed exactly: 1 left, -1 right, 0 straight.
int exactOrient(Offset a, Offset b, Offset c) {
  final v = _exact([a.dx, a.dy, b.dx, b.dy, c.dx, c.dy]);
  final det = (v[2] - v[0]) * (v[5] - v[1]) - (v[3] - v[1]) * (v[4] - v[0]);
  return det.sign;
}

/// True if [p] is strictly inside the circle through a, b and c.
bool inCircumcircle(Offset a, Offset b, Offset c, Offset p) {
  final v = _exact([a.dx, a.dy, b.dx, b.dy, c.dx, c.dy, p.dx, p.dy]);
  final adx = v[0] - v[6], ady = v[1] - v[7];
  final bdx = v[2] - v[6], bdy = v[3] - v[7];
  final cdx = v[4] - v[6], cdy = v[5] - v[7];
  final det =
      (adx * adx + ady * ady) * (bdx * cdy - cdx * bdy) -
      (bdx * bdx + bdy * bdy) * (adx * cdy - cdx * ady) +
      (cdx * cdx + cdy * cdy) * (adx * bdy - bdx * ady);
  return det * BigInt.from(exactOrient(a, b, c)) > BigInt.zero;
}

// Every double is mantissa * 2^exponent. Scaling all values by the same
// power of two makes them integers without changing any sign.
List<BigInt> _exact(List<double> values) {
  final parts = values.map(_split).toList();
  final lowest = parts.map((p) => p.$2).reduce(min);
  return [
    for (final (mantissa, exponent) in parts) mantissa << (exponent - lowest),
  ];
}

(BigInt, int) _split(double x) {
  final bits = (ByteData(8)..setFloat64(0, x)).getUint64(0);
  final exponentBits = (bits >> 52) & 0x7ff;
  final fraction = bits & 0xfffffffffffff;
  var mantissa = exponentBits == 0 ? fraction : fraction | (1 << 52);
  if (bits >> 63 == 1) mantissa = -mantissa;
  final exponent = (exponentBits == 0 ? 1 : exponentBits) - 1075;
  return (BigInt.from(mantissa), exponent);
}
