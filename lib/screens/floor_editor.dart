// lib/screens/floor_editor.dart
import 'dart:math';
import 'dart:ui' as ui;
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

class _FloorEditorState extends State<FloorEditor> {
  // ---------- НАСТРОЙКИ ----------
  double _gridMm = 500;
  bool _gridOn = true; // сетка только фон
  bool _dimsOn = true;
  bool _snapsOn = true; // включает/выключает все привязки

  double _thickMm = 120;
  double _heightMm = 2700;
  WallMaterial _mat = WallMaterial.concrete;

  // шаг длины стены (0 = без шага)
  double _stepMm = 100;

  // радиусы привязок в мм
  static const double _vertexSnapMm = 80; // к вершинам
  // настройки привязки для Snapper
  SnapSettings get _snapSettings => SnapSettings(
        enabled: _snapsOn,
        stepMm: _stepMm,
        vertexRadiusMm: _vertexSnapMm,
        // ортогональность ±3°
        orthoToleranceDeg: 3,
      );

  double _scale = 0.12;
  ui.Offset _panPx = ui.Offset.zero;
  final EdgeInsets _pad = const EdgeInsets.all(80);

  // ---------- ДАННЫЕ ----------
  final List<WallSeg> _walls = [];
  final Set<int> _sel = {};
  List<Room> _rooms = [];

  Tool _tool = Tool.pencil;

  bool _isDrawing = false;
  bool _isMarqueeing = false;

  ui.Offset? _dragStartMm;
  ui.Offset? _dragCurMm;

  ui.Rect? _marqueeWorld;

  int? _hoverIndex;
  ui.Offset? _hoverVertex; // подсвечиваемая вершина

  // ---------- ЖЕСТЫ ----------
  double _gestureScale0 = 1.0;
  ui.Offset? _gestureFocalPx0;
  ui.Offset? _gestureFocalWorld;

  // ---------- ИСТОРИЯ ----------
  final List<List<WallSeg>> _undoStack = [];
  final List<List<WallSeg>> _redoStack = [];

  // =========================================================
  //                       UNDO / REDO
  // =========================================================

  void _saveState() {
    final snapshot = _walls.map((w) => w.copyWith()).toList();
    _undoStack.add(snapshot);
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
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

  // =========================================================
  //                    КООРДИНАТЫ / ROOMS
  // =========================================================

  ui.Offset _px2mm(ui.Offset px) => ui.Offset(
        (px.dx - _panPx.dx - _pad.left) / _scale,
        (px.dy - _panPx.dy - _pad.top) / _scale,
      );

  void _recalcRooms() {
    _rooms = detectRooms(_walls);
  }

  // =========================================================
  //                      СТЕНЫ
  // =========================================================

  void _addWall(ui.Offset aMm, ui.Offset bMm) {
    if ((bMm - aMm).distance < 1) return;

    // защита от дубликатов/наложений – в Snapper
    if (Snapper.isDuplicateSegment(aMm, bMm, _walls)) {
      return;
    }

    _saveState();
    insertWallSmart(_walls,
    WallSeg(
        a:aMm,
        b:bMm,
        thickMm: _thickMm,
        heightMm: _heightMm,
        material: _mat,
     ),
    );
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

  // =========================================================
  //                    РИСОВАНИЕ СТЕН
  // =========================================================

  void _handleDrawStart(ui.Offset localPx) {
   if (_tool != Tool.pencil) return;

   final world = _px2mm(localPx);

   // Snapper сам решает: если попали в ребро — смещает к краю,
   // если в вершину — цепляет вершину.
   final res = Snapper.snapStart(world, _walls, _snapSettings);

   _dragStartMm = res.snapped;
   _dragCurMm = res.snapped;
   _hoverVertex = res.hoverVertex;
   _isDrawing = true;
   setState(() {});
 }

void _handleDrawUpdate(ui.Offset localPx) {
  if (!_isDrawing || _dragStartMm == null) return;

  final start = _dragStartMm!;
  final world = _px2mm(localPx);

  // Ищем ТОЛЬКО вершины, НЕ края стен
  ui.Offset? hv;
  for (final w in _walls) {
    for (final v in [w.a, w.b]) {
      if ((world - v).distance < _snapSettings.vertexRadiusMm) {
        hv = v;
        break;
      }
    }
  }

  // 1) Берём «p» без авто-снаппинга
  ui.Offset p = world;

  // 2) Продление стены ТОЛЬКО если старт сам является вершиной
  if (hv != null && (start - hv).distance < 0.5) {
    p = autoExtendFromCorner(start, world, _walls);
  }

  // 3) Закрытие контура ТОЛЬКО если тянемся к той же вершине
  if (hv != null && (p - hv).distance < 120) {
    p = hv;
  }

  // 4) Окончательный snap — ТОЛЬКО snapDrag, без остальных
  final res = Snapper.snapDrag(start, p, _walls, _snapSettings);

  _dragCurMm = res.snapped;
  _hoverVertex = res.hoverVertex ?? hv;

  setState(() {});
}

  void _handleDrawEnd() {
    if (_dragStartMm != null && _dragCurMm != null) {
      _addWall(_dragStartMm!, _dragCurMm!);
    }
    _isDrawing = false;
    _dragStartMm = null;
    _dragCurMm = null;
    _hoverVertex = null;
    setState(() {});
  }

  // =========================================================
  //                     UI / GESTURES
  // =========================================================

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
          _marqueeWorld = ui.Rect.fromPoints(w, w);
          setState(() {});
        }
      },
      onScaleUpdate: (d) {
        final now = d.localFocalPoint;

        // мультитач → масштаб/пан
        if (d.pointerCount > 1) {
          final worldFocal = _gestureFocalWorld ?? _px2mm(now);
          setState(() {
            _scale = (_gestureScale0 * d.scale).clamp(
              MediaQuery.of(context).size.width / 100000,
              MediaQuery.of(context).size.width / 5,
            );
            _panPx = now -
                ui.Offset(
                  worldFocal.dx * _scale + _pad.left,
                  worldFocal.dy * _scale + _pad.top,
                );
          });
          return;
        }

        // одиночный палец
        if (_tool == Tool.hand) {
          // панорамирование
          if (_gestureFocalPx0 != null) {
            final delta = now - _gestureFocalPx0!;
            setState(() {
              _panPx += delta;
              _gestureFocalPx0 = now;
            });
          }
          return;
        }

        if (_isDrawing && _tool == Tool.pencil) {
          _handleDrawUpdate(now);
          return;
        }

        if (_isMarqueeing && _marqueeWorld != null) {
          final w = _px2mm(now);
          final raw = ui.Rect.fromPoints(_marqueeWorld!.topLeft, w);
          _marqueeWorld = ui.Rect.fromLTRB(
            min(raw.left, raw.right),
            min(raw.top, raw.bottom),
            max(raw.left, raw.right),
            max(raw.top, raw.bottom),
          );
          setState(() {});
          return;
        }

        // просто ведём пальцем в режиме карандаша — подсветка ближайшей вершины
        if (_tool == Tool.pencil && !_isDrawing && !_isMarqueeing) {
          final world = _px2mm(now);
          final res = Snapper.snapStart(world, _walls, _snapSettings);
          setState(() {
            _hoverVertex = res.hoverVertex;
          });
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

        _isDrawing = false;
        _isMarqueeing = false;
        _gestureFocalPx0 = null;
        _gestureFocalWorld = null;
      },
      child: RepaintBoundary(
        child: CustomPaint(
          painter: WallPainter(
            walls: _walls,
            rooms: _rooms,
            k: _scale,
            panPx: _panPx,
            pad: _pad,
            gridMm: _gridMm,
            gridOn: _gridOn,
            dragA: _dragStartMm,
            dragB: _dragCurMm,
            previewThickMm: _thickMm,
            showDims:  _dimsOn,
            marqueeWorld: _marqueeWorld,
            selected: _sel,
            hoverIndex: _hoverIndex,
            hoverVertex: _hoverVertex,
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
              'Помещений: ${_rooms.length} • '
              '${_rooms.map((r) => r.areaM2).fold<double>(0, (s, a) => s + a).toStringAsFixed(2)} м²',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ---------- ВЕРХНЯЯ ПАНЕЛЬ ----------
  Widget _buildToolbarContainer(
      BuildContext context, Widget child) {
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
                  _tool == Tool.pencil, () {
                setState(() => _tool = Tool.pencil);
              }),
              const SizedBox(width: 8),
              _toolButton(Icons.crop_free, 'Область',
                  _tool == Tool.marquee, () {
                setState(() => _tool = Tool.marquee);
              }),
              const SizedBox(width: 8),
              _toolButton(Icons.pan_tool_alt, 'Рука',
                  _tool == Tool.hand, () {
                setState(() => _tool = Tool.hand);
              }),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Привязки'),
                selected: _snapsOn,
                onSelected: (_) =>
                    setState(() => _snapsOn = !_snapsOn),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Сетка'),
                selected: _gridOn,
                onSelected: (_) =>
                    setState(() => _gridOn = !_gridOn),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Размеры'),
                selected: _dimsOn,
                onSelected: (_) =>
                    setState(() => _dimsOn = !_dimsOn),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickStep(context),
                icon: const Icon(Icons.straighten, size: 18),
                label: Text(
                  _stepMm <= 0
                      ? 'Шаг: —'
                      : 'Шаг: ${_stepMm.toStringAsFixed(0)} мм',
                ),
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

        // параметры стен / сетки
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
                ).then((v) {
                  if (v != null) {
                    setState(() => _thickMm = v);
                  }
                }),
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
                ).then((v) {
                  if (v != null) {
                    setState(() => _heightMm = v);
                  }
                }),
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
                  title: 'Шаг сетки (фон)',
                  current: _gridMm,
                  unit: 'мм',
                  min: 50,
                  max: 2000,
                  step: 50,
                ).then((v) {
                  if (v != null) {
                    setState(() => _gridMm = v);
                  }
                }),
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
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return ChoiceChip(
      selected: active,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  // ---------- диалоги ----------

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
                    onChanged: (v) => ss(() => tmp = v),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, tmp),
              child: const Text('ОК'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickStep(BuildContext ctx) async {
    final values = <double>[0, 10, 50, 100, 200, 500, 1000];
    final labels = <double, String>{
      0: 'Без шага',
      10: '10 мм',
      50: '50 мм',
      100: '100 мм',
      200: '200 мм',
      500: '500 мм',
      1000: '1000 мм',
    };

    final picked = await showDialog<double>(
      context: ctx,
      builder: (c) {
        return AlertDialog(
          title: const Text('Шаг построения'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final v in values)
                RadioListTile<double>(
                  value: v,
                  groupValue: _stepMm,
                  onChanged: (x) => Navigator.pop(c, x),
                  title: Text(labels[v]!),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Отмена'),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      setState(() => _stepMm = picked);
    }
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
                    title: Text(mapNames[m] ?? m.name),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
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
