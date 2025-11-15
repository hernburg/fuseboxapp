// lib/floor/rooms/room_detector.dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../core/wall_model.dart';

class RoomRect {
  final ui.Rect rectMm;
  RoomRect(this.rectMm);

  double get areaM2 => rectMm.width * rectMm.height / 1e6;
}

/// Детектор прямоугольных помещений.
/// tol      — допуск по координатам (мм),
/// gapTolMm — максимальный «незакрытый» зазор по стене, который считаем
///            всё равно закрытым (как в Remplanner).
List<RoomRect> detectRectRooms(
  List<WallSeg> walls, {
  double tol = 1.0,
  double gapTolMm = 60.0,
}) {
  if (walls.length < 4) return const [];

  // --- собираем уникальные x/y из вершин ---
  final xs = <double>[];
  final ys = <double>[];

  void addCoord(List<double> list, double v) {
    for (final e in list) {
      if ((e - v).abs() <= tol) return;
    }
    list.add(v);
  }

  for (final w in walls) {
    addCoord(xs, w.a.dx);
    addCoord(xs, w.b.dx);
    addCoord(ys, w.a.dy);
    addCoord(ys, w.b.dy);
  }

  xs.sort();
  ys.sort();

  // Проверка, что отрезок [from, to] на линии
  // покрыт горизонтальными или вертикальными отрезками стен
  // с допуском по маленьким «дыркам» до gapTolMm.
  bool hasCoverage({
    required bool horizontal,
    required double constPos, // y для горизонтальных, x для вертикальных
    required double from,
    required double to,
  }) {
    final intervals = <ui.Offset>[]; // dx = start, dy = end

    for (final w in walls) {
      final a = w.a;
      final b = w.b;

      if (horizontal) {
        final dy1 = (a.dy - constPos).abs();
        final dy2 = (b.dy - constPos).abs();
        if (dy1 > tol || dy2 > tol) continue;

        double start = math.min(a.dx, b.dx);
        double end = math.max(a.dx, b.dx);
        if (end <= from || start >= to) continue;

        start = math.max(start, from);
        end = math.min(end, to);
        if (end - start <= 0) continue;

        intervals.add(ui.Offset(start, end));
      } else {
        final dx1 = (a.dx - constPos).abs();
        final dx2 = (b.dx - constPos).abs();
        if (dx1 > tol || dx2 > tol) continue;

        double start = math.min(a.dy, b.dy);
        double end = math.max(a.dy, b.dy);
        if (end <= from || start >= to) continue;

        start = math.max(start, from);
        end = math.min(end, to);
        if (end - start <= 0) continue;

        intervals.add(ui.Offset(start, end));
      }
    }

    if (intervals.isEmpty) return false;

    intervals.sort((a, b) => a.dx.compareTo(b.dx));

    double covered = 0.0;
    double currentStart = intervals[0].dx;
    double currentEnd = intervals[0].dy;
    double biggestGap = 0.0;

    for (int i = 1; i < intervals.length; i++) {
      final iv = intervals[i];
      if (iv.dx <= currentEnd + tol) {
        // пересекается или стыкуется
        if (iv.dy > currentEnd) currentEnd = iv.dy;
      } else {
        // зазор
        final gap = iv.dx - currentEnd;
        if (gap > biggestGap) biggestGap = gap;
        covered += currentEnd - currentStart;
        currentStart = iv.dx;
        currentEnd = iv.dy;
      }
    }
    covered += currentEnd - currentStart;

    final total = to - from;
    final uncovered = total - covered;

    // считаем стену «сплошной», если
    // суммарные дырки и максимальная дырка не больше gapTolMm
    if (uncovered <= gapTolMm && biggestGap <= gapTolMm) {
      return true;
    }
    return false;
  }

  final rooms = <RoomRect>[];

  for (int ix1 = 0; ix1 < xs.length; ix1++) {
    for (int ix2 = ix1 + 1; ix2 < xs.length; ix2++) {
      final x1 = xs[ix1];
      final x2 = xs[ix2];
      if ((x2 - x1).abs() <= tol) continue;

      for (int iy1 = 0; iy1 < ys.length; iy1++) {
        for (int iy2 = iy1 + 1; iy2 < ys.length; iy2++) {
          final y1 = ys[iy1];
          final y2 = ys[iy2];
          if ((y2 - y1).abs() <= tol) continue;

          // проверяем 4 стороны прямоугольника
          if (!hasCoverage(
              horizontal: true, constPos: y1, from: x1, to: x2)) {
            continue;
          }
          if (!hasCoverage(
              horizontal: true, constPos: y2, from: x1, to: x2)) {
            continue;
          }
          if (!hasCoverage(
              horizontal: false, constPos: x1, from: y1, to: y2)) {
            continue;
          }
          if (!hasCoverage(
              horizontal: false, constPos: x2, from: y1, to: y2)) {
            continue;
          }

          final rect = ui.Rect.fromLTRB(x1, y1, x2, y2);

          // убираем дубликаты (тот же прямоугольник)
          bool exists = false;
          for (final r in rooms) {
            if ((r.rectMm.left - rect.left).abs() <= tol &&
                (r.rectMm.top - rect.top).abs() <= tol &&
                (r.rectMm.right - rect.right).abs() <= tol &&
                (r.rectMm.bottom - rect.bottom).abs() <= tol) {
              exists = true;
              break;
            }
          }
          if (!exists) rooms.add(RoomRect(rect));
        }
      }
    }
  }

  return rooms;
}
