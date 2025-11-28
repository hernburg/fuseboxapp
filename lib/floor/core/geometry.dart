import 'wall_model.dart';
import 'node_graph.dart';
import 'vec2.dart';


/// Класс Geometry предоставляет геометрические утилиты для построения стен и анализа пересечений.
class Geometry {
  // Removed unused segment id generator. NodeGraph handles ID generation.

  static bool segmentsIntersect(Vec2 a, Vec2 b, Vec2 c, Vec2 d) {
    bool straddles(Vec2 p, Vec2 q, Vec2 r, Vec2 s) {
      double cross1 = (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
      double cross2 = (q.x - p.x) * (s.y - p.y) - (q.y - p.y) * (s.x - p.x);
      return cross1 * cross2 <= 0;
    }
    return straddles(a, b, c, d) && straddles(c, d, a, b);
  }

  static Vec2 intersectionPoint(Vec2 a, Vec2 b, Vec2 c, Vec2 d) {
    double a1 = b.y - a.y;
    double b1 = a.x - b.x;
    double c1 = a1 * a.x + b1 * a.y;

    double a2 = d.y - c.y;
    double b2 = c.x - d.x;
    double c2 = a2 * c.x + b2 * c.y;

    double det = a1 * b2 - a2 * b1;
    if (det.abs() < 1e-9) {
      return Vec2((a.x + b.x) / 2, (a.y + b.y) / 2);
    }
    double x = (b2 * c1 - b1 * c2) / det;
    double y = (a1 * c2 - a2 * c1) / det;
    return Vec2(x, y);
  }

  static bool areCollinear(WallSegment seg1, WallSegment seg2) {
    Vec2 v1 = seg1.p2 - seg1.p1;
    Vec2 v2 = seg2.p2 - seg2.p1;
    double cross = v1.x * v2.y - v1.y * v2.x;
    if (cross.abs() > 1e-6) return false;
    double dist1 = _pointToLineDistance(seg1.p1, seg1.p2, seg2.p1);
    double dist2 = _pointToLineDistance(seg1.p1, seg1.p2, seg2.p2);
    return dist1 < 1e-3 && dist2 < 1e-3;
  }

  static double _pointToLineDistance(Vec2 a, Vec2 b, Vec2 p) {
    double area2 = ((b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)).abs();
    // Use Vec2.length getter; don't call it like a function
    double base = (b - a).length;
    return base < 1e-9 ? (p - a).length : area2 / base;
  }

  static bool isDuplicateSegment(WallSegment a, WallSegment b) {
    bool directMatch = (a.p1.x == b.p1.x && a.p1.y == b.p1.y && a.p2.x == b.p2.x && a.p2.y == b.p2.y);
    bool reverseMatch = (a.p1.x == b.p2.x && a.p1.y == b.p2.y && a.p2.x == b.p1.x && a.p2.y == b.p1.y);
    return directMatch || reverseMatch;
  }

  static WallSegment? mergeCollinear(WallSegment a, WallSegment b) {
    if (!areCollinear(a, b)) return null;
    Vec2 dir = (a.p2 - a.p1).normalized();
    List<Vec2> points = [a.p1, a.p2, b.p1, b.p2];
    points.sort((p1, p2) =>
      (p1.x * dir.x + p1.y * dir.y).compareTo(p2.x * dir.x + p2.y * dir.y)
    );
    Vec2 minPoint = points.first;
    Vec2 maxPoint = points.last;
    return WallSegment(
      id: NodeGraph.newSegmentId(),
      p1: minPoint,
      p2: maxPoint,
      thickness: a.thickness,
      thickToLeft: a.thickToLeft,
    );
  }
}
