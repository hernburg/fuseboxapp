// lib/floor/core/geometry.dart
import 'dart:math' as math;
import 'dart:ui' as ui;

/// Длина вектора
double len(ui.Offset v) => v.distance;

/// Скалярное произведение
double dot(ui.Offset a, ui.Offset b) => a.dx * b.dx + a.dy * b.dy;

/// Нормированный вектор (или zero)
ui.Offset norm(ui.Offset v) {
  final l = v.distance;
  return l == 0 ? ui.Offset.zero : v / l;
}

/// Левый нормаль к вектору
ui.Offset leftNormal(ui.Offset v) {
  final n = norm(v);
  return ui.Offset(-n.dy, n.dx);
}

/// Расстояние от точки до отрезка AB (в тех же единицах)
double pointSegDist(ui.Offset p, ui.Offset a, ui.Offset b) {
  final ab = b - a;
  final ap = p - a;
  final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (ab2 == 0) return (p - a).distance;
  var t = dot(ap, ab) / ab2;
  t = t.clamp(0.0, 1.0);
  final proj = a + ab * t;
  return (p - proj).distance;
}

/// Проверка «почти осевая» ориентация (по X или Y)
bool isAxisAligned(ui.Offset a, ui.Offset b, {double angTolDeg = 2}) {
  final v = b - a;
  if (v == ui.Offset.zero) return true;
  final ang = (math.atan2(v.dy, v.dx).abs() * 180 / math.pi) % 90;
  final dev = math.min(ang, 90 - ang);
  return dev <= angTolDeg;
}

/// Геометрический «знак поворота» (для пересечений/CCW)
bool ccw(ui.Offset A, ui.Offset B, ui.Offset C) =>
    (C.dy - A.dy) * (B.dx - A.dx) > (B.dy - A.dy) * (C.dx - A.dx);

/// Пересечение отрезков (включая касания)
bool segsIntersect(ui.Offset a1, ui.Offset b1, ui.Offset a2, ui.Offset b2) {
  bool _overlap1D(double a, double b, double c, double d) =>
      math.max(math.min(a, b), math.min(c, d)) <=
      math.min(math.max(a, b), math.max(c, d));
  final o = _overlap1D(a1.dx, b1.dx, a2.dx, b2.dx) &&
      _overlap1D(a1.dy, b1.dy, a2.dy, b2.dy) &&
      (ccw(a1, a2, b2) != ccw(b1, a2, b2)) &&
      (ccw(a1, b1, a2) != ccw(a1, b1, b2));
  return o;
}

/// Смещение пары точек A,B на постоянное расстояние offsetMm
/// влево относительно направления A->B (для предварительного
/// построения стен «по центру»/«по внутренней/внешней кромке»).
List<ui.Offset> posShift(ui.Offset a, ui.Offset b, double offsetMm) {
  final n = leftNormal(b - a);       // единичная левая нормаль
  final shift = n * offsetMm;        // смещение в мм
  return [a + shift, b + shift];
}