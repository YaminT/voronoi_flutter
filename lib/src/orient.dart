// Robust orientation test, ported from robust-predicates (orient2d.js and
// util.js), which follows Shewchuk's adaptive precision arithmetic.
// The sign of the result is always right, even for nearly collinear points.
import 'dart:typed_data';

const _epsilon = 1.1102230246251565e-16;
const _splitter = 134217729.0;
const _resultErrorBound = (3 + 8 * _epsilon) * _epsilon;
const _errorBoundA = (3 + 16 * _epsilon) * _epsilon;
const _errorBoundB = (2 + 12 * _epsilon) * _epsilon;
const _errorBoundC = (9 + 64 * _epsilon) * _epsilon * _epsilon;

// One slot more than needed: the sum below reads one past the end.
final _b = Float64List(5);
final _c1 = Float64List(9);
final _c2 = Float64List(13);
final _d = Float64List(17);
final _u = Float64List(5);

/// Negative if a, b, c turn counterclockwise (c is left of the line a -> b),
/// positive if clockwise, zero if they are on one line.
/// This is the sign convention of robust-predicates and Delaunator.
double orient2d(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
) {
  final left = (ay - cy) * (bx - cx);
  final right = (ax - cx) * (by - cy);
  final det = left - right;
  final detSum = (left + right).abs();
  if (det.abs() >= _errorBoundA * detSum) return det;
  return -_orient2dAdapt(ax, ay, bx, by, cx, cy, detSum);
}

double _orient2dAdapt(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
  double detSum,
) {
  final acx = ax - cx;
  final bcx = bx - cx;
  final acy = ay - cy;
  final bcy = by - cy;

  _diffOfProducts(acx, bcy, acy, bcx, _b);
  var det = _estimate(4, _b);
  var errorBound = _errorBoundB * detSum;
  if (det >= errorBound || -det >= errorBound) return det;

  final acxTail = _tail(ax, acx, cx);
  final bcxTail = _tail(bx, bcx, cx);
  final acyTail = _tail(ay, acy, cy);
  final bcyTail = _tail(by, bcy, cy);
  if (acxTail == 0 && acyTail == 0 && bcxTail == 0 && bcyTail == 0) {
    return det;
  }

  errorBound = _errorBoundC * detSum + _resultErrorBound * det.abs();
  det += (acx * bcyTail + bcy * acxTail) - (acy * bcxTail + bcx * acyTail);
  if (det >= errorBound || -det >= errorBound) return det;

  _diffOfProducts(acxTail, bcy, acyTail, bcx, _u);
  final c1Length = _sum(4, _b, 4, _u, _c1);
  _diffOfProducts(acx, bcyTail, acy, bcxTail, _u);
  final c2Length = _sum(c1Length, _c1, 4, _u, _c2);
  _diffOfProducts(acxTail, bcyTail, acyTail, bcxTail, _u);
  final dLength = _sum(c2Length, _c2, 4, _u, _d);
  return _d[dLength - 1];
}

// Rounding error of the difference x - y, where difference = x - y.
double _tail(double x, double difference, double y) {
  final virtual = x - difference;
  return x - (difference + virtual) + (virtual - y);
}

// a * b - c * d as an exact sum of four doubles, written to [out].
void _diffOfProducts(double a, double b, double c, double d, Float64List out) {
  final s1 = a * b;
  final s0 = _productTail(a, b, s1);
  final t1 = c * d;
  final t0 = _productTail(c, d, t1);

  var i = s0 - t0;
  var virtual = s0 - i;
  out[0] = s0 - (i + virtual) + (virtual - t0);
  final j = s1 + i;
  virtual = j - s1;
  final zero = s1 - (j - virtual) + (i - virtual);
  i = zero - t1;
  virtual = zero - i;
  out[1] = zero - (i + virtual) + (virtual - t1);
  final last = j + i;
  virtual = last - j;
  out[2] = j - (last - virtual) + (i - virtual);
  out[3] = last;
}

// Rounding error of the product a * b, where product = a * b.
double _productTail(double a, double b, double product) {
  var c = _splitter * a;
  final aHigh = c - (c - a);
  final aLow = a - aHigh;
  c = _splitter * b;
  final bHigh = c - (c - b);
  final bLow = b - bHigh;
  return aLow * bLow - (product - aHigh * bHigh - aLow * bHigh - aHigh * bLow);
}

double _estimate(int length, Float64List e) {
  var q = e[0];
  for (var i = 1; i < length; i++) {
    q += e[i];
  }
  return q;
}

// Adds two expansions, dropping zero parts (fast_expansion_sum_zeroelim).
int _sum(
  int eLength,
  Float64List e,
  int fLength,
  Float64List f,
  Float64List h,
) {
  var eNow = e[0];
  var fNow = f[0];
  var eIndex = 0;
  var fIndex = 0;
  double q;
  if ((fNow > eNow) == (fNow > -eNow)) {
    q = eNow;
    eNow = e[++eIndex];
  } else {
    q = fNow;
    fNow = f[++fIndex];
  }

  var hIndex = 0;
  double qNew, hh;

  // Adds one more part to q and keeps the rounding error in h.
  void add(double part, bool fast) {
    qNew = q + part;
    if (fast) {
      hh = q - (qNew - part);
    } else {
      final virtual = qNew - q;
      hh = q - (qNew - virtual) + (part - virtual);
    }
    q = qNew;
    if (hh != 0) h[hIndex++] = hh;
  }

  if (eIndex < eLength && fIndex < fLength) {
    if ((fNow > eNow) == (fNow > -eNow)) {
      add(eNow, true);
      eNow = e[++eIndex];
    } else {
      add(fNow, true);
      fNow = f[++fIndex];
    }
    while (eIndex < eLength && fIndex < fLength) {
      if ((fNow > eNow) == (fNow > -eNow)) {
        add(eNow, false);
        eNow = e[++eIndex];
      } else {
        add(fNow, false);
        fNow = f[++fIndex];
      }
    }
  }
  while (eIndex < eLength) {
    add(eNow, false);
    eNow = e[++eIndex];
  }
  while (fIndex < fLength) {
    add(fNow, false);
    fNow = f[++fIndex];
  }
  if (q != 0 || hIndex == 0) h[hIndex++] = q;
  return hIndex;
}
