// lib/screens/floor_editor.dart

import 'package:flutter/material.dart';
import '../floor/edit/snapping.dart';
import '../floor/core/wall_model.dart';
import '../floor/draw/wall_painter.dart';
import '../floor/edit/selection.dart';
import '../floor/rooms/room_detector.dart';

class FloorEditor extends StatefulWidget {
  const FloorEditor({super.key});

  @override
  State<FloorEditor> createState() => _FloorEditorState();
}

enum Tool { pencil, marquee, hand }

class _FloorEditorState extends State<FloorEditor> {
  // ---------- ПАРАМЕТРЫ/СОСТОЯНИЕ ----------
  // сетка/матчасть
  double _gridMm = 500;
  bool   _gridOn = true;

  bool _isDrawing = false;
  bool _isMarqueeing = false;

  bool _snapsOn = true;     // включены ли умные привязки
  bool _gridSnapOn = true;  // «прилипать» к сетке

  // свойства стен по умолчанию
  double _thickMm  = 120;
  double _heightMm = 2700;
  WallMaterial _mat = WallMaterial.concrete;

  // вьюпорт
  double _scale = 0.12;                // px per mm
  Offset _panPx = const Offset(80,80); // смещение канвы
  final EdgeInsets _pad = const EdgeInsets.all(80);

  // текущая разметка/рисование
  Offset? _dragStartMm;
  Offset? _dragCurMm;
  Offset? _fingerPx; // просто для превью-хелперов (крестик/подсказка)

  // выделение
  final Set<int> _sel = {};         // индексы выбранных стен
  Rect? _marqueeWorld;              // прямоугольник выделения в мм
  Tool _tool = Tool.pencil;

  // стены/помещения
  final List<WallSeg> _walls = [];
  List<RoomRect> _rooms = [];

  // жест scale (пан+зуум)
  Offset? _lastFocalPx;
  double  _scaleBase = 1.0;

  // ---------- УТИЛИТЫ КООРДИНАТ ----------
  Offset _mm2px(Offset mm) => Offset(
        mm.dx * _scale + _panPx.dx + _pad.left,
        mm.dy * _scale + _panPx.dy + _pad.top,
      );

  Offset _px2mm(Offset px) => Offset(
        (px.dx - _panPx.dx - _pad.left) / _scale,
        (px.dy - _panPx.dy - _pad.top)  / _scale,
      );

  // ---------- ОПЕРАЦИИ ----------
  void _recalcRooms() {
    // детект только прямоугольных помещений (поддерживается библиотекой)
    _rooms = detectRectRooms(_walls);
  }

  void _addWall(Offset aMm, Offset bMm) {
  // Проверка, чтобы не создавать слишком короткие стены
  if ((bMm - aMm).distance < 1) return;

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
    final remain = <WallSeg>[];
    for (int i=0;i<_walls.length;i++) {
      if (!_sel.contains(i)) remain.add(_walls[i]);
    }
    _walls
      ..clear()
      ..addAll(remain);
    _sel.clear();
    _recalcRooms();
    setState(() {});
  }

  void _applyToSelection({double? thickMm, double? heightMm, WallMaterial? mat}) {
    if (_sel.isEmpty) return;
    for (final i in _sel) {
      final w = _walls[i];
      _walls[i] = w.copyWith(
        thickMm: thickMm ?? w.thickMm,
        heightMm: heightMm ?? w.heightMm,
        material: mat ?? w.material,
      );
    }
    setState(() {});
  }

  // ---------- UI ПОМОЩНИКИ ----------
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
          content: StatefulBuilder(builder: (c, ss) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${tmp.toStringAsFixed(0)} $unit'),
                Slider(
                  min: min,
                  max: max,
                  divisions: ((max - min) ~/ step).clamp(1, 1000),
                  value: tmp,
                  onChanged: (v) => ss(() => tmp = v),
                ),
              ],
            );
          }),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Отмена')),
            ElevatedButton(onPressed: ()=> Navigator.pop(c, tmp), child: const Text('ОК')),
          ],
        );
      },
    );
  }

  Future<void> _pickThickness(BuildContext ctx) async {
    final v = await _pickNumber(ctx, title: 'Толщина стены', current: _thickMm, unit: 'мм', min: 50, max: 500, step: 10);
    if (v!=null) setState(()=> _thickMm = v);
  }

  Future<void> _pickHeight(BuildContext ctx) async {
    final v = await _pickNumber(ctx, title: 'Высота стены', current: _heightMm, unit: 'мм', min: 1000, max: 4000, step: 50);
    if (v!=null) setState(()=> _heightMm = v);
  }

  Future<void> _pickMaterial(BuildContext ctx) async {
    final mapNames = <WallMaterial, String>{
      WallMaterial.concrete : 'Бетон',
      WallMaterial.brick    : 'Кирпич',
      WallMaterial.aerated  : 'Газобетон',
      WallMaterial.wood     : 'Дерево',
      WallMaterial.drywall  : 'ГКЛ',
      // если у тебя есть другие значения в enum — они отрисуются своим .name
    };

    WallMaterial sel = _mat;
    final picked = await showDialog<WallMaterial>(
      context: ctx,
      builder: (c){
        return AlertDialog(
          title: const Text('Материал стен'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in WallMaterial.values)
                  RadioListTile<WallMaterial>(
                    value: m,
                    groupValue: sel,
                    onChanged: (v)=> Navigator.pop(c, v),
                    title: Text(mapNames[m] ?? m.name),
                  )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Отмена')),
          ],
        );
      }
    );
    if (picked!=null) setState(()=> _mat = picked);
  }

  // ---------- GESTURES: только onScale* (пан/зум/рисование) ----------
 void _handleDrawStart(Offset localPx) {
  if (_tool != Tool.pencil) return;
  final tapMm = _px2mm(localPx);

  // старт — ровно под пальцем, но с умной привязкой к вершинам/концам/сетке
  final start = snapStartToCornerOrEnd(
    tapMm: tapMm,
    walls: _walls,
    gridOn: _gridSnapOn,
    gridMm: _gridMm.toInt(),
  );

  _dragStartMm = start;
  _dragCurMm   = start;
  _fingerPx    = localPx;
  setState((){});

    if (_tool != Tool.pencil) return;
    _dragStartMm = _px2mm(localPx);
    _dragCurMm   = _dragStartMm;
    _fingerPx    = localPx;
    setState((){});  
  }

  void _handleDrawUpdate(Offset localPx) {
    if (_tool != Tool.pencil) return;
    _dragCurMm = _px2mm(localPx);
    _fingerPx  = localPx;
    setState((){});
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = _buildToolbar(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
// ---------- КАНВА ----------
Positioned.fill(
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,

 onScaleStart: (details) {
  _lastFocalPx = details.localFocalPoint;
  _scaleBase   = _scale;

  final single = details.pointerCount == 1;

  // старт рисования — только 1 палец и инструмент Карандаш
  if (single && _tool == Tool.pencil) {
    _isDrawing = true;
    _handleDrawStart(details.localFocalPoint);
  }

  // старт рамки — только 1 палец и инструмент Область
  if (single && _tool == Tool.marquee) {
    _isMarqueeing = true;
    final w = _px2mm(details.localFocalPoint);
    _marqueeWorld = Rect.fromPoints(w, w);
    setState((){});
  }
 },

     onScaleUpdate: (details) {
      final now   = details.localFocalPoint;
      final delta = now - (_lastFocalPx ?? now);
    _lastFocalPx = now;

  final single = details.pointerCount == 1;

  setState(() {
    if (!single) {
      // двумя пальцами — зум (во всех режимах), якорим фокус
      final worldAtFocal = _px2mm(now);
      _scale = (_scaleBase * details.scale).clamp(0.05, 6.0);
      _panPx = now - worldAtFocal * _scale;

      // если пользователь «добавил» второй палец — отменяем активное рисование/рамку
      _isDrawing = false;
      _isMarqueeing = false;
    } else {
      if (_tool == Tool.hand) {
        _panPx += delta; // пан одной пальцем только в «Рука»
      }
      // Pencil/Marquee — канву не двигаем
    }
  });

  if (_isDrawing) {
    _handleDrawUpdate(now);
  }
    if (_isMarqueeing && _marqueeWorld != null) {
     final w = _px2mm(now);
     _marqueeWorld = Rect.fromPoints(_marqueeWorld!.topLeft, w);
     setState((){});
   }
 },

     onScaleEnd: (_) {
     _lastFocalPx = null;

     if (_isDrawing) {
      _handleDrawEnd();
     }
     _isDrawing = false;

     if (_isMarqueeing && _marqueeWorld != null) {
     final picked = marqueePick(_walls, _marqueeWorld!);
     _sel..clear()..addAll(picked);
      _marqueeWorld = null;
     setState((){});
   }
   _isMarqueeing = false;
 },

    onTapUp: (d) {
      if (_tool == Tool.pencil) return;
      if (_tool == Tool.marquee) return;

      final world = _px2mm(d.localPosition);
      final idx   = hitWallIndex(_walls, world);
      if (idx != null) {
        setState(() {
          if (_sel.contains(idx)) {
            _sel.remove(idx);
          } else {
            _sel.add(idx);
          }
        });
      }
    },

    child: Container(
      color: const Color(0xFF1E1F22), // ТЁМНЫЙ ФОН холста
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
       ),
       child: const SizedBox.expand(),
      ),
     ),
    ),
  ),
),
          // Верхняя панель
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white70, Colors.transparent],
                ),
              ),
              child: toolbar,
            ),
          ),

          // Инфо по помещениям (простая аннотация)
          Positioned(
            left: 12, bottom: 12 + MediaQuery.of(context).padding.bottom,
            child: _rooms.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Помещений: ${_rooms.length} • '
                      '${_rooms.map((r)=>r.areaM2).fold<double>(0, (s,a)=>s+a).toStringAsFixed(2)} м²',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------- TOOLBAR ----------
  Widget _buildToolbar(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Режимы
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toolButton(
                icon: Icons.edit,
                label: 'Карандаш',
                active: _tool == Tool.pencil,
                onTap: ()=> setState(()=> _tool = Tool.pencil),
              ),
              const SizedBox(width: 8),
              _toolButton(
                icon: Icons.crop_free,
                label: 'Область',
                active: _tool == Tool.marquee,
                onTap: ()=> setState(()=> _tool = Tool.marquee),
              ),
              const SizedBox(width: 8),
              _toolButton(
                icon: Icons.pan_tool_alt,
                label: 'Рука',
                active: _tool == Tool.hand,
                onTap: ()=> setState(()=> _tool = Tool.hand),
              ),
              const SizedBox(width: 12),
              // сетка
              FilterChip(
                label: const Text('Сетка'),
                selected: _gridOn,
                onSelected: (_)=> setState(()=> _gridOn = !_gridOn),
              ),
              const SizedBox(width: 8),
              // удалить выделенное
              ElevatedButton.icon(
                onPressed: _sel.isEmpty ? null : _deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Свойства стен (по умолчанию или «применить к выделенным»)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: ()=> _pickThickness(context),
                icon: const Icon(Icons.straighten),
                label: Text('Толщина ${_thickMm.toStringAsFixed(0)} мм'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: ()=> _pickHeight(context),
                icon: const Icon(Icons.unfold_more),
                label: Text('Высота ${_heightMm.toStringAsFixed(0)} мм'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: ()=> _pickMaterial(context),
                icon: const Icon(Icons.texture),
                label: Text('Материал: ${_mat.name}'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _sel.isEmpty
                    ? null
                    : (){
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

  Widget _toolButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      selected: active,
      onSelected: (_)=> onTap(),
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}