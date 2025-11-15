// lib/floor/edit/snapping.dart
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../core/wall_model.dart';

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

// Найти стену, к которой принадлежит вершина v (с малым эпсилоном)
WallSeg? _wallByVertex(Offset v, List<WallSeg> walls, {double epsMm = 1e-3}) {
  for (final w in walls) {
    if ((w.a - v).distance <= epsMm || (w.b - v).distance <= epsMm) return w;
  }
  return null;
}

// Сдвиг точки старта на нужную грань стены (кромку), от оси кромку выбираем по направлению новой стены
// Выбор правильной кромки по направлению драга
Offset _edgeAttachByDragDirection({
  required Offset axisStart,     // вершина оси, куда ты кликнул/привязался
  required Offset dragTarget,    // rawBMm — куда тащишь конец стены
  required WallSeg baseWall,     // стена, от кромки которой стартуем
}) {
  final n = baseWall.leftNormal;
  final halfT = baseWall.thickMm / 2.0;

  final shiftPos = n * halfT;   // одна кромка
  final shiftNeg = -shiftPos;   // вторая кромка

  final drag = dragTarget - axisStart;

  // если «проекция» драга на сдвиг положительная — берём эту кромку
  final usePos = (drag.dx * shiftPos.dx + drag.dy * shiftPos.dy) >= 0;
  return axisStart + (usePos ? shiftPos : shiftNeg);
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
  // осевая привязка/сетка к предварительному концу
  if (gridSnapOn) {
    double rd(double v) => (v / gridMm).roundToDouble() * gridMm;
    rawBMm = Offset(rd(rawBMm.dx), rd(rawBMm.dy));
  }

  // прилипание стартовой точки к ближайшей вершине (ось), не меняем пока — это вершина оси
   final startAxis = snapStartToCornerOrEnd(aMm, walls,
      snapStartMm: snapEndMm, gridSnapOn: gridSnapOn, gridMm: gridMm);


  // первичная ортогональ к предполагаемому концу
   Offset b = axisSnap(startAxis, rawBMm, angTolDeg: 30);

  // направление новой стены
  var d = b - startAxis;
  var len = d.distance;
  if (len <= 0.0001 || walls.isEmpty) return b;
  var dir = Offset(d.dx / len, d.dy / len);

  // === КЛЮЧЕВОЕ: перенос старта с оси на КРОМКУ базовой стены ===
  // Если начало совпало с вершиной какой-либо стены — переносим на нужную грань этой стены
  final baseWall = _wallByVertex(startAxis, walls, epsMm: 0.5);
  var aEdge = startAxis;
   if (baseWall != null) {
    aEdge = _edgeAttachByDragDirection(
      axisStart: startAxis,
      dragTarget: rawBMm,     // важно! направление берём от реального драга
      baseWall: baseWall,
    );
    // сохраняем «параметр» вдоль dir и перестраиваем b из новой точки
    final tEnd = (b - startAxis).dx * dir.dx + (b - startAxis).dy * dir.dy;
    b = aEdge + Offset(dir.dx * tEnd, dir.dy * tEnd);

    d = b - aEdge;
    len = d.distance;
    if (len <= 0.0001) return b;
    dir = Offset(d.dx / len, d.dy / len);
  }
   if (gridSnapOn && gridMm > 0) {
   // проекция «как далеко ты тащишь» от внутренней кромки вдоль направления
   final tAlong = (rawBMm - aEdge).dx * dir.dx + (rawBMm - aEdge).dy * dir.dy;
   final snapped = (tAlong / gridMm).roundToDouble() * gridMm;
   b = aEdge + dir * snapped; // теперь 2000, 2500 и т.п. будут ровно внутренними
   }

  // Дальше используем aEdge как фактическое начало новой стены
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

    final gapA = _distPointToLine(w.a, aEdge, dir);
    final gapB = _distPointToLine(w.b, aEdge, dir);
    final gap = math.min(gapA, gapB);
    if (gap > snapParallelGapMm) continue;

    final startNearCorner = (w.a - aEdge).distance <= (snapEndMm*1.5) ||
                            (w.b - aEdge).distance <= (snapEndMm*1.5);

    final p1 = (w.a - aEdge).dx * dir.dx + (w.a - aEdge).dy * dir.dy;
    final p2 = (w.b - aEdge).dx * dir.dx + (w.b - aEdge).dy * dir.dy;
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
    final tEnd = (b - aEdge).dx * dir.dx + (b - aEdge).dy * dir.dy;

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
      final snappedB = aEdge + Offset(dir.dx * snappedT, dir.dy * snappedT);
      final escape = math.max(escapeFactor * snapEdgeMm, bestLen * 0.35);
      if ((snappedB - rawBMm).distance <= escape) {
        b = snappedB;
      }
    }
  }

  // финальная ортогональ и прихваты к вершинам после переноса начала на грань
  b = axisSnap(aEdge, b, angTolDeg: 10);
  Offset? vtxAfterAxis;
  double best2 = snapEndMm + 1;
  for (final w in walls) {
    for (final v in [w.a, w.b]) {
      if ((v - aEdge).distance <= 1e-6) continue;
      final d2 = (v - b).distance;
      if (d2 < best2) { best2 = d2; vtxAfterAxis = v; }
    }
  }
  if (vtxAfterAxis != null) return vtxAfterAxis!;
  return b;
}
