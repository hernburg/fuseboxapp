import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../floor/core/vec2.dart';
import '../floor/core/geometry.dart';
import '../floor/core/node_graph.dart';
import '../floor/core/wall_model.dart';
import '../floor/draw/wall_painter.dart';
import '../floor/edit/snapping.dart';


class FloorEditor extends StatefulWidget {
  const FloorEditor({super.key});

  @override
  State<FloorEditor> createState() => _FloorEditorState();
}

class _FloorEditorState extends State<FloorEditor> {
  late final FloorEditorController _controller;
  int _activePointers = 0;
  bool _viewCentered = false;
  // World size: 1000 meters by 1000 meters. The project uses millimeter units
  // for geometry (wall thickness was set to 200 = 200 mm), so convert meters
  // to millimeters here.
  static const double _worldMeters = 1000.0;
  static const double _metersToMillimeters = 1000.0;

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
    _activePointers++;
    if (_activePointers == 1) {
      final w = _screenToWorld(event.localPosition);
      _controller.startDraw(w);
    } else {
      // If a second pointer appears (pinch), cancel any ongoing drawing
      _controller.cancelDraw();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointers == 1) {
      final w = _screenToWorld(event.localPosition);
      _controller.updateDraw(w);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_activePointers == 1) {
      _controller.endDraw();
    }
    _activePointers = _activePointers > 0 ? _activePointers - 1 : 0;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers = _activePointers > 0 ? _activePointers - 1 : 0;
    _controller.cancelDraw();
  }

  Vec2 _screenToWorld(Offset screenPoint) {
    // Copy current transform, invert it and apply to screen point to get world coords
    final m = Matrix4.copy(_controller.viewTransform.value);
    m.invert();
    final v = m.transform3(vm.Vector3(screenPoint.dx, screenPoint.dy, 0.0));
    return Vec2(v.x, v.y);
  }

  // pointer-to-Vec2 conversion removed; pointer handlers disabled.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактор этажа'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _controller.undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _controller.redo,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _controller.clearAll,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final worldWidth = _worldMeters * _metersToMillimeters;
          final worldHeight = _worldMeters * _metersToMillimeters;

          // Center the large world in the viewport on first build
          if (!_viewCentered) {
            final dx = (constraints.maxWidth - worldWidth) / 2.0;
            final dy = (constraints.maxHeight - worldHeight) / 2.0;
            _controller.viewTransform.value = Matrix4.translationValues(dx, dy, 0.0);
            _viewCentered = true;
          }
          return Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: InteractiveViewer(
              transformationController: _controller.viewTransform,
              minScale: 0.2,
              maxScale: 8.0,
              constrained: false,
              scaleEnabled: true,
              panEnabled: true,
              child: SizedBox(
                width: worldWidth,
                height: worldHeight,
                child: CustomPaint(
                  painter: WallPainter(
                    _controller.walls,
                    preview: _controller.previewWalls,
                    transform: _controller.viewTransform.value,
                  ),
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

  // View transform for InteractiveViewer
  final TransformationController viewTransform = TransformationController();

  // History
  final List<List<WallSegment>> _undoStack = [];
  final List<List<WallSegment>> _redoStack = [];

  bool _drawing = false;
  Vec2? _p1;
  // Snap state disabled while builder is turned off.

  FloorEditorController() {
    _nodeGraph = NodeGraph(walls: _walls);
  }

  List<WallSegment> get walls => List.unmodifiable(_walls);

  List<WallSegment> get previewWalls => List.unmodifiable(_previewWalls);

  void startDraw(Vec2 point) {
    final snap = SnapManager(walls: _walls, nodeGraph: _nodeGraph).findSnap(point);
    _p1 = snap.snapped;
    _drawing = true;
    _previewWalls.clear();
    notifyListeners();
  }

  void updateDraw(Vec2 point) {
    if (!_drawing || _p1 == null) return;

    final snap = SnapManager(walls: _walls, nodeGraph: _nodeGraph).findSnap(point);
    final p2 = snap.snapped;

    final length = (p2 - _p1!).length;

    _previewWalls.clear();

    if (length >= minWallLength) {
      _previewWalls.add(WallSegment(
        id: NodeGraph.newSegmentId(),
        p1: _p1!,
        p2: p2,
        thickness: WallSegment.defaultThickness,
      ));
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

  // _determineBaseWallForNode is disabled while builder is turned off.

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
        _saveStateForUndo();
      }
    }
  }

  void _saveStateForUndo() {
    _undoStack.add(_walls.map((w) => w.copy()).toList());
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_walls.map((w) => w.copy()).toList());
    final prev = _undoStack.removeLast();
    _walls
      ..clear()
      ..addAll(prev.map((w) => w.copy()));
    _nodeGraph.rebuildFromWalls();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_walls.map((w) => w.copy()).toList());
    final next = _redoStack.removeLast();
    _walls
      ..clear()
      ..addAll(next.map((w) => w.copy()));
    _nodeGraph.rebuildFromWalls();
    notifyListeners();
  }

  void clearAll() {
    if (_walls.isEmpty) return;
    _saveStateForUndo();
    _walls.clear();
    _previewWalls.clear();
    _nodeGraph.rebuildFromWalls();
    notifyListeners();
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
    _p1 = null;
  }
}
