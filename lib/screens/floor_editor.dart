import 'package:flutter/material.dart';

import '../floor/core/vec2.dart';
import '../floor/core/geometry.dart';
import '../floor/core/node_graph.dart';
import '../floor/core/wall_model.dart';
import '../floor/draw/wall_painter.dart';
import '../floor/edit/pick_corner.dart';
import '../floor/edit/snap_hit.dart';
import '../floor/edit/snapping.dart';
import '../floor/edit/wall_builder_v5.dart';


class FloorEditor extends StatefulWidget {
  const FloorEditor({super.key});

  @override
  State<FloorEditor> createState() => _FloorEditorState();
}

class _FloorEditorState extends State<FloorEditor> {
  late final FloorEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FloorEditorController();
    _controller.addListener(_handleControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerUpdate() => setState(() {});

  void _onPointerDown(PointerDownEvent event) {
    _controller.startDraw(_toVec(event.localPosition));
  }

  void _onPointerMove(PointerMoveEvent event) {
    _controller.updateDraw(_toVec(event.localPosition));
  }

  void _onPointerUp(PointerUpEvent event) {
    _controller.endDraw();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _controller.cancelDraw();
  }

  Vec2 _toVec(Offset offset) => Vec2(offset.dx, offset.dy);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактор этажа'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              color: Colors.grey.shade100,
              child: CustomPaint(
                painter: WallPainter(
                  _controller.walls,
                  preview: _controller.previewWalls,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FloorEditorController extends ChangeNotifier {
  static const double minWallLength = 20.0;

  final List<WallSegment> _walls = [];
  final List<WallSegment> _previewWalls = [];
  late final NodeGraph _nodeGraph;

  bool _drawing = false;
  Vec2? _p1;
  SnapHit? _snapStart;

  FloorEditorController() {
    _nodeGraph = NodeGraph(walls: _walls);
  }

  List<WallSegment> get walls => List.unmodifiable(_walls);

  List<WallSegment> get previewWalls => List.unmodifiable(_previewWalls);

  void startDraw(Vec2 point) {
  final snap = SnapManager(walls: _walls, nodeGraph: _nodeGraph).findSnap(point);
    _snapStart = snap;
    _p1 = snap.snapped;
    _drawing = true;
    _previewWalls.clear();
    notifyListeners();
  }

  void updateDraw(Vec2 point) {
    if (!_drawing || _p1 == null) return;

    _previewWalls.clear();
  final snapEnd = SnapManager(walls: _walls, nodeGraph: _nodeGraph).findSnap(point);
    final Vec2 p2 = snapEnd.snapped;

    WallSegment? previewWall;
    if (_snapStart?.kind == SnapKind.edge && _snapStart?.wall != null) {
      final base = _snapStart!.wall!;
      final isLeft = _snapStart!.isLeftSide;
      previewWall = WallBuilderV5.buildFromSide(base, _p1!, isLeft, p2 - _p1!);
    } else if (_snapStart?.kind == SnapKind.node) {
      final base = _determineBaseWallForNode(_p1!, p2 - _p1!);
      previewWall = WallBuilderV5.buildFromCorner(base, _p1!, p2 - _p1!);
    } else {
      previewWall = WallBuilderV5.buildFree(_p1!, p2);
    }

    if (previewWall != null && (previewWall.p2 - previewWall.p1).length >= minWallLength) {
      _previewWalls.add(previewWall);
    }
    notifyListeners();
  }

  void endDraw() {
    if (!_drawing) return;
    _drawing = false;

    if (_previewWalls.isEmpty) {
      _resetPreview();
      notifyListeners();
      return;
    }

    for (final seg in List<WallSegment>.from(_previewWalls)) {
      _addWallWithSplits(seg);
    }

    _mergeCollinearWalls();
  _nodeGraph.rebuildFromWalls();
    _resetPreview();
    notifyListeners();
  }

  void cancelDraw() {
    _drawing = false;
    _resetPreview();
    notifyListeners();
  }

  WallSegment _determineBaseWallForNode(Vec2 nodePos, Vec2 gestureVector) {
  final node = _nodeGraph.nodes.firstWhere(
      (n) => (n.position - nodePos).length < 1e-3,
      orElse: () => WallNode(position: nodePos),
    );
    final adjacent = node.segments.isNotEmpty
        ? node.segments
        : _walls.where((w) => (w.p1 - nodePos).length < 1e-3 || (w.p2 - nodePos).length < 1e-3).toList();

    if (adjacent.isEmpty) {
      throw Exception('Base wall not found for node at $nodePos');
    }
    if (adjacent.length == 1) return adjacent.first;
    return pickNearestWallForNode(nodePos, adjacent, gestureVector);
  }

  void _addWallWithSplits(WallSegment candidate) {
    final queue = <WallSegment>[candidate];
    while (queue.isNotEmpty) {
      final seg = queue.removeLast();
      if ((seg.p2 - seg.p1).length < minWallLength) continue;

      bool splitOccurred = false;
      for (int i = 0; i < _walls.length; i++) {
        final wall = _walls[i];
        final inter = _intersectionExcludingShared(seg, wall);
        if (inter == null) continue;

        final newSegParts = seg.splitAt(inter);
        final wallParts = wall.splitAt(inter);
        _walls.removeAt(i);
        _walls.insertAll(i, wallParts);
        queue.addAll(newSegParts);
        splitOccurred = true;
        break;
      }

      if (!splitOccurred) {
        _walls.add(seg);
      }
    }
  }

  Vec2? _intersectionExcludingShared(WallSegment a, WallSegment b) {
    if (!Geometry.segmentsIntersect(a.p1, a.p2, b.p1, b.p2)) return null;
    final inter = Geometry.intersectionPoint(a.p1, a.p2, b.p1, b.p2);
    final onA = _isNear(inter, a.p1) || _isNear(inter, a.p2);
    final onB = _isNear(inter, b.p1) || _isNear(inter, b.p2);
    if (onA && onB) return null;
    return inter;
  }

  bool _isNear(Vec2 a, Vec2 b, {double eps = 1e-6}) => (a - b).length < eps;

  void _mergeCollinearWalls() {
    bool changed;
    do {
      changed = false;
      for (int i = 0; i < _walls.length; i++) {
        for (int j = i + 1; j < _walls.length; j++) {
          final a = _walls[i];
          final b = _walls[j];

          if (Geometry.isDuplicateSegment(a, b)) {
            _walls.removeAt(j);
            changed = true;
            break;
          }

          if (Geometry.areCollinear(a, b)) {
            final merged = Geometry.mergeCollinear(a, b);
            if (merged != null) {
              _walls.removeAt(j);
              _walls.removeAt(i);
              _walls.add(merged);
              changed = true;
              break;
            }
          }
        }
        if (changed) break;
      }
    } while (changed);
  }

  void _resetPreview() {
    _previewWalls.clear();
    _snapStart = null;
    _p1 = null;
  }
}
