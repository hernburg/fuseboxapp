import 'dart:math' as math;
import 'dart:ui' as ui;

import '../core/wall_model.dart';

/// Представление комнаты (замкнутого цикла), измеренной по осям стен
/// и пересчитанной через Shoelace formula.
class Room {
  final List<ui.Offset> outer;            // внешний контур
  final List<List<ui.Offset>> holes;      // отверстия (обычно пусто)
  final ui.Offset centerMm;               // центр геометрический
  final double areaM2;                    // площадь в м²

  const Room({
    required this.outer,
    required this.holes,
    required this.centerMm,
    required this.areaM2,
  });
}

/// Публичное API для расчёта комнат.
List<Room> detectRooms(List<WallSeg> walls) {
  if (walls.length < 3) return const <Room>[];

  final graph = _PlanarGraph.fromWalls(walls);
  final faces = graph.extractFaces();

  final rooms = <Room>[];
  for (final face in faces) {
    if (face.length < 3) continue;
    final data = _shoelace(face);
    if (data == null) continue;
    final (areaMm2, centroid) = data;

    // отсекаем слишком маленькие петли (< 0.5 м²) и внешнюю грань (отрицательная площадь)
    if (areaMm2 <= 0) continue;
    if (areaMm2 < 500000) continue; // 0.5 м²

    rooms.add(Room(
      outer: face,
      holes: const [],
      centerMm: centroid,
      areaM2: areaMm2 / 1e6,
    ));
  }

  return rooms;
}

/// Нормализованная вершина графа (с учётом допусков)
class _Node {
  final ui.Offset p;
  final List<_HalfEdge> edges = [];

  _Node(this.p);
}

class _HalfEdge {
  final _Node from;
  final _Node to;
  final WallSeg wall;
  final double angle;    // [0; 2π)
  late final _HalfEdge twin;
  bool visited = false;

  _HalfEdge({
    required this.from,
    required this.to,
    required this.wall,
  }) : angle = _normAngle(
          math.atan2(
            to.p.dy - from.p.dy,
            to.p.dx - from.p.dx,
          ),
        );
}

class _PlanarGraph {
  final List<_Node> nodes;

  const _PlanarGraph(this.nodes);

  static _PlanarGraph fromWalls(List<WallSeg> walls) {
    final map = <String, _Node>{};

    _Node get(ui.Offset p) {
      final key = '${p.dx.toStringAsFixed(3)}_${p.dy.toStringAsFixed(3)}';
      return map.putIfAbsent(key, () => _Node(p));
    }

    final nodes = <_Node>{};

    for (final wall in walls) {
      final a = get(wall.a);
      final b = get(wall.b);
      nodes
        ..add(a)
        ..add(b);

      final ab = _HalfEdge(from: a, to: b, wall: wall);
      final ba = _HalfEdge(from: b, to: a, wall: wall);
      ab.twin = ba;
      ba.twin = ab;

      a.edges.add(ab);
      b.edges.add(ba);
    }

    for (final node in nodes) {
      node.edges.sort(
        (a, b) => a.angle.compareTo(b.angle),
      );
    }

    return _PlanarGraph(nodes.toList());
  }

  List<List<ui.Offset>> extractFaces() {
    final faces = <List<ui.Offset>>[];

    for (final node in nodes) {
      for (final edge in node.edges) {
        if (edge.visited) continue;
        final poly = _traverseFace(edge);
        if (poly != null) {
          faces.add(poly);
        }
      }
    }

    return faces;
  }

  List<ui.Offset>? _traverseFace(_HalfEdge start) {
    final loop = <ui.Offset>[];
    var current = start;
    var safety = 0;

    while (true) {
      if (current.visited) return null; // уже разобранная грань
      current.visited = true;

      loop.add(current.from.p);

      final next = _nextAroundCorner(current);
      if (next == null) return null; // разрыв графа

      current = next;
      safety++;

      if (identical(current, start)) {
        break;
      }

      if (safety > 4096) {
        // защита от зацикливания
        return null;
      }
    }

    return loop;
  }

  _HalfEdge? _nextAroundCorner(_HalfEdge incoming) {
    final node = incoming.to;
    if (node.edges.isEmpty) return null;

    final idx = node.edges.indexOf(incoming.twin);
    if (idx == -1) return null;

    final prevIdx = (idx - 1) < 0 ? node.edges.length - 1 : idx - 1;
    return node.edges[prevIdx];
  }
}

double _normAngle(double value) {
  final twoPi = 2 * math.pi;
  var angle = value % twoPi;
  if (angle < 0) angle += twoPi;
  return angle;
}

(double, ui.Offset)? _shoelace(List<ui.Offset> poly) {
  if (poly.length < 3) return null;

  double twiceArea = 0;
  double cx = 0;
  double cy = 0;

  for (var i = 0; i < poly.length; i++) {
    final j = (i + 1) % poly.length;
    final x1 = poly[i].dx;
    final y1 = poly[i].dy;
    final x2 = poly[j].dx;
    final y2 = poly[j].dy;

    final cross = x1 * y2 - x2 * y1;
    twiceArea += cross;
    cx += (x1 + x2) * cross;
    cy += (y1 + y2) * cross;
  }

  if (twiceArea.abs() < 1e-3) return null;

  final area = twiceArea / 2;
  final centroid = ui.Offset(
    cx / (3 * twiceArea),
    cy / (3 * twiceArea),
  );

  return (area, centroid);
}
