import 'wall_model.dart';
import 'geometry.dart';
import 'vec2.dart';

class NodeGraph {
  final List<WallNode> nodes = [];
  final List<WallSegment> walls;
  static int _nextSegmentId = 1000;

  NodeGraph({required this.walls});

  static int newSegmentId() => _nextSegmentId++;

  void rebuildFromWalls({double eps = 0.5}) {
    nodes.clear();
    for (final wall in walls) {
      final start = _getOrCreateNode(wall.p1, eps: eps);
      final end = _getOrCreateNode(wall.p2, eps: eps);

      wall.nodeStart = start;
      wall.nodeEnd = end;
      start.attachSegments([wall]);
      end.attachSegments([wall]);
      wall.updateCorners();
    }
    mergeNodesIfClose(eps: eps);
  }

  void mergeNodesIfClose({double eps = 1.0}) {
    for (int i = 0; i < walls.length; i++) {
      for (int j = i + 1; j < walls.length; j++) {
        WallSegment a = walls[i];
        WallSegment b = walls[j];

        if ((a.p2 - b.p1).length < eps) {
          _unifyNodes(segA: a, endOfA: true, segB: b, startOfB: true);
        }
        if ((a.p1 - b.p1).length < eps) {
          _unifyNodes(segA: a, endOfA: false, segB: b, startOfB: true);
        }
        if ((a.p2 - b.p2).length < eps) {
          _unifyNodes(segA: a, endOfA: true, segB: b, startOfB: false);
        }
        if ((a.p1 - b.p2).length < eps) {
          _unifyNodes(segA: a, endOfA: false, segB: b, startOfB: false);
        }
      }
    }
  }

  void _unifyNodes({
    required WallSegment segA,
    required bool endOfA,
    required WallSegment segB,
    required bool startOfB,
  }) {
    Vec2 unifiedPos = endOfA ? segA.p2 : segA.p1;
    WallNode? existingNode = _findNodeAt(unifiedPos);
    WallNode node = existingNode ?? WallNode(position: unifiedPos);
    if (existingNode == null) nodes.add(node);

    if (endOfA) {
      segA.nodeEnd = node;
    } else {
      segA.nodeStart = node;
    }
    if (startOfB) {
      segB.nodeStart = node;
    } else {
      segB.nodeEnd = node;
    }

    node.attachSegments([segA, segB]);
    segA.attachToNodes();
    segB.attachToNodes();
    adjustCornersAtNode(node);
  }

  WallNode? _findNodeAt(Vec2 pos, {double eps = 0.5}) {
    for (var node in nodes) {
      if ((node.position - pos).length < eps) {
        return node;
      }
    }
    return null;
  }

  void adjustCornersAtNode(WallNode node) {
    List<WallSegment> segs = node.segments;
    if (segs.length < 2) return;

    if (segs.length == 2) {
      WallSegment a = segs[0];
      WallSegment b = segs[1];

      Vec2 dirA = (a.p2 - a.p1).normalized();
      if ((node.position - a.p2).length < 1e-6) {
        dirA = (a.p1 - a.p2).normalized();
      }

      Vec2 dirB = (b.p2 - b.p1).normalized();
      if ((node.position - b.p2).length < 1e-6) {
        dirB = (b.p1 - b.p2).normalized();
      }

      double dot = dirA.dot(dirB);

      if (dot.abs() > 0.999) return;

      if (dot.abs() < 0.1) {
        // Very sharp corner — inner corner should be at the node position
        final innerCornerPoint = node.position;
        if (a.thickToLeft) {
          a.r1 = innerCornerPoint;
        } else {
          a.l1 = innerCornerPoint;
        }
        if (b.thickToLeft) {
          b.r1 = innerCornerPoint;
        } else {
          b.l1 = innerCornerPoint;
        }
      } else {
        Vec2 aOuterLineDir = a.thickToLeft ? dirA.rotated90CCW() : dirA.rotated90CW();
        Vec2 bOuterLineDir = b.thickToLeft ? dirB.rotated90CCW() : dirB.rotated90CW();

        Vec2 point = Geometry.intersectionPoint(
          node.position, node.position + aOuterLineDir,
          node.position, node.position + bOuterLineDir,
        );

        if (a.thickToLeft) {
          a.l1 = point;
        } else {
          a.r1 = point;
        }
        if (b.thickToLeft) {
          b.l1 = point;
        } else {
          b.r1 = point;
        }
      }
      a.updateCorners();
      b.updateCorners();
    } else {
      for (var seg in segs) {
        seg.updateCorners();
      }
    }
  }

  WallNode _getOrCreateNode(Vec2 pos, {double eps = 0.5}) {
    return _findNodeAt(pos, eps: eps) ?? _createNode(pos);
  }

  WallNode _createNode(Vec2 pos) {
    final node = WallNode(position: pos);
    nodes.add(node);
    return node;
  }
}
