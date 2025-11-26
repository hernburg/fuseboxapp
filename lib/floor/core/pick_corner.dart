import 'dart:ui' as ui;

import 'wall_model.dart';

/// Умный выбор угла стены по направлению жеста и позиции пальца.
ui.Offset pickCornerSmart({
  required WallSeg baseWall,
  required ui.Offset dir,
  required ui.Offset finger,
}) {
  final a1 = baseWall.cornerA; // bottom-left
  final b1 = baseWall.cornerB; // top-left
  final c1 = baseWall.cornerC; // top-right
  final d1 = baseWall.cornerD; // bottom-right

  final dx = dir.dx;
  final dy = dir.dy;

  // ---- 1. Выбираем группу углов по направлению ----
  late final List<ui.Offset> group;

  if (dx > 0 && dy.abs() < 1e-6) {
    // →
    group = [c1, d1];
  } else if (dx < 0 && dy.abs() < 1e-6) {
    // ←
    group = [a1, b1];
  } else if (dy < 0 && dx.abs() < 1e-6) {
    // ↑
    group = [b1, c1];
  } else if (dy > 0 && dx.abs() < 1e-6) {
    // ↓
    group = [a1, d1];
  } else {
    // fallback — если жест диагональный
    group = [a1, b1, c1, d1];
  }

  // ----- 2. Внутри группы выбираем ближайший угол -----
  ui.Offset best = group.first;
  double bestDist = (finger - best).distanceSquared;

  for (final p in group.skip(1)) {
    final d = (finger - p).distanceSquared;
    if (d < bestDist) {
      bestDist = d;
      best = p;
    }
  }

  return best;
}
