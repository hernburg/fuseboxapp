import 'dart:math' as math;
import 'dart:ui';

class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  Offset get o => Offset(x, y);

  Vec2 operator +(Vec2 b) => Vec2(x + b.x, y + b.y);
  Vec2 operator -(Vec2 b) => Vec2(x - b.x, y - b.y);
  Vec2 operator *(double k) => Vec2(x * k, y * k);

  double dot(Vec2 b) => x * b.x + y * b.y;

  double get length => math.sqrt(x * x + y * y);

  Vec2 normalized() {
    final len = length;
    return len < 1e-9 ? this : this * (1.0 / len);
  }

  Vec2 rotated90CCW() => Vec2(-y, x);
  Vec2 rotated90CW() => Vec2(y, -x);
}
