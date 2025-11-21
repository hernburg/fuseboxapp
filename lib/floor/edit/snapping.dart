// lib/floor/edit/snapping.dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../core/wall_model.dart';

/// Тип привязки
enum SnapMode {
  free,
  axis,
  edge,
  vertex,
}

/// Результат привязки
class SnapResult {
  final ui.Offset snapped;
  final ui.Offset? hoverVertex;
  final SnapMode mode;

  const SnapResult({
    required this.snapped,
    this.hoverVertex,
    this.mode = SnapMode.free,
  });
}

/// Настройки привязок
class SnapSettings {
  final bool enabled;
  final double stepMm;
  final double vertexRadiusMm;
  final double orthoToleranceDeg;

  const SnapSettings({
    required this.enabled,
    this.stepMm = 0,
    this.vertexRadiusMm = 80,
    this.orthoToleranceDeg = 3,
  });
}

class Snapper {
  static double _toDeg(double r) => r * 180.0 / math.pi;

  static double _angleDiffDeg(double a, double b) {
    double d = (a - b).abs();
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    return _toDeg(d.abs());
  }

  static ui.Offset _closestPointOnSegment(
    ui.Offset p,
    ui.Offset a,
    ui.Offset b,
  ) {
    final ab = b - a;
    final len2 = ab.distanceSquared;
    if (len2 < 1e-9) return a;
    final ap = p - a;
    final t = ((ap.dx * ab.dx) + (ap.dy * ab.dy)) / len2;
    final clamped = t.clamp(0.0, 1.0).toDouble();
    return ui.Offset(
      a.dx + ab.dx * clamped,
      a.dy + ab.dy * clamped,
    );
  }

  static _EdgeSnapCandidate? _findEdgeSnap(
    ui.Offset p,
    List<WallSeg> walls,
    double radius,
  ) {
    if (radius <= 0) return null;

    double bestDist = radius;
    _EdgeSnapCandidate? best;

    void consider(WallSeg w, {required bool left}) {
      final shift = w.leftNormal * (w.thickMm / 2) * (left ? 1 : -1);
      final edge = [w.a + shift, w.b + shift];
      final closest = _closestPointOnSegment(p, edge[0], edge[1]);
      final d = (p - closest).distance;
      if (d < bestDist) {
        bestDist = d;
        best = _EdgeSnapCandidate(
          axisPoint: closest - shift,
          facePoint: closest,
          distance: d,
        );
      }
    }

    for (final w in walls) {
      consider(w, left: true);
      consider(w, left: false);
    }

    return best;
  }

  /// ---------------------------------------------------------
  /// SNAP START — привязка к вершинам и краям стен
  /// ---------------------------------------------------------
  static SnapResult snapStart(
    ui.Offset p,
    List<WallSeg> walls,
    SnapSettings s,
  ) {
    if (!s.enabled) return SnapResult(snapped: p);

    ui.Offset? bestVertex;
    double bestVertexDist = s.vertexRadiusMm;

    for (final w in walls) {
      for (final v in [w.a, w.b]) {
        final d = (p - v).distance;
        if (d < bestVertexDist) {
          bestVertexDist = d;
          bestVertex = v;
        }
      }
    }

    final edgeSnap = _findEdgeSnap(p, walls, s.vertexRadiusMm);

    if (bestVertex != null &&
        (edgeSnap == null || bestVertexDist <= edgeSnap.distance)) {
      return SnapResult(
        snapped: bestVertex,
        hoverVertex: bestVertex,
        mode: SnapMode.vertex,
      );
    }

    if (edgeSnap != null) {
      return SnapResult(
        snapped: edgeSnap.axisPoint,
        hoverVertex: edgeSnap.facePoint,
        mode: SnapMode.edge,
      );
    }

    return SnapResult(snapped: p);
  }

  /// ---------------------------------------------------------
  /// SNAP DRAG — ортогональность + шаг + привязка к вершинам/краям
  /// ---------------------------------------------------------
  static SnapResult snapDrag(
    ui.Offset start,
    ui.Offset raw,
    List<WallSeg> walls,
    SnapSettings s,
  ) {
    if (!s.enabled) return SnapResult(snapped: raw);

    ui.Offset p = raw;

    final v = p - start;
    double len = v.distance;
    if (len < 0.1) return SnapResult(snapped: p);

    double ang = math.atan2(v.dy, v.dx);

    // -------------------------------------------------
    // Ортогональность
    // -------------------------------------------------
    const axes = <double>[
      0,
      math.pi / 2,
      math.pi,
      3 * math.pi / 2,
    ];

    double bestAxis = ang;
    double bestDelta = 999;

    for (final ax in axes) {
      final d = _angleDiffDeg(ang, ax);
      if (d < s.orthoToleranceDeg && d < bestDelta) {
        bestDelta = d;
        bestAxis = ax;
      }
    }

    if (bestDelta < 999) {
      final dir = ui.Offset(math.cos(bestAxis), math.sin(bestAxis));
      p = start + dir * len;
    }

    // перерасчёт
    final v2 = p - start;
    len = v2.distance;
    if (len < 0.1) return SnapResult(snapped: p);

    ui.Offset dir = v2 / len;

    // -------------------------------------------------
    // Шаг длины
    // -------------------------------------------------
    if (s.stepMm > 0) {
      final snapped = (len / s.stepMm).roundToDouble() * s.stepMm;
      len = snapped.abs();
      p = start + dir * len;
    }

    // -------------------------------------------------
    // Привязка к вершине / краю
    // -------------------------------------------------
    ui.Offset? bestV;
    double bestVD = s.vertexRadiusMm;

    for (final w in walls) {
      for (final v in [w.a, w.b]) {
        final d = (p - v).distance;
        if (d < bestVD) {
          bestVD = d;
          bestV = v;
        }
      }
    }

    final edgeSnap = _findEdgeSnap(p, walls, s.vertexRadiusMm);

    if (bestV != null &&
        (edgeSnap == null || bestVD <= edgeSnap.distance)) {
      return SnapResult(
        snapped: bestV,
        hoverVertex: bestV,
        mode: SnapMode.vertex,
      );
    }

    if (edgeSnap != null) {
      return SnapResult(
        snapped: edgeSnap.axisPoint,
        hoverVertex: edgeSnap.facePoint,
        mode: SnapMode.edge,
      );
    }

    return SnapResult(
      snapped: p,
      mode: bestDelta < 999 ? SnapMode.axis : SnapMode.free,
    );
  }

  /// ---------------------------------------------------------
  /// Дубликаты стен (минимальная версия)
  /// ---------------------------------------------------------
  static bool isDuplicateSegment(
    ui.Offset a,
    ui.Offset b,
    List<WallSeg> walls, {
    double tolDistMm = 5,
  }) {
    final v = b - a;
    final len = v.distance;
    if (len < 1) return true;

    for (final w in walls) {
      final d1 = (w.a - a).distance;
      final d2 = (w.b - b).distance;
      final d3 = (w.a - b).distance;
      final d4 = (w.b - a).distance;

      if ((d1 <= tolDistMm && d2 <= tolDistMm) ||
          (d3 <= tolDistMm && d4 <= tolDistMm)) {
        return true;
      }
    }

    return false;
  }
}

class _EdgeSnapCandidate {
  final ui.Offset axisPoint;
  final ui.Offset facePoint;
  final double distance;

  const _EdgeSnapCandidate({
    required this.axisPoint,
    required this.facePoint,
    required this.distance,
  });
}

ui.Offset autoExtendFromCorner(
  ui.Offset start,
  ui.Offset world,
  List<WallSeg> walls,
) {
  const tol = 2.0;

  // ищем соседние точки
  final neighbors = <ui.Offset>[];

  for (final w in walls) {
    if ((w.a - start).distance < tol) neighbors.add(w.b);
    if ((w.b - start).distance < tol) neighbors.add(w.a);
  }

  if (neighbors.isEmpty) return world;

  final drag = world - start;
  final dragLen = drag.distance;
  if (dragLen < 0.001) return world;

  final dragDir = drag / dragLen;

  ui.Offset? bestDir;
  double bestDot = -1e9;

  for (final nb in neighbors) {
    final v = nb - start;
    final l = v.distance;
    if (l < 0.001) continue;

    final dir = v / l;
    final dot = dragDir.dx * dir.dx + dragDir.dy * dir.dy;

    if (dot > bestDot) {
      bestDot = dot;
      bestDir = dir;
    }
  }

  if (bestDir == null) return world;

  final t = (world.dx - start.dx) * bestDir.dx +
            (world.dy - start.dy) * bestDir.dy;

  if (t <= 0) return world;

  return ui.Offset(
    start.dx + bestDir.dx * t,
    start.dy + bestDir.dy * t,
  );
}
