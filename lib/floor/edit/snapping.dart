import '../core/vec2.dart';
import '../core/wall_model.dart';
import 'snap_hit.dart';
import '../core/node_graph.dart';

class SnapManager {
  final List<WallSegment> walls;
  final NodeGraph nodeGraph;
  static const double snapNodeRadius = 10.0;
  static const double snapEdgeThreshold = 8.0;

  SnapManager({required this.walls, required this.nodeGraph});

  SnapHit findSnap(Vec2 point) {
    for (var node in nodeGraph.nodes) {
      if ((node.position - point).length() <= snapNodeRadius) {
        return SnapHit(kind: SnapKind.node, snapped: node.position);
      }
    }

    for (var wall in walls) {
      Vec2 ab = wall.p2 - wall.p1;
      Vec2 ap = point - wall.p1;
      double t = (ap.dot(ab)) / (ab.dot(ab));
      if (t >= 0 && t <= 1) {
        Vec2 proj = wall.p1 + ab * t;
        if ((proj - point).length() <= snapEdgeThreshold) {
          Vec2 wallDir = (wall.p2 - wall.p1).normalized();
          Vec2 normLeft = wallDir.rotated90CCW();
          Vec2 normRight = wallDir.rotated90CW();
          Vec2 vecFromWall = point - proj;
          bool isLeft = vecFromWall.dot(normLeft) >= vecFromWall.dot(normRight);
          return SnapHit(
            kind: SnapKind.edge,
            snapped: proj,
            wall: wall,
            isLeftSide: isLeft,
          );
        }
      }
    }

    return SnapHit(kind: SnapKind.none, snapped: point);
  }
}
