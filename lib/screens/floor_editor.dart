import '../floor/core/vec2.dart';
import '../floor/core/geometry.dart';
import '../floor/core/node_graph.dart';
import '../floor/core/wall_model.dart';
import '../floor/edit/snapping.dart';
import '../floor/edit/wall_builder_v5.dart';
import '../floor/edit/pick_corner.dart';


class FloorEditor {
  static const double minWallLength = 20.0;
  final List<WallSegment> _walls = [];
  late NodeGraph _nodeGraph;
  bool _drawing = false;
  Vec2? _p1;
  SnapHit? _snapStart;
  final List<WallSegment> _previewWalls = [];

  FloorEditor() {
    _nodeGraph = NodeGraph(walls: _walls);
  }

  void startDraw(Vec2 point) {
    SnapHit snap = SnapManager(walls: _walls, nodeGraph: _nodeGraph).findSnap(point);
    if (snap.kind == SnapKind.edge) {
      _p1 = snap.snapped;
      _snapStart = snap;
    } else if (snap.kind == SnapKind.node) {
      _p1 = snap.snapped;
      _snapStart = snap;
    } else {
      _p1 = point;
      _snapStart = SnapHit(kind: SnapKind.none, snapped: point);
    }
    _drawing = true;
  }

  void updateDraw(Vec2 point) {
    if (!_drawing || _p1 == null) return;
    _previewWalls.clear();
    SnapHit snapEnd = SnapManager(walls: _walls, nodeGraph: _nodeGraph).findSnap(point);
    Vec2 p2 = snapEnd.snapped;
    WallSegment? previewWall;

    if (_snapStart != null && _snapStart!.kind == SnapKind.edge) {
      WallSegment base = _snapStart!.wall!;
      bool isLeft = _snapStart!.isLeftSide;
      previewWall = WallBuilderV5.buildFromSide(base, _p1!, isLeft, p2 - _p1!);
    } else if (_snapStart != null && _snapStart!.kind == SnapKind.node) {
      WallSegment base = _determineBaseWallForNode(_p1!, p2 - _p1!);
      previewWall = WallBuilderV5.buildFromCorner(base, _p1!, p2 - _p1!);
    } else {
      previewWall = WallBuilderV5.buildFree(_p1!, p2);
    }

    if (previewWall != null) {
      _previewWalls.add(previewWall);
    }
  }

  WallSegment _determineBaseWallForNode(Vec2 nodePos, Vec2 gestureVector) {
    List<WallSegment> adjacent = _walls.where((w) => (w.p1 - nodePos).length() < 1e-6 || (w.p2 - nodePos).length() < 1e-6).toList();
    if (adjacent.isEmpty) {
      throw Exception("Base wall not found for node at $nodePos");
    }
    if (adjacent.length == 1) return adjacent.first;
    return pickNearestWallForNode(nodePos, adjacent, gestureVector);
  }

  void endDraw() {
    if (!_drawing) return;
    _drawing = false;
    for (WallSegment seg in _previewWalls) {
      _walls.add(seg);
    }

    _nodeGraph.mergeNodesIfClose();

    if (_previewWalls.isNotEmpty) {
      WallSegment newSeg = _previewWalls.first;
      for (WallSegment wall in List.from(_walls)) {
        if (wall == newSeg) continue;
        if (Geometry.segmentsIntersect(newSeg.p1, newSeg.p2, wall.p1, wall.p2)) {
          if ((newSeg.p1 - wall.p1).length() < 1e-6 || (newSeg.p1 - wall.p2).length() < 1e-6 ||
              (newSeg.p2 - wall.p1).length() < 1e-6 || (newSeg.p2 - wall.p2).length() < 1e-6) {
            continue;
          } else {
            Vec2 inter = Geometry.intersectionPoint(newSeg.p1, newSeg.p2, wall.p1, wall.p2);
            List<WallSegment> newSegParts = newSeg.splitAt(inter);
            List<WallSegment> wallParts = wall.splitAt(inter);
            _walls.remove(newSeg);
            _walls.remove(wall);
            _walls.addAll(newSegParts);
            _walls.addAll(wallParts);
            WallNode node = _nodeGraph.nodes.last;
            _nodeGraph.adjustCornersAtNode(node);
            newSeg = newSegParts[0];
          }
        }
      }
    }

    for (int i = 0; i < _walls.length; i++) {
      for (int j = i + 1; j < _walls.length; j++) {
        WallSegment a = _walls[i];
        WallSegment b = _walls[j];
        if (Geometry.isDuplicateSegment(a, b)) {
          _walls.removeAt(j);
          j--;
          continue;
        }
        if (Geometry.areCollinear(a, b)) {
          WallSegment? merged = Geometry.mergeCollinear(a, b);
          if (merged != null) {
            _walls.remove(b);
            _walls.remove(a);
            _walls.add(merged);
            _nodeGraph.mergeNodesIfClose();
            if (merged.nodeStart != null) _nodeGraph.adjustCornersAtNode(merged.nodeStart!);
            if (merged.nodeEnd != null) _nodeGraph.adjustCornersAtNode(merged.nodeEnd!);
            i = -1;
            break;
          }
        }
      }
    }

    _previewWalls.clear();
    _snapStart = null;
    _p1 = null;
  }

  void cancelDraw() {
    _drawing = false;
    _previewWalls.clear();
    _snapStart = null;
    _p1 = null;
  }

  List<WallSegment> getAllWalls() => _walls;
}
