import 'dart:math' as math;
import 'dart:ui' as ui;
import 'snap_hit.dart';
import '../core/wall_model.dart';

SnapHit findSnap(ui.Offset p, List<WallSeg> walls, SnapSettings set) {
  if (!set.enabled) {
    return SnapHit(kind: SnapKind.none, snapped: p);
  }

  // --- сначала ищем вершины ---
  for (final w in walls) {
    if ((p - w.a).distance <= set.vertexRadiusMm) {
      final isLeft = _isLeftOfWall(w, origin: w.a, point: p);
      return SnapHit(
        kind: SnapKind.vertex,
        snapped: w.a,
        vertex: w.a,
        wall: w,
        isLeftSide: isLeft,
      );
    }
    if ((p - w.b).distance <= set.vertexRadiusMm) {
      final isLeft = _isLeftOfWall(w, origin: w.b, point: p);
      return SnapHit(
        kind: SnapKind.vertex,
        snapped: w.b,
        vertex: w.b,
        wall: w,
        isLeftSide: isLeft,
      );
    }
  }

  // --- затем ищем попадание на грань ---
  for (final w in walls) {
    final ab = w.b - w.a;
    final ap = p - w.a;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / (ab.distance * ab.distance);

    if (t >= 0 && t <= 1) {
      final proj = ui.Offset(w.a.dx + ab.dx * t, w.a.dy + ab.dy * t);
      if ((proj - p).distance < 40) { // радиус снапа к грани
        final left = (ab.dx * (p.dy - w.a.dy) - ab.dy * (p.dx - w.a.dx)) > 0;
        return SnapHit(
          kind: SnapKind.edge,
          snapped: proj,
          wall: w,
          isLeftSide: left,
        );
      }
    }
  }

  return SnapHit(kind: SnapKind.none, snapped: p);
}

bool _isLeftOfWall(
  WallSeg wall, {
  required ui.Offset origin,
  required ui.Offset point,
}) {
  final dir = wall.dir;
  final rel = point - origin;

  final cross = dir.dx * rel.dy - dir.dy * rel.dx;
  if (cross.abs() < 1e-6) {
    return true;
  }
  return cross > 0;
}
ui.Offset computeAxisDirection(ui.Offset gesture) {
  if (gesture.distance < 1e-6) {
    return const ui.Offset(1, 0);
  }

  final g = gesture / gesture.distance;

  final angle = math.atan2(g.dy, g.dx) * 180.0 / math.pi;
  final absAngle = angle.abs();

  // около горизонтали
  if (absAngle <= 3 || absAngle >= 177) {
    return ui.Offset(g.dx.sign, 0);
  }

  // около вертикали
  if ((absAngle - 90).abs() <= 3) {
    return ui.Offset(0, g.dy.sign);
  }

  return g;
}
