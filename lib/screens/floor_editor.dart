import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../floor/core/geometry.dart' as geom;
import '../floor/core/pick_corner.dart';
import '../floor/core/wall_model.dart';
import '../floor/draw/wall_painter.dart';
import '../floor/edit/snapping.dart';
import '../floor/edit/snap_hit.dart';
import '../floor/edit/wall_builder.dart';
import '../utils/log.dart'; // ← логгер

enum _BuildMode { idle, free, corner, side }

class FloorEditor extends StatefulWidget {
  const FloorEditor({super.key});

  @override
  State<FloorEditor> createState() => _FloorEditorState();
}

class _FloorEditorState extends State<FloorEditor> {
  final List<WallSeg> _walls = [];
  final List<WallSeg> _preview = [];
  final List<List<WallSeg>> _history = [];
  int _historyIndex = -1;

  double _scale = 0.4;
  ui.Offset _panPx = ui.Offset.zero;
  final EdgeInsets _pad = const EdgeInsets.all(40);

  final SnapSettings _snapSettings =
      const SnapSettings(enabled: true, vertexRadiusMm: 120);

  // для зума/пана
  double _gestureScale0 = 1.0;
  ui.Offset? _gestureFocalWorld;

  // построение
  _BuildMode _mode = _BuildMode.idle;
  ui.Offset? _freeStart;
  ui.Offset? _baseCorner;
  ui.Offset? _attachPoint;
  SnapHit? _snap;
  WallSeg? _snapWall;
  bool _snapLeft = true;
  ui.Offset? _highlightCorner;

  WallDebugOverlay _debugOverlay = WallDebugOverlay.empty;
  static const bool _debugMode = kDebugMode;

  // толщина новой стены (можно потом сделать из настроек)
  final double _thickMm = 120;

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo => _historyIndex + 1 < _history.length;

  // --------- утилиты для логов ----------

  String _f2(ui.Offset o) =>
      '(${o.dx.toStringAsFixed(2)},${o.dy.toStringAsFixed(2)})';

  void _logEditor(String msg) {
    // единая точка входа для логов этого экрана
    logMsg('EDITOR', msg);
  }

  @override
  void initState() {
    super.initState();
    _captureHistory(); // initial empty state
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3E4858),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
                child: CustomPaint(
                  painter: WallPainter(
                    walls: [..._walls, ..._preview],
                    k: _scale,
                    panPx: _panPx,
                    pad: _pad,
                    debugMode: _debugMode,
                    debugOverlay: _debugOverlay,
                    highlightCorner: _highlightCorner,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '1 палец — рисовать\n2 пальца — зум/пан',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HistoryButton(
                          icon: Icons.undo,
                          enabled: _canUndo,
                          tooltip: 'Назад',
                          onTap: _undo,
                        ),
                        const SizedBox(width: 6),
                        _HistoryButton(
                          icon: Icons.redo,
                          enabled: _canRedo,
                          tooltip: 'Повторить',
                          onTap: _redo,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    backgroundColor: Colors.redAccent,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Очистить'),
                    onPressed: () {
                      setState(() {
                        _walls.clear();
                        _preview.clear();
                        _resetBuildState();
                        _captureHistory();
                        _logEditor('CLEAR_ALL');
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================== ЖЕСТЫ ======================

  void _handleScaleStart(ScaleStartDetails d) {
    _gestureScale0 = _scale;
    _gestureFocalWorld = _px2mm(d.localFocalPoint);

    if (d.pointerCount == 1) {
      _startDraw(d.localFocalPoint);
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails d) {
    // мультитач — зум/пан
    if (d.pointerCount > 1) {
      final now = d.localFocalPoint;
      final worldFocal = _gestureFocalWorld ?? _px2mm(now);

      setState(() {
        _scale = (_gestureScale0 * d.scale).clamp(0.05, 2.0);
        _panPx = now -
            ui.Offset(
              worldFocal.dx * _scale + _pad.left,
              worldFocal.dy * _scale + _pad.top,
            );
      });
      return;
    }

    // одиночный палец — построение
    if (_mode != _BuildMode.idle) {
      _updateDraw(d.localFocalPoint);
    }
  }

  void _handleScaleEnd(ScaleEndDetails d) {
    if (_mode != _BuildMode.idle) {
      _endDraw();
    }
    _gestureFocalWorld = null;
  }

  // ====================== ПОСТРОЕНИЕ ======================

  void _startDraw(ui.Offset localPx) {
    final world = _px2mm(localPx);
    final hit = findSnap(world, _walls, _snapSettings);

    _snap = hit.kind == SnapKind.none ? null : hit;
    _snapWall = hit.wall;
    _snapLeft = hit.isLeftSide;
    _preview.clear();

    // лог: старт построения
    _logEditor(
      'START mode? rawHit=${hit.kind} world=${_f2(world)} '
      'snap=${hit.kind != SnapKind.none ? _f2(hit.snapped) : 'none'}',
    );

    switch (hit.kind) {
      case SnapKind.vertex:
        _mode = _BuildMode.corner;
        _freeStart = null;
        _attachPoint = null;
        break;
      case SnapKind.edge:
        _mode = _BuildMode.side;
        _attachPoint = hit.snapped;
        _baseCorner = null;
        _freeStart = null;
        break;
      case SnapKind.none:
        _mode = _BuildMode.free;
        _freeStart = world;
        _snapWall = null;
        _baseCorner = null;
        _attachPoint = null;
        _snapLeft = true;
        break;
    }

    if (hit.kind == SnapKind.vertex) {
      _baseCorner = hit.vertex;
    }

    if (_mode == _BuildMode.corner &&
        (_snapWall == null || _baseCorner == null)) {
      _mode = _BuildMode.free;
      _freeStart = world;
      _snap = null;
    }

    if (_mode == _BuildMode.side &&
        (_snapWall == null || _attachPoint == null)) {
      _mode = _BuildMode.free;
      _freeStart = world;
      _snap = null;
    }

    // Подсветка угла
    if (hit.kind == SnapKind.vertex && hit.vertex != null) {
      _highlightCorner = hit.vertex;
    } else if (hit.kind == SnapKind.edge &&
        _snapWall != null &&
        _attachPoint != null) {
      _highlightCorner = _snapWall!.nearestCornerTo(_attachPoint!);
    } else {
      _highlightCorner = null;
    }

    setState(() {
      _debugOverlay = WallDebugOverlay.empty;
    });

    _logEditor('MODE=$_mode snapWall=${_snapWall != null} '
        'corner=${_baseCorner != null ? _f2(_baseCorner!) : 'none'}');
  }

  void _updateDraw(ui.Offset localPx) {
    final world = _px2mm(localPx);

    if (_mode == _BuildMode.idle) {
      return;
    }

    List<WallSeg> preview = [];
    WallDebugOverlay overlay = WallDebugOverlay.empty;

    switch (_mode) {
      case _BuildMode.free:
       if (_freeStart == null) break;

       final gesture = world - _freeStart!;
         if (gesture.distance < 1e-3) {
         preview = [];
         break;
       }

       final axisDir = geom.computeAxisDirection(gesture);
       final end = _freeStart! + axisDir * gesture.distance;
       final thickToLeft = _extrudeOpposite(_freeStart!, end, _freeStart);

       final wall = WallSeg.fromGuide(
         start: _freeStart!,
         end: end,
         thickMm: _thickMm,
         thickToLeft: thickToLeft,
       );

  // 🔥 ЛОГ ОТДЕЛЬНОЙ СВОБОДНОЙ СТЕНЫ
       logMsg('WALL', 'FREE PREVIEW '
         'a1=${wall.cornerA.dx.toStringAsFixed(2)},${wall.cornerA.dy.toStringAsFixed(2)} '
         'b1=${wall.cornerB.dx.toStringAsFixed(2)},${wall.cornerB.dy.toStringAsFixed(2)} '
         'c1=${wall.cornerC.dx.toStringAsFixed(2)},${wall.cornerC.dy.toStringAsFixed(2)} '
         'd1=${wall.cornerD.dx.toStringAsFixed(2)},${wall.cornerD.dy.toStringAsFixed(2)}');

       preview = [wall];

       overlay = WallDebugOverlay(
         snapPoint: _snap?.snapped,
         newNormalOrigin: _freeStart,
         newNormalVector: axisDir,
       );
       break;


      case _BuildMode.corner:
        if (_snapWall == null || _baseCorner == null) break;
        final gesture = world - _baseCorner!;
        if (gesture.distance < 1e-3) {
          preview = [];
          break;
        }

        final newDir = geom.computeAxisDirection(gesture);

        // даём редактору "умно" выбрать угол для подсветки,
        // но сама геометрия строится внутри builder'а
        _baseCorner = pickCornerSmart(
          baseWall: _snapWall!,
          dir: newDir,
          finger: world,
        );
        _highlightCorner = _baseCorner;

        final segments = buildWallFromCorner(
          baseWall: _snapWall!,
          baseCorner: _baseCorner!,
          gestureEnd: world,
          isLeftSide: _snapLeft,
          newThick: _thickMm,
        );
        preview = segments;

        break;

      case _BuildMode.side:
        if (_snapWall == null || _attachPoint == null) break;
        final gesture = world - _attachPoint!;
        if (gesture.distance < 1e-3) {
          preview = [];
          break;
        }

        final newDir = geom.computeAxisDirection(gesture);

        final corner = pickCornerSmart(
          baseWall: _snapWall!,
          dir: newDir,
          finger: world,
        );
        _attachPoint = corner;
        _highlightCorner = corner;

        final segments = buildWallFromSide(
          baseWall: _snapWall!,
          attachPoint: _attachPoint!,
          gestureEnd: world,
          isLeftSide: _snapLeft,
          newThick: _thickMm,
        );
        preview = segments;

        break;

      case _BuildMode.idle:
        break;
    }

    setState(() {
      _preview
        ..clear()
        ..addAll(preview);
      _debugOverlay = overlay;
    });
  }

  void _endDraw() {
  setState(() {
    if (_preview.isNotEmpty) {

      // 1. ЛОГИРУЕМ каждую стену ДО добавления в _walls
      for (final w in _preview) {
        logMsg(
          'WALL',
          'COMMIT '
            'a1=${w.cornerA.dx.toStringAsFixed(2)},${w.cornerA.dy.toStringAsFixed(2)} '
            'b1=${w.cornerB.dx.toStringAsFixed(2)},${w.cornerB.dy.toStringAsFixed(2)} '
            'c1=${w.cornerC.dx.toStringAsFixed(2)},${w.cornerC.dy.toStringAsFixed(2)} '
            'd1=${w.cornerD.dx.toStringAsFixed(2)},${w.cornerD.dy.toStringAsFixed(2)}'
        );
      }

      // 2. Коммитим стены
      _walls.addAll(_preview);

      // 3. Лого редактора
      _logEditor('COMMIT count=${_preview.length} total=${_walls.length}');

      // 4. Чистим превью + история
      _preview.clear();
      _captureHistory();
    }

    // 5. Сброс состояния
    _resetBuildState();
    _highlightCorner = null;
  });
}


  // ====================== ВСПОМОГАТЕЛЬНОЕ ======================

  ui.Offset _px2mm(ui.Offset px) {
    return ui.Offset(
      (px.dx - _panPx.dx - _pad.left) / _scale,
      (px.dy - _panPx.dy - _pad.top) / _scale,
    );
  }

  void _resetBuildState() {
    _mode = _BuildMode.idle;
    _freeStart = null;
    _baseCorner = null;
    _attachPoint = null;
    _snap = null;
    _snapWall = null;
    _snapLeft = true;
    _debugOverlay = WallDebugOverlay.empty;
  }

  bool _extrudeOpposite(ui.Offset a, ui.Offset b, ui.Offset? anchor) {
    if (anchor == null) return true;
    final dir = b - a;
    final len = dir.distance;
    if (len < 1e-6) return true;
    final rel = anchor - a;
    final cross = dir.dx * rel.dy - dir.dy * rel.dx;
    return cross > 0;
  }

  void _captureHistory() {
    if (_historyIndex + 1 < _history.length) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(List<WallSeg>.from(_walls));
    _historyIndex = _history.length - 1;
  }

  void _undo() {
    if (!_canUndo) return;
    setState(() {
      _historyIndex--;
      _walls
        ..clear()
        ..addAll(_history[_historyIndex]);
      _preview.clear();
      _resetBuildState();
      _logEditor('UNDO -> index=$_historyIndex');
    });
  }

  void _redo() {
    if (!_canRedo) return;
    setState(() {
      _historyIndex++;
      _walls
        ..clear()
        ..addAll(_history[_historyIndex]);
      _preview.clear();
      _resetBuildState();
      _logEditor('REDO -> index=$_historyIndex');
    });
  }
}

class _HistoryButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;

  const _HistoryButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final bg = enabled
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.08);
    final iconColor = enabled ? Colors.white : Colors.white24;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}
