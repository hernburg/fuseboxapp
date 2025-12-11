import '../core/vec2.dart';
import '../core/wall_model.dart';

WallSegment pickNearestWallForNode(Vec2 nodePos, List<WallSegment> candidates, Vec2 gestureVector) {
  WallSegment? best;
  double bestDot = -double.infinity;
  for (var wall in candidates) {
    Vec2 dir = (wall.p2 - wall.p1).normalized();
    if ((wall.p2 - nodePos).length < 1e-6) {
      dir = (wall.p1 - wall.p2).normalized();
    }
    double d = dir.dot(gestureVector.normalized());
    if (d > bestDot) {
      best = wall;
      bestDot = d;
    }
  }
  return best!;
}
