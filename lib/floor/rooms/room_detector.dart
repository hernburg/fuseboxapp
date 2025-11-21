import 'dart:ui' as ui;
import '../core/wall_model.dart';

/// Узел (вершина графа)
class Node {
  final ui.Offset p;

  Node(this.p);

  @override
  bool operator ==(Object other) =>
      other is Node && (other.p - p).distance < 1e-3;

  @override
  int get hashCode => p.dx.hashCode ^ p.dy.hashCode;
}
class Edge {
  final Node a;
  final Node b;

  Edge(this.a, this.b);

  double get length => (b.p - a.p).distance;
}
class WallGraph {
  final List<Node> nodes = [];
  final List<Edge> edges = [];

  Node getOrAddNode(ui.Offset p) {
    for (final n in nodes) {
      if ((n.p - p).distance < 1.0) return n;
    }
    final n = Node(p);
    nodes.add(n);
    return n;
  }

  void addWall(WallSeg w) {
    final a = getOrAddNode(w.a);
    final b = getOrAddNode(w.b);
    edges.add(Edge(a, b));
  }
}
List<List<Node>> findCycles(WallGraph g) {
  final adj = <Node, List<Node>>{};
  for (final e in g.edges) {
    adj.putIfAbsent(e.a, () => []).add(e.b);
    adj.putIfAbsent(e.b, () => []).add(e.a);
  }

  final visited = <Node>{};
  final stack = <Node>[];
  final cycles = <List<Node>>[];

  void dfs(Node curr, Node start) {
    visited.add(curr);
    stack.add(curr);

    for (final next in adj[curr]!) {
      if (next == start && stack.length > 2) {
        cycles.add(List<Node>.from(stack));
      } else if (!visited.contains(next)) {
        dfs(next, start);
      }
    }
    stack.removeLast();
    visited.remove(curr);
  }

  for (final n in g.nodes) {
    dfs(n, n);
    visited.clear();
    stack.clear();
  }

  // удаляем дубли и самопересечения
  final unique = <String, List<Node>>{};
  for (final c in cycles) {
    final key = c.map((n) => "${n.p.dx}:${n.p.dy}").join('|');
    if (!unique.containsKey(key)) unique[key] = c;
  }

  return unique.values.toList();
}
ui.Path cycleToPath(List<Node> nodes) {
  final path = ui.Path();
  if (nodes.isEmpty) return path;

  path.moveTo(nodes.first.p.dx, nodes.first.p.dy);
  for (var i = 1; i < nodes.length; i++) {
    path.lineTo(nodes[i].p.dx, nodes[i].p.dy);
  }
  path.close();
  return path;
}

double polygonArea(ui.Path p) {
  final metrics = p.computeMetrics().toList();
  if (metrics.isEmpty) return 0;
  // просто площадь через shoelace
  final List<ui.Offset> pts = [];

  for (final m in metrics) {
    for (var t = 0.0; t < m.length; t += 10) {
      pts.add(m.getTangentForOffset(t)!.position);
    }
  }

  double sum = 0;
  for (var i = 0; i < pts.length; i++) {
    final j = (i + 1) % pts.length;
    sum += pts[i].dx * pts[j].dy - pts[j].dx * pts[i].dy;
  }
  return sum.abs() / 2;
}
List<ui.Path> detectRoomsAllShapes(List<WallSeg> walls) {
  final g = WallGraph();

  for (final w in walls) {
    g.addWall(w);
  }

  final cycles = findCycles(g);
  if (cycles.isEmpty) return [];

  final rooms = <ui.Path>[];
  for (final c in cycles) {
    final path = cycleToPath(c);
    final area = polygonArea(path);

    // площадь > 0.5 м² (отсекаем мусор)
    if (area > 50000) {
      rooms.add(path);
    }
  }

  return rooms;
}
List<Room> detectRooms(List<WallSeg> walls) {
  final paths = detectRoomsAllShapes(walls); // твоя функция, которая делает List<Path>

  final result = <Room>[];

  for (final p in paths) {
    final outer = <ui.Offset>[];

    // Извлекаем точки Path
    for (final metric in p.computeMetrics()) {
      final poly = <ui.Offset>[];

      for (double t = 0; t < metric.length; t += 10) {
        final pos = metric.getTangentForOffset(t)!.position;
        poly.add(pos);
      }

      if (poly.length >= 3) {
        outer.addAll(poly);
      }
    }

    if (outer.length < 3) continue;

    // Вычисление центра
    final cx = outer.fold(0.0, (s, o) => s + o.dx) / outer.length;
    final cy = outer.fold(0.0, (s, o) => s + o.dy) / outer.length;

    // Вычисление площади (полигонный метод)
    double area = 0;
    for (int i = 0; i < outer.length; i++) {
      final j = (i + 1) % outer.length;
      area += outer[i].dx * outer[j].dy - outer[j].dx * outer[i].dy;
    }
    area = area.abs() / 2 / 1e6; // мм² → м²

    result.add(
      Room(
        outer: outer,
        holes: const [],
        centerMm: ui.Offset(cx, cy),
        areaM2: area,
      ),
    );
  }

  return result;
}
class Room {
  final List<ui.Offset> outer;            // внешний контур
  final List<List<ui.Offset>> holes;      // отверстия (обычно пусто)
  final ui.Offset centerMm;               // центр комнаты
  final double areaM2;                    // площадь м²

  Room({
    required this.outer,
    required this.holes,
    required this.centerMm,
    required this.areaM2,
  });
}
