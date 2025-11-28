import 'dart:math';
import '../core/wall_model.dart';
import '../core/geometry.dart';
import '../core/node_graph.dart';
import '../core/vec2.dart';
import 'snapping.dart';
import 'pick_corner.dart';

enum BuildMode { collinear, ortho }

class WallBuilderV5 {
  static BuildMode? detectBuildMode(Vec2 gestureDir, Vec2 baseDir) {
    Vec2 u = gestureDir.normalized();
    Vec2 v = baseDir.normalized();
    double dot = u.dot(v);
    if (dot.abs() > 0.966) {
      return BuildMode.collinear;
    }
    if (dot.abs() < 0.259) {
      return BuildMode.ortho;
    }
    return null;
  }

  static WallSegment? buildFree(Vec2 p1, Vec2 p2) {
  Vec2 delta = p2 - p1;
  double length = delta.length;
    if (length < 20.0) return null;

    double angle = atan2(delta.y, delta.x);
    double deg = angle * 180 / pi;
    if (deg % 90 < 5 || deg % 90 > 85) {
      double snappedAngle = (deg % 90 < 5) ? (deg - (deg % 90)) : (deg + (90 - (deg % 90)));
      double rad = snappedAngle * pi / 180;
      delta = Vec2(cos(rad) * length, sin(rad) * length);
      p2 = p1 + delta;
    }

    return WallSegment(
      id: NodeGraph.newSegmentId(),
      p1: p1,
      p2: p2,
      thickness: WallSegment.defaultThickness,
      thickToLeft: true,
    );
  }

  static WallSegment? buildFromCorner(WallSegment baseWall, Vec2 nodePoint, Vec2 gestureDir) {
    Vec2 baseDir = (baseWall.p2 - baseWall.p1).normalized();
    BuildMode? mode = detectBuildMode(gestureDir, baseDir);

    Vec2 newDir;
    if (mode == BuildMode.collinear) {
      newDir = (gestureDir.dot(baseDir) >= 0) ? baseDir : baseDir * -1;
    } else if (mode == BuildMode.ortho) {
      Vec2 normLeft = baseDir.rotated90CCW();
      Vec2 normRight = baseDir.rotated90CW();
      newDir = (normLeft.dot(gestureDir) > normRight.dot(gestureDir)) ? normLeft : normRight;
    } else {
      newDir = gestureDir.normalized();
    }

    Vec2 baseOuterNorm = baseWall.thickToLeft ? baseDir.rotated90CCW() : baseDir.rotated90CW();
    Vec2 newNormLeft = newDir.rotated90CCW();
    Vec2 newNormRight = newDir.rotated90CW();
    bool newThickToLeft = (baseOuterNorm.dot(newNormLeft) >= baseOuterNorm.dot(newNormRight));

  double projLength = gestureDir.dot(newDir) * gestureDir.length;
    if (projLength < 20.0) return null;

    Vec2 newP2 = nodePoint + newDir * projLength;
    WallSegment newWall = WallSegment(
      id: NodeGraph.newSegmentId(),
      p1: nodePoint,
      p2: newP2,
      thickness: baseWall.thickness,
      thickToLeft: newThickToLeft,
    );

    WallNode node = WallNode(position: nodePoint);
    newWall.nodeStart = node;
    node.attachSegments([newWall]);
    return newWall;
  }

  static WallSegment? buildFromSide(WallSegment baseWall, Vec2 attachPoint, bool isLeftSide, Vec2 gestureDir) {
    WallNode attachNode = WallNode(position: attachPoint);
    List<WallSegment> splitParts = baseWall.splitAt(attachPoint);

    Vec2 baseDir = (baseWall.p2 - baseWall.p1).normalized();
    BuildMode? mode = detectBuildMode(gestureDir, baseDir);
    if (mode == BuildMode.collinear) {
      mode = BuildMode.ortho;
    }

    Vec2 newDir;
    if (mode == BuildMode.ortho) {
      newDir = isLeftSide ? baseDir.rotated90CCW() : baseDir.rotated90CW();
      if (newDir.dot(gestureDir) < 0) {
        newDir = newDir * -1;
      }
    } else {
      newDir = gestureDir.normalized();
    }

    Vec2 baseOuterNorm = baseWall.thickToLeft ? baseDir.rotated90CCW() : baseDir.rotated90CW();
    Vec2 newNormLeft = newDir.rotated90CCW();
    Vec2 newNormRight = newDir.rotated90CW();
    bool newThickToLeft = (baseOuterNorm.dot(newNormLeft) >= baseOuterNorm.dot(newNormRight));

  double projLength = gestureDir.dot(newDir) * gestureDir.length;
    if (projLength < 20.0) return null;

    Vec2 newP2 = attachPoint + newDir * projLength;
    WallSegment newWall = WallSegment(
      id: NodeGraph.newSegmentId(),
      p1: attachPoint,
      p2: newP2,
      thickness: baseWall.thickness,
      thickToLeft: newThickToLeft,
      nodeStart: attachNode,
    );
    attachNode.attachSegments([newWall]);
    return newWall;
  }
}
