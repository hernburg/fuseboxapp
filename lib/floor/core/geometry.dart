// lib/floor/core/geometry.dart
import 'dart:math' as math;
import 'dart:ui' as ui;

/// Вектор в мировых координатах (мм)
typedef Vec2 = ui.Offset;

/// Набор геометрических утилит,
/// без знания о стенах / редакторе.
class Geom {
  /// Эпсилон для сравнения
  static const double eps = 1e-6;

  static const Vec2 zero = ui.Offset.zero;

  /// Нормализация вектора
  static Vec2 normalize(Vec2 v) {
    final len = v.distance;
    if (len < eps) return zero;
    return v / len;
  }

  /// Скалярное произведение
  static double dot(Vec2 a, Vec2 b) => a.dx * b.dx + a.dy * b.dy;

  /// Длина вектора
  static double length(Vec2 v) => v.distance;

  /// Расстояние между точками
  static double distance(Vec2 a, Vec2 b) => (b - a).distance;

  /// Перпендикуляр влево (-y, x)
  static Vec2 perpLeft(Vec2 v) => ui.Offset(-v.dy, v.dx);

  /// Перпендикуляр вправо (y, -x)
  static Vec2 perpRight(Vec2 v) => ui.Offset(v.dy, -v.dx);

  /// Линейная интерполяция
  static Vec2 lerp(Vec2 a, Vec2 b, double t) => a + (b - a) * t;

  /// Проекция точки на бесконечную прямую AB
  static Vec2 projectPointOnLine(Vec2 p, Vec2 a, Vec2 b) {
    final ab = b - a;
    final denom = ab.dx * ab.dx + ab.dy * ab.dy;
    if (denom.abs() < eps) return a;
    final ap = p - a;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / denom;
    return a + ab * t;
  }

  /// Проекция точки на ОТРЕЗОК AB, с обрезкой t в [0..1]
  static Vec2 projectPointOnSegment(Vec2 p, Vec2 a, Vec2 b) {
    final ab = b - a;
    final denom = ab.dx * ab.dx + ab.dy * ab.dy;
    if (denom.abs() < eps) return a;
    final ap = p - a;
    double t = (ap.dx * ab.dx + ap.dy * ab.dy) / denom;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    return a + ab * t;
  }

  /// Расстояние от точки до отрезка AB
  static double distanceToSegment(Vec2 p, Vec2 a, Vec2 b) {
    final proj = projectPointOnSegment(p, a, b);
    return (p - proj).distance;
  }

  /// Проверка пересечения отрезков (включая концы)
  static bool segmentsIntersect(
    Vec2 a1,
    Vec2 b1,
    Vec2 a2,
    Vec2 b2, {
    bool includeEndpoints = true,
  }) {
    int sign(num x) => x > 0 ? 1 : (x < 0 ? -1 : 0);

    double cross(Vec2 o, Vec2 p, Vec2 q) {
      final op = p - o;
      final oq = q - o;
      return op.dx * oq.dy - op.dy * oq.dx;
    }

    final c1 = cross(a1, b1, a2);
    final c2 = cross(a1, b1, b2);
    final c3 = cross(a2, b2, a1);
    final c4 = cross(a2, b2, b1);

    if (includeEndpoints) {
      if (c1 == 0 && _pointOnSegment(a2, a1, b1)) return true;
      if (c2 == 0 && _pointOnSegment(b2, a1, b1)) return true;
      if (c3 == 0 && _pointOnSegment(a1, a2, b2)) return true;
      if (c4 == 0 && _pointOnSegment(b1, a2, b2)) return true;
    }

    return sign(c1) * sign(c2) < 0 && sign(c3) * sign(c4) < 0;
  }

  static bool _pointOnSegment(Vec2 p, Vec2 a, Vec2 b) {
    final minX = math.min(a.dx, b.dx) - eps;
    final maxX = math.max(a.dx, b.dx) + eps;
    final minY = math.min(a.dy, b.dy) - eps;
    final maxY = math.max(a.dy, b.dy) + eps;
    if (p.dx < minX || p.dx > maxX || p.dy < minY || p.dy > maxY) return false;

    final cross = (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
    return cross.abs() < eps;
  }

  /// Площадь многоугольника (абсолютная), точки в порядке обхода
  static double polygonArea(List<Vec2> pts) {
    if (pts.length < 3) return 0;
    double sum = 0;
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      final q = pts[(i + 1) % pts.length];
      sum += p.dx * q.dy - p.dy * q.dx;
    }
    return sum.abs() * 0.5;
  }
}

/// Возвращает единичный вектор, прилегающий к ближайшей оси (горизонт/вертикаль)
/// с направлением, соответствующим жесту `v`.
ui.Offset computeAxisDirection(ui.Offset v) {
  if (v.distance < Geom.eps) {
    return const ui.Offset(1, 0);
  }

  final absDx = v.dx.abs();
  final absDy = v.dy.abs();

  if (absDx >= absDy) {
    final sign = v.dx >= 0 ? 1.0 : -1.0;
    return ui.Offset(sign, 0);
  } else {
    final sign = v.dy >= 0 ? 1.0 : -1.0;
    return ui.Offset(0, sign);
  }
}
