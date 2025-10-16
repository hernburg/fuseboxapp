// lib/floor/edit/snapping.dart
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../core/wall_model.dart';

// Допусти, что в проекте уже есть помощники в geometry.dart.
// Если нет – эти локальные утилиты оставим здесь.

double _degBetween(Offset a, Offset b) {
  final la = a.distance, lb = b.distance;
  if (la == 0 || lb == 0) return 180;
  final cosv = ((a.dx*b.dx) + (a.dy*b.dy)) / (la*lb);
  final clamped = cosv.clamp(-1.0, 1.0);
  return (math.acos(clamped) * 180 / math.pi).abs();
}

double _distPointToLine(Offset p, Offset x0, Offset dirUnit) {
  final v = p - x0;
  final cross = (v.dx * dirUnit.dy) - (v.dy * dirUnit.dx);
  return cross.abs();
}

// === публичные функции, которые ждёт floor_editor.dart ===

Offset axisSnap(Offset a, Offset b, {double angTolDeg = 10}) {
  final th = angTolDeg * math.pi / 180.0;
  final d = b - a;
  if (d == Offset.zero) return b;
  final ang = math.atan2(d.dy, d.dx).abs();
  if (ang <= th || (math.pi - ang) <= th) return Offset(b.dx, a.dy);
  if ((ang - math.pi/2).abs() <= th)   return Offset(a.dx, b.dy);
  return b;
}

Offset snapStartToCornerOrEnd(
  Offset tapMm,
  List<WallSeg> walls, {
  double snapStartMm = 60,
  bool gridSnapOn = true,
  double gridMm = 100,
}) {
  Offset? nearestVertex;
  double bestD = snapStartMm + 1;
  for (final w in walls) {
    for (final v in [w.a, w.b]) {
      final d = (v - tapMm).distance;
      if (d < bestD) { bestD = d; nearestVertex = v; }
    }
  }
  if (nearestVertex != null) return nearestVertex!;
  if (gridSnapOn) {
    double rd(double v) => (v / gridMm).roundToDouble() * gridMm;
    return Offset(rd(tapMm.dx), rd(tapMm.dy));
  }
  return tapMm;
}

Offset smartSnapWallEnd(
  Offset aMm,
  Offset rawBMm,
  List<WallSeg> walls, {
  double snapEndMm = 40,
  bool gridSnapOn = true,
  double gridMm = 100,
  double parallelTolDeg = 10,
  double snapParallelGapMm = 2500,
  double snapEdgeMm = 700,
  double escapeFactor = 3.0,
}) {
  if (gridSnapOn) {
    double rd(double v) => (v / gridMm).roundToDouble() * gridMm;
    rawBMm = Offset(rd(rawBMm.dx), rd(rawBMm.dy));
  }

  // прилипание к вершине (кроме стартовой)
  Offset? endVertex;
  double bestD = snapEndMm + 1;
  for (final w in walls) {
    for (final v in [w.a, w.b]) {
      if ((v - aMm).distance <= 1e-6) continue;
      final d = (v - rawBMm).distance;
      if (d < bestD) { bestD = d; endVertex = v; }
    }
  }
  if (endVertex != null) return endVertex!;

  // осевая помощь (ортогональ)
  Offset b = axisSnap(aMm, rawBMm, angTolDeg: 30);

  final d = b - aMm;
  final len = d.distance;
  if (len <= 0.0001 || walls.isEmpty) return b;

  final dir = Offset(d.dx / len, d.dy / len);

  int bestIdx = -1;
  double bestScore = -1e9;
  double bestPmin = 0, bestPmax = 0, bestGap = 1e9, bestLen = 0;
  bool   bestStartAtCorner = false;

  for (int i=0;i<walls.length;i++) {
    final w = walls[i];
    final wv = w.b - w.a;
    final wlen = wv.distance;
    if (wlen == 0) continue;
    final wdir = Offset(wv.dx / wlen, wv.dy / wlen);

    final ang = _degBetween(dir, wdir);
    if (ang > parallelTolDeg && (180-ang) > parallelTolDeg) continue;

    final gapA = _distPointToLine(w.a, aMm, dir);
    final gapB = _distPointToLine(w.b, aMm, dir);
    final gap = math.min(gapA, gapB);
    if (gap > snapParallelGapMm) continue;

    final startNearCorner = (w.a - aMm).distance <= (snapEndMm*1.5) ||
                            (w.b - aMm).distance <= (snapEndMm*1.5);

    final p1 = (w.a - aMm).dx * dir.dx + (w.a - aMm).dy * dir.dy;
    final p2 = (w.b - aMm).dx * dir.dx + (w.b - aMm).dy * dir.dy;
    final pmin = math.min(p1, p2);
    final pmax = math.max(p1, p2);

    final score = (pmax - pmin) - gap * 0.02 + (startNearCorner? 500.0 : 0.0);
    if (score > bestScore) {
      bestScore = score;
      bestIdx = i;
      bestPmin = pmin;
      bestPmax = pmax;
      bestGap  = gap;
      bestLen  = wlen;
      bestStartAtCorner = startNearCorner;
    }
  }

  if (bestIdx >= 0) {
    final tEnd = (b - aMm).dx * dir.dx + (b - aMm).dy * dir.dy;

    double? snappedT;
    final nearLeft  = (tEnd - bestPmin).abs() <= snapEdgeMm;
    final nearRight = (tEnd - bestPmax).abs() <= snapEdgeMm;
    if (nearLeft)  snappedT = bestPmin;
    if (nearRight) snappedT = (snappedT==null || (tEnd - bestPmax).abs() < (tEnd - snappedT).abs())
        ? bestPmax : snappedT;

    if (snappedT==null && bestGap <= snapParallelGapMm * 0.8) {
      final wantLen = bestLen;
      final nearEqual = (tEnd - wantLen).abs() <= snapEdgeMm || bestStartAtCorner;
      if (nearEqual) snappedT = wantLen;
    }

    if (snappedT != null) {
      final snappedB = aMm + Offset(dir.dx * snappedT, dir.dy * snappedT);
      final escape = math.max(escapeFactor * snapEdgeMm, bestLen * 0.35);
      if ((snappedB - rawBMm).distance <= escape) {
        b = snappedB;
      }
    }
  }

  // финальная прилипка к вершине после осевой помощи
  b = axisSnap(aMm, b, angTolDeg: 10);
  Offset? vtxAfterAxis;
  double best2 = snapEndMm + 1;
  for (final w in walls) {
    for (final v in [w.a, w.b]) {
      if ((v - aMm).distance <= 1e-6) continue;
      final d = (v - b).distance;
      if (d < best2) { best2 = d; vtxAfterAxis = v; }
    }
  }
  if (vtxAfterAxis != null) return vtxAfterAxis!;
  return b;
}