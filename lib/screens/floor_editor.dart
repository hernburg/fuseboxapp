// lib/screens/floor_editor.dart
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import '../floor/core/wall_model.dart';
import '../floor/draw/wall_painter.dart';
import '../floor/edit/selection.dart';
import '../floor/edit/snapping.dart';
import '../floor/rooms/room_detector.dart';

class FloorEditor extends StatefulWidget {
  const FloorEditor({super.key});
  @override
  State<FloorEditor> createState() => _FloorEditorState();
}

enum Tool { pencil, marquee, hand }
enum GuideMode { center, inner, outer }

class _FloorEditorState extends State<FloorEditor> {
  // ---------- НАСТРОЙКИ ----------
  double _gridMm = 500;
  bool _gridOn = true;
  bool _dimsOn = true;
  bool _gridSnapOn = true;

  double _thickMm = 120;
  double _heightMm = 2700;
  WallMaterial _mat = WallMaterial.concrete;

  GuideMode _guideMode = GuideMode.center;

  double _scale = 0.12;
  Offset _panPx = Offset.zero;
  final EdgeInsets _pad = const EdgeInsets.all(80);

  // ---------- ДАННЫЕ ----------
  final List<WallSeg> _walls = [];
  final Set<int> _sel = {};
  List<RoomRect> _rooms = [];

  Tool _tool = Tool.pencil;
  bool _isDrawing = false;
  bool _isMarqueeing = false;
  Offset? _dragStartMm;
  Offset? _dragCurMm;
  Rect? _marqueeWorld;
  int? _hoverIndex;

  // ---------- ЖЕСТЫ ----------
  double _gestureScale0 = 1.0;
  Offset? _gestureFocalPx0;
  Offset? _gestureFocalWorld;

  // ---------- ИСТОРИЯ ----------
  final List<List<WallSeg>> _undoStack = [];
  final List<List<WallSeg>> _redoStack = [];

  void _saveState() {
    final snapshot = _walls.map((w) => w.copyWith()).toList();
    _undoStack.add(snapshot);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final last = _undoStack.removeLast();
    _redoStack.add(_walls.map((w) => w.copyWith()).toList());
    _walls
      ..clear()
      ..addAll(last);
    _recalcRooms();
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(_walls.map((w) => w.copyWith()).toList());
    _walls
      ..clear()
      ..addAll(next);
    _recalcRooms();
    setState(() {});
  }

  // ---------- КООРДИНАТЫ ----------
  Offset _px2mm(Offset px) =>
      Offset((px.dx - _panPx.dx - _pad.left) / _scale,
          (px.dy - _panPx.dy - _pad.top) / _scale);

  void _recalcRooms() => _rooms = detectRectRooms(_walls);

  // ---------- ПРИВЯЗКА (пока только к сетке / простые хелперы) ----------
  Offset _snapToGrid(Offset pMm, double stepMm) {
    return Offset(
      (pMm.dx / stepMm).roundToDouble() * stepMm,
      (pMm.dy / stepMm).roundToDouble() * stepMm,
    );
  }

  Offset _snapIfNearGrid(Offset pMm, {double tolMm = 50}) {
    final gx = (pMm.dx / _gridMm).roundToDouble() * _gridMm;
    final gy = (pMm.dy / _gridMm).roundToDouble() * _gridMm;

    final dx = (gx - pMm.dx).abs();
    final dy = (gy - pMm.dy).abs();

    // если близко — прилипаем, иначе оставляем как есть
    return Offset(
      dx <= tolMm ? gx : pMm.dx,
      dy <= tolMm ? gy : pMm.dy,
    );
  }

  Offset? _snapToWallAxis(Offset pMm, {double maxDistMm = 60}) {
    Offset? best;
    double bestDist = maxDistMm;

    for (final w in _walls) {
      final ab = w.b - w.a;
      final len = ab.distance;
      if (len < 1e-6) continue;

      final t = ((pMm.dx - w.a.dx) * ab.dx +
              (pMm.dy - w.a.dy) * ab.dy) /
          (len * len);

      final tClamped = t.clamp(0.0, 1.0);
      final proj = Offset(
        w.a.dx + ab.dx * tClamped,
        w.a.dy + ab.dy * tClamped,
      );

      final dist = (pMm - proj).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = proj;
      }
    }

    return best;
  }

  Offset guidePoint(WallSeg w, Offset axisPoint, GuideMode mode) {
    final dir = w.dir;
    final n = Offset(-dir.dy, dir.dx);
    final half = w.thickMm / 2;

    switch (mode) {
      case GuideMode.center:
        return axisPoint;
      case GuideMode.inner:
        return axisPoint + n * half;
      case GuideMode.outer:
        return axisPoint - n * half;
    }
  }

  // ---------- СТЕНЫ ----------
  void _addWall(Offset aMm, Offset bMm) {
    if ((bMm - aMm).distance < 1) return;
    _saveState();
    _walls.add(WallSeg(
      a: aMm,
      b: bMm,
      thickMm: _thickMm,
      heightMm: _heightMm,
      material: _mat,
    ));
    _recalcRooms();
    setState(() {});
  }

  void _deleteSelected() {
    if (_sel.isEmpty) return;
    _saveState();
    _walls.removeWhere((w) => _sel.contains(_walls.indexOf(w)));
    _sel.clear();
    _recalcRooms();
    setState(() {});
  }

  void _applyToSelection({
    double? thickMm,
    double? heightMm,
    WallMaterial? mat,
  }) {
    if (_sel.isEmpty) return;
    _saveState();
    for (final i in _sel) {
      if (i < 0 || i >= _walls.length) continue;
      final w = _walls[i];
      _walls[i] = w.copyWith(
        thickMm: thickMm ?? w.thickMm,
        heightMm: heightMm ?? w.heightMm,
        material: mat ?? w.material,
      );
    }
    _recalcRooms();
    setState(() {});
  }

  // ---------- РИСОВАНИЕ ----------
  void _handleDrawStart(Offset localPx) {
    if (_tool != Tool.pencil) return;

    Offset p = _px2mm(localPx);

    if (_gridSnapOn) {
      p = _snapIfNearGrid(p);
    }

    final axis = _snapToWallAxis(p);
    if (axis != null) {
      p = axis;
    }

    _dragStartMm = p;
    _dragCurMm = p;
    _isDrawing = true;
    setState(() {});
  }

  void _handleDrawUpdate(Offset localPx) {
    if (!_isDrawing || _dragStartMm == null) return;

    Offset p = _px2mm(localPx);

    if (_gridSnapOn) {
      p = _snapIfNearGrid(p);
    }

    final axis = _snapToWallAxis(p);
    if (axis != null) {
      p = axis;
    }

    _dragCurMm = p;
    setState(() {});
  }

  void _handleDrawEnd() {
    if (_dragStartMm != null && _dragCurMm != null) {
      _addWall(_dragStartMm!, _dragCurMm!);
    }
    _isDrawing = false;
    _dragStartMm = null;
    _dragCurMm = null;
    setState(() {});
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final toolbar = _buildToolbar(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildGestureLayer(context)),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: _buildToolbarContainer(context, toolbar),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureLayer(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) {
        _gestureScale0 = _scale;
        _gestureFocalPx0 = d.localFocalPoint;
        _gestureFocalWorld = _px2mm(_gestureFocalPx0!);

        if (d.pointerCount == 1 && _tool == Tool.pencil) {
          _handleDrawStart(d.localFocalPoint);
        }
        if (d.pointerCount == 1 && _tool == Tool.marquee) {
          _isMarqueeing = true;
          final w = _px2mm(d.localFocalPoint);
          _marqueeWorld = Rect.fromPoints(w, w);
          setState(() {});
        }
      },
      onScaleUpdate: (d) {
        final now = d.localFocalPoint;
        if (d.pointerCount > 1) {
          final worldFocal = _gestureFocalWorld ?? _px2mm(now);
          setState(() {
            _scale = (_gestureScale0 * d.scale).clamp(
                MediaQuery.of(context).size.width / 100000,
                MediaQuery.of(context).size.width / 5);
            _panPx = now -
                Offset(worldFocal.dx * _scale + _pad.left,
                    worldFocal.dy * _scale + _pad.top);
          });
          return;
        }

        if (_isDrawing && _tool == Tool.pencil) _handleDrawUpdate(now);
        if (_isMarqueeing && _marqueeWorld != null) {
          final w = _px2mm(now);
          final raw = Rect.fromPoints(_marqueeWorld!.topLeft, w);
          _marqueeWorld = Rect.fromLTRB(
            min(raw.left, raw.right),
            min(raw.top, raw.bottom),
            max(raw.left, raw.right),
            max(raw.top, raw.bottom),
          );
          setState(() {});
        }
      },
      onScaleEnd: (_) {
        if (_isDrawing) _handleDrawEnd();
        if (_isMarqueeing && _marqueeWorld != null) {
          final picked = marqueePick(_walls, _marqueeWorld!);
          _sel
            ..clear()
            ..addAll(picked);
          _marqueeWorld = null;
          setState(() {});
        }
        _isDrawing = _isMarqueeing = false;
      },
      child: RepaintBoundary(
        child: CustomPaint(
          painter: WallPainter(
            walls: _walls,
            k: _scale,
            panPx: _panPx,
            pad: _pad,
            gridMm: _gridMm,
            gridOn: _gridOn,
            dragA: _dragStartMm,
            dragB: _dragCurMm,
            previewThickMm: _thickMm,
            showDims: _dimsOn,
            marqueeWorld: _marqueeWorld,
            selected: _sel,
            hoverIndex: _hoverIndex,
            rooms: _rooms, 
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  // ---------- НИЖНИЙ БАР ----------
  Widget _buildBottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _undoStack.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Назад'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _redoStack.isEmpty ? null : _redo,
              icon: const Icon(Icons.redo, size: 18),
              label: const Text('Вперёд'),
            ),
          ],
        ),
        if (_rooms.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Помещений: ${_rooms.length} • ${_rooms.map((r) => r.areaM2).fold<double>(0, (s, a) => s + a).toStringAsFixed(2)} м²',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ---------- ВЕРХНЯЯ ПАНЕЛЬ ----------
  Widget _buildToolbarContainer(BuildContext context, Widget child) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context)
                .colorScheme
                .surface
                .withOpacity(0.92),
            Theme.of(context)
                .colorScheme
                .surface
                .withOpacity(0.80),
            Colors.transparent,
          ],
        ),
      ),
      child: child,
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // инструменты
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _toolButton(Icons.edit, 'Карандаш',
                  _tool == Tool.pencil,
                  () => setState(() => _tool = Tool.pencil)),
              const SizedBox(width: 8),
              _toolButton(Icons.crop_free, 'Область',
                  _tool == Tool.marquee,
                  () => setState(() => _tool = Tool.marquee)),
              const SizedBox(width: 8),
              _toolButton(Icons.pan_tool_alt, 'Рука',
                  _tool == Tool.hand,
                  () => setState(() => _tool = Tool.hand)),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Сетка'),
                selected: _gridOn,
                onSelected: (_) =>
                    setState(() => _gridOn = !_gridOn),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Привязка'),
                selected: _gridSnapOn,
                onSelected: (_) =>
                    setState(() => _gridSnapOn = !_gridSnapOn),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Размеры'),
                selected: _dimsOn,
                onSelected: (_) =>
                    setState(() => _dimsOn = !_dimsOn),
              ),
              const SizedBox(width: 8),
              DropdownButton<GuideMode>(
                value: _guideMode,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _guideMode = v);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: GuideMode.center,
                    child: Text('Напр. по центру'),
                  ),
                  DropdownMenuItem(
                    value: GuideMode.inner,
                    child: Text('Напр. внутренняя'),
                  ),
                  DropdownMenuItem(
                    value: GuideMode.outer,
                    child: Text('Напр. внешняя'),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed:
                    _sel.isEmpty ? null : _deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // параметры
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickNumber(
                  context,
                  title: 'Толщина стены',
                  current: _thickMm,
                  unit: 'мм',
                  min: 50,
                  max: 500,
                  step: 10,
                ).then((v) =>
                    v != null ? setState(() => _thickMm = v) : null),
                icon: const Icon(Icons.straighten),
                label: Text(
                    'Толщина ${_thickMm.toStringAsFixed(0)} мм'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickNumber(
                  context,
                  title: 'Высота стены',
                  current: _heightMm,
                  unit: 'мм',
                  min: 1000,
                  max: 4000,
                  step: 50,
                ).then((v) =>
                    v != null ? setState(() => _heightMm = v) : null),
                icon: const Icon(Icons.unfold_more),
                label: Text(
                    'Высота ${_heightMm.toStringAsFixed(0)} мм'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickMaterial(context),
                icon: const Icon(Icons.texture),
                label: Text('Материал: ${_mat.name}'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickNumber(
                  context,
                  title: 'Шаг сетки',
                  current: _gridMm,
                  unit: 'мм',
                  min: 50,
                  max: 2000,
                  step: 50,
                ).then((v) =>
                    v != null ? setState(() => _gridMm = v) : null),
                icon: const Icon(Icons.grid_on),
                label: Text(
                    'Сетка ${_gridMm.toStringAsFixed(0)} мм'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _sel.isEmpty
                    ? null
                    : () {
                        _applyToSelection(
                          thickMm: _thickMm,
                          heightMm: _heightMm,
                          mat: _mat,
                        );
                      },
                child: const Text('Применить к выделенным'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolButton(
      IconData icon, String label, bool active, VoidCallback onTap) {
    return ChoiceChip(
      selected: active,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  // ---------- диалог выбора ----------
  Future<double?> _pickNumber(
    BuildContext ctx, {
    required String title,
    required double current,
    required String unit,
    double min = 0,
    double max = 10000,
    double step = 10,
  }) async {
    double tmp = current.clamp(min, max);
    return showDialog<double>(
      context: ctx,
      builder: (c) {
        return AlertDialog(
          title: Text(title),
          content: StatefulBuilder(
            builder: (c, ss) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${tmp.toStringAsFixed(0)} $unit'),
                  Slider(
                    min: min,
                    max: max,
                    divisions:
                        ((max - min) ~/ step).clamp(1, 1000),
                    value: tmp,
                    onChanged: (v) =>
                        ss(() => tmp = v),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Отмена')),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, tmp),
                child: const Text('ОК')),
          ],
        );
      },
    );
  }

  Future<void> _pickMaterial(BuildContext ctx) async {
    const primary = <WallMaterial>[
      WallMaterial.concrete,
      WallMaterial.brick,
      WallMaterial.aerated,
      WallMaterial.wood,
      WallMaterial.gypsumBlock,
      WallMaterial.drywall,
    ];

    final mapNames = <WallMaterial, String>{
      WallMaterial.concrete: 'Бетон',
      WallMaterial.brick: 'Кирпич',
      WallMaterial.aerated: 'Газобетон',
      WallMaterial.wood: 'Дерево',
      WallMaterial.gypsumBlock: 'ПГП (пазогребень)',
      WallMaterial.drywall: 'ГКЛ',
    };

    final picked = await showDialog<WallMaterial>(
      context: ctx,
      builder: (c) {
        return AlertDialog(
          title: const Text('Материал стен'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in primary)
                  RadioListTile<WallMaterial>(
                    value: m,
                    groupValue: _mat,
                    onChanged: (v) =>
                        Navigator.pop(c, v),
                    title:
                        Text(mapNames[m] ?? m.name),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(c),
              child: const Text('Отмена'),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      setState(() => _mat = picked);
    }
  }
}
