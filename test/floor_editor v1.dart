// lib/screens/floor_editor.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models/project.dart';
import '../data/mem_repo.dart';

/* ==================== МОДЕЛИ ==================== */

enum _WallMat { brick, concrete, drywall }

class _Wall {
  /// Центр-линия стены в миллиметрах (мировые координаты)
  Offset a; // начало
  Offset b; // конец
  double thickMm;
  _WallMat mat;
  _Wall({required this.a, required this.b, required this.thickMm, required this.mat});

  Map toMap() => {
        'ax': a.dx,
        'ay': a.dy,
        'bx': b.dx,
        'by': b.dy,
        't': thickMm,
        'm': mat.name,
      };

  static _Wall fromMap(Map m) => _Wall(
        a: Offset((m['ax'] as num).toDouble(), (m['ay'] as num).toDouble()),
        b: Offset((m['bx'] as num).toDouble(), (m['by'] as num).toDouble()),
        thickMm: ((m['t'] ?? 100) as num).toDouble(),
        mat: _parseMat((m['m'] ?? 'brick') as String),
      );

  static _WallMat _parseMat(String s) {
    switch (s) {
      case 'concrete':
        return _WallMat.concrete;
      case 'drywall':
        return _WallMat.drywall;
      default:
        return _WallMat.brick;
    }
  }
}

enum _OpeningType { door, window }

class _Opening {
  final _OpeningType type;
  final int wallIdx;
  final double t; // [0..1] по оси стены (центр проёма)
  final double widthMm;
  _Opening({
    required this.type,
    required this.wallIdx,
    required this.t,
    required this.widthMm,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'w': wallIdx,
        't': t,
        'wd': widthMm,
      };

  static _Opening fromMap(Map m) => _Opening(
        type: (m['type'] == 'window') ? _OpeningType.window : _OpeningType.door,
        wallIdx: (m['w'] as num).toInt(),
        t: ((m['t'] ?? 0.5) as num).toDouble(),
        widthMm: ((m['wd'] ?? 900) as num).toDouble(),
      );
}

enum _PointType { socket, ceiling, sconce, box, switcher }

class _Point {
  final _PointType type;
  final Offset atMm;
  _Point({required this.type, required this.atMm});

  Map<String, dynamic> toMap() => {'type': type.name, 'x': atMm.dx, 'y': atMm.dy};

  static _Point fromMap(Map m) => _Point(
        type: _parsePointType((m['type'] ?? 'socket') as String),
        atMm: Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()),
      );

  static _PointType _parsePointType(String s) {
    switch (s) {
      case 'ceiling':
        return _PointType.ceiling;
      case 'sconce':
        return _PointType.sconce;
      case 'box':
        return _PointType.box;
      case 'switcher':
        return _PointType.switcher;
      case 'socket':
      default:
        return _PointType.socket;
    }
  }

  String get short {
    switch (type) {
      case _PointType.socket:
        return 'Роз.';
      case _PointType.ceiling:
        return 'Свет';
      case _PointType.sconce:
        return 'Бра';
      case _PointType.box:
        return 'Кор.';
      case _PointType.switcher:
        return 'Выкл.';
    }
  }

  Color get color {
    switch (type) {
      case _PointType.socket:
        return const Color(0xFF3DB2FF);
      case _PointType.ceiling:
        return const Color(0xFFFFD166);
      case _PointType.sconce:
        return const Color(0xFFB392F0);
      case _PointType.box:
        return const Color(0xFFA0E7A0);
      case _PointType.switcher:
        return const Color(0xFF6EE7F5);
    }
  }
}

/* ==================== ЭКРАН ==================== */

class FloorEditor extends StatefulWidget {
  final Project project;
  final int floorIndex;
  const FloorEditor({super.key, required this.project, required this.floorIndex});

  @override
  State<FloorEditor> createState() => _FloorEditorState();
}

class _FloorEditorState extends State<FloorEditor> with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late Map floor;
  late Map plan;

  // Canvas
  double scale = 1.0;
  Offset pan = Offset.zero;
  final EdgeInsets pad = const EdgeInsets.fromLTRB(24, 24, 24, 24);
  bool _panInited = false;

  // Данные
  final List<_Wall> walls = [];
  final List<_Opening> openings = [];
  final List<_Point> points = [];

  // История
  final List<Map<String, dynamic>> _history = [];
  int _histIndex = -1;
  void _pushHistory() {
    final snapshot = {
      'walls': walls.map((w) => w.toMap()).toList(),
      'openings': openings.map((o) => o.toMap()).toList(),
      'points': points.map((p) => p.toMap()).toList(),
    };
    if (_histIndex + 1 < _history.length) _history.removeRange(_histIndex + 1, _history.length);
    _history.add(snapshot);
    _histIndex = _history.length - 1;
  }

  void _restore(Map<String, dynamic> s) {
    walls
      ..clear()
      ..addAll((s['walls'] as List).map((e) => _Wall.fromMap(e as Map)));
    openings
      ..clear()
      ..addAll((s['openings'] as List).map((e) => _Opening.fromMap(e as Map)));
    points
      ..clear()
      ..addAll((s['points'] as List).map((e) => _Point.fromMap(e as Map)));
  }

  void _undo() {
    if (_histIndex > 0) {
      _histIndex--;
      _restore(_history[_histIndex]);
      setState(() {});
    }
  }

  void _redo() {
    if (_histIndex + 1 < _history.length) {
      _histIndex++;
      _restore(_history[_histIndex]);
      setState(() {});
    }
  }

  // Настройки инструментов
  double _wallThick = 100; // мм
  _WallMat _mat = _WallMat.brick;
  _OpeningType _openingTypeCurrent = _OpeningType.door;
  double _doorWidth = 900;
  double _windowWidth = 1400;
  _PointType _pointTypeCurrent = _PointType.socket;

  // Режимы
  bool _snapsOn = true;     // снэпы стен/вершин
  bool _gridSnapOn = true;  // приоритетная привязка к сетке

  // Пороговые значения / углы
  static const double _snapVertexStartBaseMm = 60.0;
  static const double _snapVertexEndBaseMm   = 40.0;
  static const double _snapParallelGapMm     = 2500.0;
  static const double _snapEdgeMm            = 700.0;
  static const double _escapeFactor          = 3.0;
  static const double _parallelTolDeg        = 10.0;
  static const double _orthoDeg              = 30.0;
  static const double _axisHelpDeg           = 10.0;

  // Построение стены: под пальцем идёт ВНУТРЕННЯЯ кромка
  Offset? dragStartMm; // внутренняя кромка, начало
  Offset? dragCurMm;   // внутренняя кромка, конец
  bool _dragging = false;
  Offset? _pendingStartMm;
  Offset? _lastFingerPx; // где показывать размер при drag

  // Превью
  _Opening? _previewOpening;
  _Point? _previewPoint;

  // Выбор/удаление
  int? _selectedWallIdx;

  bool get _isContourClosed {
    final deg = <String,int>{};
    for (final w in walls) {
      final k1 = '${w.a.dx}:${w.a.dy}';
      final k2 = '${w.b.dx}:${w.b.dy}';
      deg[k1] = (deg[k1] ?? 0) + 1;
      deg[k2] = (deg[k2] ?? 0) + 1;
    }
    return deg.values.where((v)=>v==1).isEmpty && walls.isNotEmpty;
  }

  // Multi-touch
  static const double _pinchZoomThreshold = 0.03;
  static const double _pinchSensitivity  = 0.35;

  late final TabController tab;

  @override
  void initState() {
    super.initState();
    floor = (widget.project.payload['floors'] as List)[widget.floorIndex] as Map;
    plan  = (floor['plan'] as Map?) ?? <String, dynamic>{};

    final List? oldWalls = plan['walls'] as List?;
    if (oldWalls != null &&
        oldWalls.isNotEmpty &&
        oldWalls.first is Map &&
        (oldWalls.first as Map).containsKey('ax')) {
      walls.addAll(oldWalls.map((e) => _Wall.fromMap(e as Map)));
    } else {
      final List w = oldWalls ?? [];
      for (int i = 0; i + 1 < w.length; i += 2) {
        final a = Offset((w[i]['x'] as num).toDouble(), (w[i]['y'] as num).toDouble());
        final b = Offset((w[i+1]['x'] as num).toDouble(), (w[i+1]['y'] as num).toDouble());
        walls.add(_Wall(a: a, b: b, thickMm: _wallThick, mat: _mat));
      }
    }

    final List o = (plan['openings'] as List?) ?? [];
    openings.addAll(o.map((e) => _Opening.fromMap(e as Map)));

    final List p = (plan['points'] as List?) ?? [];
    points.addAll(p.map((e) => _Point.fromMap(e as Map)));

    _pushHistory();
    tab = TabController(length: 3, vsync: this)..addListener(() => setState((){}));
  }

  /* ===== Сохранение ===== */
  void _savePlan() {
    plan['walls']    = walls.map((w) => w.toMap()).toList();
    plan['openings'] = openings.map((o) => o.toMap()).toList();
    plan['points']   = points.map((p) => p.toMap()).toList();
    floor['plan'] = plan;
    widget.project.touch();
    MemRepo().upsert(widget.project);
    _pushHistory();
  }

  /* ===== Утилиты координат ===== */
  double get k => scale;
  Offset mm2px(Offset mm) => Offset(mm.dx * k, mm.dy * k) + pan + Offset(pad.left, pad.top);
  Offset px2mm(Offset px) => (px - pan - Offset(pad.left, pad.top)) / k;

  int get gridMm {
    const desiredPx = 24.0;
    final desiredMm = (desiredPx / k).clamp(5.0, 2000.0);
    final pow10 = math.pow(10, (math.log(desiredMm) / math.ln10).floor()).toDouble();
    final candidates = <double>[1,2,5,10].map((m) => m * pow10).toList();
    double best = candidates.first, bestDelta = (best - desiredMm).abs();
    for (final c in candidates) {
      final d = (c - desiredMm).abs();
      if (d < bestDelta) { best = c; bestDelta = d; }
    }
    return best.round().clamp(1, 5000);
  }

  /* ===== Геометрия & снэпы ===== */

  double get _snapStartMm => (24.0 / k).clamp(_snapVertexStartBaseMm, 220.0);
  double get _snapEndMm   => (24.0 / k).clamp(_snapVertexEndBaseMm,   180.0);

  Offset _snapToGrid(Offset p) {
    final g = gridMm.toDouble();
    double rd(double v) => (v / g).roundToDouble() * g;
    return Offset(rd(p.dx), rd(p.dy));
  }

  List<Offset> _collectVertices() {
    final vs = <String, Offset>{};
    for (final w in walls) {
      final k1 = '${w.a.dx.toStringAsFixed(3)}:${w.a.dy.toStringAsFixed(3)}';
      final k2 = '${w.b.dx.toStringAsFixed(3)}:${w.b.dy.toStringAsFixed(3)}';
      vs[k1] = w.a; vs[k2] = w.b;
    }
    return vs.values.toList();
  }

  Offset? _nearestVertex(Offset p, double radiusMm, {Offset? exclude}) {
    Offset? best;
    double bestD = radiusMm + 1;
    for (final v in _collectVertices()) {
      if (exclude != null && (v - exclude).distance <= 1e-6) continue;
      final d = (v - p).distance;
      if (d < bestD) { bestD = d; best = v; }
    }
    return (bestD <= radiusMm) ? best : null;
  }

  Offset? _nearestWallEndNearPoint(Offset p, {double maxPerpMm = 120, double maxAlongMm = 220}) {
    Offset? best;
    double bestScore = 1e9;
    for (final w in walls) {
      final v = w.b - w.a;
      final len = v.distance;
      if (len == 0) continue;
      final dir = v / len;
      final perp = ((p - w.a).dx * dir.dy - (p - w.a).dy * dir.dx).abs();
      if (perp > maxPerpMm) continue;
      final dA = (p - w.a).distance;
      final dB = (p - w.b).distance;
      final along = math.min(dA, dB);
      if (along > maxAlongMm) continue;
      final score = perp + along * 0.25;
      if (score < bestScore) {
        bestScore = score;
        best = (dA <= dB) ? w.a : w.b;
      }
    }
    return best;
  }

  Offset _snapStartToCornerOrEnd(Offset tapMm) {
    final vtx = _nearestVertex(tapMm, _snapStartMm);
    if (vtx != null) return vtx;
    final end = _nearestWallEndNearPoint(tapMm, maxPerpMm: _snapStartMm * 1.6, maxAlongMm: _snapStartMm * 2.2);
    if (end != null) return end;
    // приоритет сетки, если рядом нет вершин
    return _gridSnapOn ? _snapToGrid(tapMm) : tapMm;
  }

  double _degBetween(Offset a, Offset b) {
    final la = a.distance, lb = b.distance;
    if (la == 0 || lb == 0) return 180;
    final cosv = ((a.dx*b.dx) + (a.dy*b.dy)) / (la*lb);
    final clamped = cosv.clamp(-1.0, 1.0) as double;
    return (math.acos(clamped) * 180 / math.pi).abs();
  }

  double _distPointToLine(Offset p, Offset x0, Offset dirUnit) {
    final v = p - x0;
    final cross = (v.dx * dirUnit.dy) - (v.dy * dirUnit.dx);
    return cross.abs();
  }

  Offset _orthoSnap(Offset aMm, Offset rawBMm) {
    final d = rawBMm - aMm;
    final len = d.distance;
    if (len == 0) return rawBMm;
    final ang = math.atan2(d.dy, d.dx);
    final deg = (ang * 180 / math.pi).abs();

    Offset candidate = rawBMm;
    final nearH = (deg <= _orthoDeg) || (deg >= 180 - _orthoDeg);
    final nearV = (deg >= 90 - _orthoDeg) && (deg <= 90 + _orthoDeg);
    if (nearH) {
      candidate = Offset(rawBMm.dx, aMm.dy);
    } else if (nearV) {
      candidate = Offset(aMm.dx, rawBMm.dy);
    }
    return candidate;
  }

  Offset _axisSnap(Offset a, Offset b) {
    final th = _axisHelpDeg * math.pi / 180.0;
    final d = b - a;
    if (d == Offset.zero) return b;
    final ang = math.atan2(d.dy, d.dx).abs();
    if (ang <= th || (math.pi - ang) <= th) return Offset(b.dx, a.dy);
    if ((ang - math.pi/2).abs() <= th)   return Offset(a.dx, b.dy);
    return b;
  }

  Offset _smartSnapWallEnd(Offset aMm, Offset rawBMm) {
    // приоритет сетки
    if (_gridSnapOn) rawBMm = _snapToGrid(rawBMm);

    final vtxEnd = _nearestVertex(rawBMm, _snapEndMm, exclude: aMm);
    if (vtxEnd != null) return vtxEnd;

    Offset b = _orthoSnap(aMm, rawBMm);

    final d = b - aMm;
    final len = d.distance;
    if (len > 0.0001 && walls.isNotEmpty && _snapsOn) {
      final dir = Offset(d.dx / len, d.dy / len);

      int bestIdx = -1;
      double bestScore = -1e9;
      double bestPmin = 0, bestPmax = 0, bestGap = 1e9, bestLen = 0;
      bool   bestStartAtCorner = false;

      for (int i=0;i<walls.length;i++) {
        final w = walls[i];
        final wv = w.b - w.a;
        final wlen = wv.distance;
        if (wlen == 0) continue;
        final wdir = Offset(wv.dx / wlen, wv.dy / wlen);

        final ang = _degBetween(dir, wdir);
        if (ang > _parallelTolDeg && (180-ang) > _parallelTolDeg) continue;

        final gapA = _distPointToLine(w.a, aMm, dir);
        final gapB = _distPointToLine(w.b, aMm, dir);
        final gap = math.min(gapA, gapB);
        if (gap > _snapParallelGapMm) continue;

        final startNearCorner = (w.a - aMm).distance <= _snapStartMm ||
                                (w.b - aMm).distance <= _snapStartMm;

        final p1 = (w.a - aMm).dx * dir.dx + (w.a - aMm).dy * dir.dy;
        final p2 = (w.b - aMm).dx * dir.dx + (w.b - aMm).dy * dir.dy;
        final pmin = math.min(p1, p2);
        final pmax = math.max(p1, p2);

        final score = (pmax - pmin) - gap * 0.02 + (startNearCorner? 500.0 : 0.0);
        if (score > bestScore) {
          bestScore = score;
          bestIdx = i;
          bestPmin = pmin;
          bestPmax = pmax;
          bestGap  = gap;
          bestLen  = wlen;
          bestStartAtCorner = startNearCorner;
        }
      }

      if (bestIdx >= 0) {
        final tEnd = (b - aMm).dx * dir.dx + (b - aMm).dy * dir.dy;

        double? snappedT;
        final nearLeft  = (tEnd - bestPmin).abs() <= _snapEdgeMm;
        final nearRight = (tEnd - bestPmax).abs() <= _snapEdgeMm;
        if (nearLeft)  snappedT = bestPmin;
        if (nearRight) snappedT = (snappedT==null || (tEnd - bestPmax).abs() < (tEnd - snappedT).abs())
            ? bestPmax : snappedT;

        if (snappedT==null && bestGap <= _snapParallelGapMm * 0.8) {
          final wantLen = bestLen;
          final nearEqual = (tEnd - wantLen).abs() <= _snapEdgeMm || bestStartAtCorner;
          if (nearEqual) snappedT = wantLen;
        }

        if (snappedT != null) {
          final dir = Offset(d.dx / len, d.dy / len);
          final snappedB = aMm + Offset(dir.dx * snappedT, dir.dy * snappedT);
          final escape = math.max(_escapeFactor * _snapEdgeMm, bestLen * 0.35);
          if ((snappedB - rawBMm).distance <= escape) {
            b = snappedB;
          }
        }
      }
    }

    b = _axisSnap(aMm, b);
    final vtxAfterAxis = _nearestVertex(b, _snapEndMm, exclude: aMm);
    if (vtxAfterAxis != null) return vtxAfterAxis;
    return b;
  }

  ({int idx, double t, Offset foot, double dist}) _nearestWall(Offset p) {
    int bestIdx = -1; double bestDist = 1e9; double bestT = 0; Offset bestFoot = p;
    for (int i=0; i<walls.length; i++) {
      final w = walls[i];
      final ab = w.b - w.a;
      final len2 = ab.distanceSquared;
      if (len2 == 0) continue;
      final t = ((p - w.a).dx * ab.dx + (p - w.a).dy * ab.dy) / len2;
      final tt = t.clamp(0.0, 1.0);
      final foot = w.a + ab * tt;
      final d = (p - foot).distance;
      if (d < bestDist) { bestDist = d; bestIdx = i; bestT = tt; bestFoot = foot; }
    }


({int idx, Offset dir, Offset nrm, Offset foot, double dist}) _wallBasisAt(Offset p) {
  int bestIdx = -1;
  double bestDist = 1e9;
  Offset bestFoot = p;
  Offset bestDir = const Offset(1,0);
  for (int i=0; i<walls.length; i++) {
    final w = walls[i];
    final v = w.b - w.a;
    final len = v.distance;
    if (len == 0) continue;
    final dir = v / len;
    final t = (((p - w.a).dx * dir.dx + (p - w.a).dy * dir.dy)).clamp(0, len) as double;
    final foot = w.a + dir * t;
    final d = (p - foot).distance;
    if (d < bestDist) { bestDist = d; bestIdx = i; bestFoot = foot; bestDir = dir; }
  }
  final nrm = Offset(-bestDir.dy, bestDir.dx);
  return (idx: bestIdx, dir: bestDir, nrm: nrm, foot: bestFoot, dist: bestDist);
}

int _detectEdgeSide(Offset tapMm, {double maxDistMm = 120.0}) {
  final nb = _wallBasisAt(tapMm);
  if (nb.idx < 0) return 0;
  if (nb.dist > maxDistMm) return 0;
  final sideDot = ((tapMm - nb.foot).dx * nb.nrm.dx) + ((tapMm - nb.foot).dy * nb.nrm.dy);
  return sideDot >= 0 ? 1 : -1;
}

    return (idx: bestIdx, t: bestT, foot: bestFoot, dist: bestDist);
  }

  void _ensurePanInit(Size size) {
    if (_panInited) return;
    const double desiredMmWidth = 5000.0;
    const double sidePaddingPx = 80.0;
    final vw = size.width  - pad.horizontal;
    final vh = size.height - pad.vertical;
    final availablePx = (vw - 2 * sidePaddingPx).clamp(100.0, vw);
    scale = (availablePx / desiredMmWidth).clamp(.05, 6.0);
    pan = Offset(vw / 2, vh / 2);
    _panInited = true;
  }

  int? _hitWallIndex(Offset pMm) {
    for (int i=0;i<walls.length;i++) {
      final w = walls[i];
      final ab = w.b - w.a;
      final len = ab.distance; if (len==0) continue;
      final nx = -(ab.dy/len), ny = (ab.dx/len);
      final half = w.thickMm/2;
      final p0L = w.a + Offset(nx*half, ny*half);
      final p0R = w.a - Offset(nx*half, ny*half);
      final p1L = w.b + Offset(nx*half, ny*half);
      final p1R = w.b - Offset(nx*half, ny*half);
      final path = Path()
        ..moveTo(p0L.dx, p0L.dy)..lineTo(p1L.dx, p1L.dy)..lineTo(p1R.dx, p1R.dy)..lineTo(p0R.dx, p0R.dy)..close();
      if (path.contains(pMm)) return i;
    }
    return null;
  }

  /* ==================== BUILD ==================== */

  @override
  Widget build(BuildContext context) {
    final title = (floor['title'] ?? 'Этаж').toString();

    return WillPopScope(
      onWillPop: () async { _savePlan(); return true; },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text('Редактор: $title'),
          bottom: TabBar(
            controller: tab,
            tabs: const [Tab(text: 'Стены'), Tab(text: 'Проёмы'), Tab(text: 'Точки')],
          ),
          actions: [
            IconButton(
             tooltip: _gridSnapOn ? 'Отключить привязку к сетке' : 'Включить привязку к сетке',
             onPressed: () => setState(() => _gridSnapOn = !_gridSnapOn),
             icon: Icon(_gridSnapOn ? Icons.grid_on : Icons.grid_off),
            ),
            IconButton(
             tooltip: _snapsOn ? 'Отключить привязки' : 'Включить привязки',
             onPressed: () => setState(() => _snapsOn = !_snapsOn),
             icon: Icon(_snapsOn ? Icons.link : Icons.link_off),
            ),

            IconButton(tooltip:'Отменить', onPressed: _undo, icon: const Icon(Icons.undo)),
            IconButton(tooltip:'Вернуть', onPressed: _redo, icon: const Icon(Icons.redo)),
            IconButton(onPressed: _savePlan, icon: const Icon(Icons.save_outlined)),
          ],
        ),
        endDrawerEnableOpenDragGesture: true,
        endDrawer: _ToolsDrawer(
          wallThick: _wallThick,
          onWallThick: (v)=> setState(()=> _wallThick = v),
          mat: _mat,
          onMat: (m)=> setState(()=> _mat = m),
          doorWidth: _doorWidth,
          onDoorWidth: (v)=> setState(()=> _doorWidth = v),
          windowWidth: _windowWidth,
          onWindowWidth: (v)=> setState(()=> _windowWidth = v),
          pointType: _pointTypeCurrent,
          onPointType: (pt)=> setState(()=> _pointTypeCurrent = pt),
        ),
        body: LayoutBuilder(
          builder: (_, bc) {
            _ensurePanInit(bc.biggest);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,

              onTapDown: (e) {
                if (tab.index==0) {
                  _pendingStartMm = px2mm(e.localPosition);
                }
                final pMm = px2mm(e.localPosition);
                if (!_isContourClosed && tab.index==0) {
                  final prev = _selectedWallIdx;
                  _selectedWallIdx = _hitWallIndex(pMm);

                  if (prev != null && prev == _selectedWallIdx) {
                    final w = walls[prev];
                    final ctr = mm2px(Offset((w.a.dx+w.b.dx)/2, (w.a.dy+w.b.dy)/2));
                    if ((ctr - e.localPosition).distance <= 18) {
                      setState(() { walls.removeAt(prev); _selectedWallIdx = null; });
                      _savePlan();
                      return;
                    }
                  }
                  setState((){});
                }
              },

              onScaleStart: (d) {
                if (d.pointerCount >= 2) return;

                final pMmTap = _pendingStartMm ?? px2mm(d.localFocalPoint);
                _pendingStartMm = null;
                _lastFingerPx = d.localFocalPoint;

                if (tab.index == 0) {
                  _dragging = true;
                  final start = _snapStartToCornerOrEnd(pMmTap);
                  dragStartMm = start;      // внутренняя кромка!
                  dragCurMm = start;
                  _selectedWallIdx = null;
                } else if (tab.index == 1) {
                  final n = _nearestWall(pMmTap);
                  _previewOpening = (n.idx >= 0)
                      ? _Opening(
                          type: _openingTypeCurrent,
                          wallIdx: n.idx,
                          t: n.t,
                          widthMm: _openingTypeCurrent == _OpeningType.door ? _doorWidth : _windowWidth,
                        )
                      : null;
                } else if (tab.index == 2) {
                  _previewPoint = _Point(type: _pointTypeCurrent, atMm: pMmTap);
                }
                setState((){});
              },

              onScaleUpdate: (d) {
                _lastFingerPx = d.localFocalPoint;

                if (d.pointerCount >= 2) {
                  final ds = d.scale;
                  final isPan = (ds - 1.0).abs() <= _pinchZoomThreshold;
                  if (isPan) {
                    setState(() { pan += d.focalPointDelta; });
                  } else {
                    final coeff = 1.0 + (ds - 1.0) * _pinchSensitivity;
                    final fp = d.localFocalPoint;
                    final world = (fp - pan - Offset(pad.left, pad.top)) / k;
                    final newScale = (scale * coeff).clamp(.05, 6.0);
                    final newPan   = fp - Offset(pad.left, pad.top) - world * newScale;
                    setState(() { scale = newScale; pan = newPan; });
                  }
                  return;
                }

                final pMm = px2mm(d.localFocalPoint);
                if (tab.index == 0 && _dragging && dragStartMm != null) {
                  final snapped = _snapsOn ? _smartSnapWallEnd(dragStartMm!, pMm)
                                           : _axisSnap(dragStartMm!, pMm);
                  dragCurMm = snapped;   // внутренняя кромка
                  setState((){});
                } else if (tab.index == 1 && _previewOpening != null) {
                  final n = _nearestWall(pMm);
                  if (n.idx >= 0) {
                    _previewOpening = _Opening(
                      type: _previewOpening!.type,
                      wallIdx: n.idx,
                      t: n.t,
                      widthMm: _previewOpening!.widthMm,
                    );
                  } else {
                    _previewOpening = null;
                  }
                  setState((){});
                } else if (tab.index == 2 && _previewPoint != null) {
                  _previewPoint = _Point(type: _previewPoint!.type, atMm: pMm);
                  setState((){});
                }
              },

              onScaleEnd: (_) {
                if (tab.index == 0 && _dragging && dragStartMm != null && dragCurMm != null) {
                  final innerA = dragStartMm!;
                  final innerB = dragCurMm!;
                  if ((innerB - innerA).distance > 0) {
                    // Сохраняем центр-линию так, чтобы внутренняя кромка совпала с тем, что было под пальцем
                    final d = innerB - innerA;
                    final len = d.distance;
                    final dir = d / len;
                    final nx = -dir.dy;
                    final ny =  dir.dx;
                    final shift = Offset(nx, ny) * (_wallThick/2);
                    final centerA = innerA + shift;
                    final centerB = innerB + shift;

                    setState(() {
                      walls.add(_Wall(a: centerA, b: centerB, thickMm: _wallThick, mat: _mat));
                    });
                    _savePlan();
                  }
                  _dragging = false; dragStartMm = null; dragCurMm = null; _lastFingerPx = null;
                } else if (tab.index == 1 && _previewOpening != null) {
                  setState(() { openings.add(_previewOpening!); _previewOpening = null; });
                  _savePlan();
                } else if (tab.index == 2 && _previewPoint != null) {
                  setState(() { points.add(_previewPoint!); _previewPoint = null; });
                  _savePlan();
                }
              },

              child: CustomPaint(
                painter: _FloorPainter(
                  walls: walls,
                  openings: openings,
                  points: points,
                  k: k,
                  pan: pan,
                  pad: pad,
                  dragStart: dragStartMm,   // внутренняя кромка
                  dragCur: dragCurMm,       // внутренняя кромка
                  dragFingerPx: _lastFingerPx,
                  gridMm: gridMm,
                  previewOpening: _previewOpening,
                  previewPoint: _previewPoint,
                  wallThickCurrent: _wallThick,
                  selectedWallIdx: _selectedWallIdx,
                  contourClosed: _isContourClosed,
                ),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
  }
void _mergeCollinearAtNodes({double epsMm = 1.0, double angleTolDeg = 2.0}) {
  bool changed = true;
  bool eq(Offset p, Offset q) => (p - q).distance <= epsMm;
  while (changed) {
    changed = false;
    outer:
    for (int i = 0; i < walls.length; i++) {
      for (int j = i + 1; j < walls.length; j++) {
        final wi = walls[i], wj = walls[j];
        Offset? common;
        bool eqA = eq(wi.a, wj.a), eqB = eq(wi.a, wj.b), eqC = eq(wi.b, wj.a), eqD = eq(wi.b, wj.b);
        if (eqA) common = wi.a; else if (eqB) common = wi.a; else if (eqC) common = wi.b; else if (eqD) common = wi.b;
        if (common == null) continue;
        if (wi.thickMm != wj.thickMm || wi.mat != wj.mat) continue;
        if (!_areCollinear(wi.a, wi.b, wj.a, wj.b, angleTolDeg)) continue;
        final pts = <Offset>[wi.a, wi.b, wj.a, wj.b];
        final dir = (wi.b - wi.a);
        final len = dir.distance; if (len == 0) continue;
        final u = dir / len;
        double proj(Offset p) => ((p - common!).dx * u.dx + (p - common!).dy * u.dy);
        double minT = 0, maxT = 0;
        for (final p in pts) { final t = proj(p); if (t < minT) minT = t; if (t > maxT) maxT = t; }
        final newA = common! + u * minT;
        final newB = common! + u * maxT;
        walls[i] = _Wall(a: newA, b: newB, thickMm: wi.thickMm, mat: wi.mat);
        walls.removeAt(j);
        changed = true;
        break outer;
      }
    }
  }
}
}

/* ==================== ИНСТРУМЕНТЫ (правое меню) ==================== */

class _ToolsDrawer extends StatelessWidget {
  final double wallThick;
  final ValueChanged<double> onWallThick;
  final _WallMat mat;
  final ValueChanged<_WallMat> onMat;

  final double doorWidth;
  final ValueChanged<double> onDoorWidth;
  final double windowWidth;
  final ValueChanged<double> onWindowWidth;

  final _PointType pointType;
  final ValueChanged<_PointType> onPointType;

  const _ToolsDrawer({
    required this.wallThick, required this.onWallThick,
    required this.mat, required this.onMat,
    required this.doorWidth, required this.onDoorWidth,
    required this.windowWidth, required this.onWindowWidth,
    required this.pointType, required this.onPointType,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 240,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('Стены', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [80,100,150,200,300,450].map((t)=>
              ChoiceChip(
                label: Text('$t мм'),
                selected: wallThick.round()==t,
                onSelected: (_)=> onWallThick(t.toDouble()),
              )).toList(),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<_WallMat>(
              value: mat,
              decoration: const InputDecoration(labelText: 'Материал', border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem(value: _WallMat.brick,    child: Text('Кирпич')),
                DropdownMenuItem(value: _WallMat.concrete, child: Text('Бетон')),
                DropdownMenuItem(value: _WallMat.drywall,  child: Text('ГКЛ')),
              ],
              onChanged: (v){ if (v!=null) onMat(v); },
            ),
            const Divider(height: 24),

            const Text('Проёмы', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Дверь, ширина:'),
            Wrap(spacing: 6, runSpacing: 6, children: [700,800,900,1000,1200,1500].map((w)=>
              ChoiceChip(
                label: Text('$w'),
                selected: doorWidth.round()==w,
                onSelected: (_)=> onDoorWidth(w.toDouble()),
              )).toList(),
            ),
            const SizedBox(height: 8),
            const Text('Окно, ширина (мм):'),
            _NumberField(
              value: windowWidth.round(),
              onChanged: (v){ final n = int.tryParse(v) ?? 1400; onWindowWidth(n.toDouble()); },
            ),
            const Divider(height: 24),

            const Text('Электрика', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<_PointType>(
              value: pointType,
              decoration: const InputDecoration(labelText: 'Электрика', border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem(value: _PointType.socket,   child: Row(children:[Icon(Icons.power, size:16), SizedBox(width:8), Text('Розетка')])),
                DropdownMenuItem(value: _PointType.switcher, child: Row(children:[Icon(Icons.toggle_on_outlined, size:16), SizedBox(width:8), Text('Выключатель')])),
                DropdownMenuItem(value: _PointType.ceiling,  child: Row(children:[Icon(Icons.light_mode_outlined, size:16), SizedBox(width:8), Text('Потолочный свет')])),
                DropdownMenuItem(value: _PointType.sconce,   child: Row(children:[Icon(Icons.light_outlined, size:16), SizedBox(width:8), Text('Бра')])),
                DropdownMenuItem(value: _PointType.box,      child: Row(children:[Icon(Icons.square_outlined, size:16), SizedBox(width:8), Text('Коробка')])),
              ],
              onChanged: (v){ if (v!=null) onPointType(v); },
            ),
          ],
        ),
      ),
    );
  }
}


bool _areCollinear(Offset a1, Offset b1, Offset a2, Offset b2, double angleTolDeg) {
  final v1 = b1 - a1; final v2 = b2 - a2;
  final l1 = v1.distance; final l2 = v2.distance;
  if (l1 == 0 || l2 == 0) return false;
  final cosv = ((v1.dx*v2.dx + v1.dy*v2.dy) / (l1*l2)).clamp(-1.0, 1.0);
  final ang = (math.acos(cosv) * 180.0 / math.pi).abs();
  return (ang <= angleTolDeg) || (180 - ang <= angleTolDeg);
}



class _NumberField extends StatelessWidget {
  final int value;
  final ValueChanged<String> onChanged;
  const _NumberField({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = TextEditingController(text: value.toString());
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        hintText: 'мм',
      ),
      onChanged: onChanged,
    );
  }
}

/* ==================== ВСПОМОГАТЕЛЬНЫЕ КЛАССЫ ==================== */

class _JointInfo {
  Offset p;
  int count;
  double maxHalf;
  _JointInfo(this.p, this.count, this.maxHalf);
}

/* ==================== PAINTER ==================== */

class _FloorPainter extends CustomPainter {
  final List<_Wall> walls;
  final List<_Opening> openings;
  final List<_Point> points;
  final double k;
  final Offset pan;
  final EdgeInsets pad;
  final Offset? dragStart; // внутренняя кромка
  final Offset? dragCur;   // внутренняя кромка
  final Offset? dragFingerPx; // положение пальца
  final int gridMm;

  // Превью + текущая толщина
  final _Opening? previewOpening;
  final _Point? previewPoint;
  final double wallThickCurrent;

  // Выбор/контур
  final int? selectedWallIdx;
  final bool contourClosed;

  _FloorPainter({
    required this.walls,
    required this.openings,
    required this.points,
    required this.k,
    required this.pan,
    required this.pad,
    required this.dragStart,
    required this.dragCur,
    required this.dragFingerPx,
    required this.gridMm,
    required this.previewOpening,
    required this.previewPoint,
    required this.wallThickCurrent,
    required this.selectedWallIdx,
    required this.contourClosed,
  });

  Offset mm2px(Offset mm) => Offset(mm.dx * k, mm.dy * k) + pan + Offset(pad.left, pad.top);

  @override
  void paint(Canvas c, Size s) {
    // фон
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF111418));

    // вьюпорт рамка
    final rect = Rect.fromLTWH(pad.left, pad.top, s.width - pad.horizontal, s.height - pad.vertical);
    c.drawRect(rect, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = const Color(0x22FFFFFF));

    // сетка
    final origin = Offset(pad.left, pad.top) + pan;
    final stepPx = gridMm * k;
    final grid1 = Paint()..color = const Color(0x18FFFFFF)..strokeWidth = 1;
    final grid2 = Paint()..color = const Color(0x33FFFFFF)..strokeWidth = 1.2;
    final firstX = rect.left - (rect.left - origin.dx) % stepPx;
    for (double x = firstX; x <= rect.right + .5; x += stepPx) {
      c.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid1);
    }
    final firstY = rect.top - (rect.top - origin.dy) % stepPx;
    for (double y = firstY; y <= rect.bottom + .5; y += stepPx) {
      c.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid1);
    }
    final step5 = stepPx * 5;
    final firstX5 = rect.left - (rect.left - origin.dx) % step5;
    for (double x = firstX5; x <= rect.right + .5; x += step5) {
      c.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid2);
    }
    final firstY5 = rect.top - (rect.top - origin.dy) % step5;
    for (double y = firstY5; y <= rect.bottom + .5; y += step5) {
      c.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid2);
    }

    // сгруппировать проёмы
    final Map<int, List<_Opening>> holesByWall = {};
    for (final o in openings) { (holesByWall[o.wallIdx] ??= []).add(o); }

    // стены прямоугольниками
    final wallFill   = Paint()..color = Colors.white..isAntiAlias = false;
    final seamStroke = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = .6;

    for (int i=0; i<walls.length; i++) {
      final w = walls[i];
      final a = w.a, b = w.b;
      final ab = b - a;
      final len = ab.distance;
      if (len < 1e-6) continue;

      final ux = ab.dx/len,  uy = ab.dy/len;
      final nx = -uy,        ny = ux;

      // вырезы
      final cuts = <(double,double)>[];
      if (holesByWall.containsKey(i)) {
        for (final o in holesByWall[i]!) {
          final half = (o.widthMm/2) / len;
          final t0 = (o.t - half).clamp(0.0, 1.0);
          final t1 = (o.t + half).clamp(0.0, 1.0);
          if (t1 > t0) cuts.add((t0,t1));
        }
        cuts.sort((x,y)=>x.$1.compareTo(y.$1));
        final merged = <(double,double)>[];
        for (final seg in cuts) {
          if (merged.isEmpty || seg.$1 > merged.last.$2) {
            merged.add(seg);
          } else {
            final last = merged.removeLast();
            merged.add((last.$1, math.max(last.$2, seg.$2)));
          }
        }
        cuts..clear()..addAll(merged);
      }

      double fromT = 0.0;
      void drawSpan(double t0,double t1) {
        const extendMm = 0.6;
        final p0 = Offset(a.dx+ab.dx*t0, a.dy+ab.dy*t0) - Offset(ux*extendMm, uy*extendMm);
        final p1 = Offset(a.dx+ab.dx*t1, a.dy+ab.dy*t1) + Offset(ux*extendMm, uy*extendMm);

        final halfT = w.thickMm/2;
        final p0L = p0 + Offset(nx*halfT, ny*halfT);
        final p0R = p0 - Offset(nx*halfT, ny*halfT);
        final p1L = p1 + Offset(nx*halfT, ny*halfT);
        final p1R = p1 - Offset(nx*halfT, ny*halfT);

        final path = Path()
          ..moveTo(mm2px(p0L).dx, mm2px(p0L).dy)
          ..lineTo(mm2px(p1L).dx, mm2px(p1L).dy)
          ..lineTo(mm2px(p1R).dx, mm2px(p1R).dy)
          ..lineTo(mm2px(p0R).dx, mm2px(p0R).dy)
          ..close();

        c.drawPath(path, wallFill);
        _hatch(c, path, w.mat);
        c.drawPath(path, seamStroke);
      }

      for (final cut in cuts) {
        if (cut.$1 > fromT) drawSpan(fromT, cut.$1);
        fromT = cut.$2;
      }
      if (fromT < 1.0) drawSpan(fromT, 1.0);

      // Размер — по центру, внутри помещения (смещение по нормали)
      final mid = Offset(a.dx + ab.dx*0.5, a.dy + ab.dy*0.5);
      final insideOffset = Offset(nx,ny) * (w.thickMm/2 + (12.0/k));
      _label(c, mm2px(mid + insideOffset), '${len.toStringAsFixed(0)} мм');
    }

    _paintJointCaps(c);
    _paintOpeningDims(c);
    _paintPreviewWall(c);

    for (final t in points) _drawPointWithRays(c, t.atMm, t.short, t.color, true);
    if (previewPoint != null) _drawPointWithRays(c, previewPoint!.atMm, previewPoint!.short, previewPoint!.color.withOpacity(.85));

    _paintPreviewOpening(c);

    // корзина удаления
    if (!contourClosed && selectedWallIdx!=null && selectedWallIdx!>=0 && selectedWallIdx!<walls.length) {
      final w = walls[selectedWallIdx!];
      final ctr = mm2px(Offset((w.a.dx+w.b.dx)/2, (w.a.dy+w.b.dy)/2));
      final r = Rect.fromCenter(center: ctr, width: 28, height: 28);
      final bg = RRect.fromRectAndRadius(r, const Radius.circular(6));
      c.drawRRect(bg, Paint()..color = const Color(0xCC2B2F33));
      final icon = Icons.delete_outline;
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
        ..pushStyle(ui.TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'MaterialIcons'));
      pb.addText(String.fromCharCode(icon.codePoint));
      final par = pb.build()..layout(const ui.ParagraphConstraints(width: 28));
      c.drawParagraph(par, Offset(r.left, r.top+4));
    }
  }

  // ——— угловые колпаки — внешний/внутренний
  void _paintJointCaps(Canvas c) {
    final Map<String, _JointInfo> deg = <String, _JointInfo>{};
    String keyOf(Offset p) => '${p.dx.toStringAsFixed(3)}:${p.dy.toStringAsFixed(3)}';
    void addV(Offset p, double half) {
      final k = keyOf(p);
      final cur = deg[k];
      if (cur == null) { deg[k] = _JointInfo(p, 1, half); }
      else { cur.count += 1; if (half > cur.maxHalf) cur.maxHalf = half; }
    }
    for (final w in walls) { addV(w.a, w.thickMm/2); addV(w.b, w.thickMm/2); }

    final paintInner = Paint()..color = Colors.white;
    final paintOuter = Paint()..color = Colors.white;
    double rPix(double mm) => (mm * k).clamp(1.0, 9999.0);

    for (final v in deg.values) {
      if (v.count >= 2) {
        c.drawCircle(mm2px(v.p), rPix(v.maxHalf*1.02), paintOuter); // внешний
        c.drawCircle(mm2px(v.p), rPix(v.maxHalf*0.96), paintInner); // внутренний
      }
    }
  }

  void _paintOpeningDims(Canvas c) {
    final holesByWall = <int, List<_Opening>>{};
    for (int i=0;i<openings.length;i++) {
      final o = openings[i];
      (holesByWall[o.wallIdx] ??= []).add(o);
    }
    for (final entry in holesByWall.entries) {
      final i = entry.key;
      final list = entry.value;
      final w = walls[i];
      final a = w.a; final b = w.b;
      final ab = b - a; final len = ab.distance; if (len==0) continue;
      final ux = ab.dx/len; final uy = ab.dy/len;
      final nx = -uy; final ny = ux;
      final halfT = w.thickMm/2;

      for (final o in list) {
        final center = Offset(a.dx + ab.dx*o.t, a.dy + ab.dy*o.t);
        final pL = center - Offset(ux * (o.widthMm/2), uy * (o.widthMm/2));
        final pR = center + Offset(ux * (o.widthMm/2), uy * (o.widthMm/2));
        final pL1 = pL + Offset(nx * halfT, ny * halfT);
        final pL2 = pL - Offset(nx * halfT, ny * halfT);
        final pR1 = pR + Offset(nx * halfT, ny * halfT);
        final pR2 = pR - Offset(nx * halfT, ny * halfT);

        final edge = Paint()..color = const Color(0xFF2A2E34)..strokeWidth = 1.5;
        final edgeLight = Paint()..color = Colors.white.withOpacity(.75)..strokeWidth = 0.75;
        c.drawLine(mm2px(pL1), mm2px(pL2), edge);
        c.drawLine(mm2px(pR1), mm2px(pR2), edge);
        c.drawLine(mm2px(pL1), mm2px(pL2), edgeLight);
        c.drawLine(mm2px(pR1), mm2px(pR2), edgeLight);

        final above = Offset(nx * (halfT + 12.0/k), ny * (halfT + 12.0/k));
        c.drawLine(mm2px(a + above), mm2px(pL + above), Paint()..color = Colors.white70..strokeWidth = 1.0);
        c.drawLine(mm2px(pR + above), mm2px(b + above), Paint()..color = Colors.white70..strokeWidth = 1.0);

        const tickMm = 6.0;
        void ticks(Offset base) {
          final t1 = base + above + Offset(nx*tickMm, ny*tickMm);
          final t2 = base + above - Offset(nx*tickMm, ny*tickMm);
          c.drawLine(mm2px(t1), mm2px(t2), Paint()..color = Colors.white70..strokeWidth = 1.0);
        }
        ticks(a); ticks(pL); ticks(pR); ticks(b);

        final distAL = (o.t*len) - (o.widthMm/2);
        final distRB = (1-o.t)*len - (o.widthMm/2);
        _label(c, mm2px((a+pL)/2 + above) + const Offset(6, -16), '${distAL.toStringAsFixed(0)} мм');
        _label(c, mm2px((pR+b)/2 + above) + const Offset(6, -16), '${distRB.toStringAsFixed(0)} мм');
      }
    }
  }

  // превью строящейся стены: прямоугольник по толщине и размер у пальца
  void _paintPreviewWall(Canvas c) {
    if (dragStart == null || dragCur == null) return;

    final a = dragStart!;
    final b = dragCur!;
    final ab = b - a;
    final len = ab.distance;
    if (len <= 0) return;

    final dir = ab / len;
    final nx = -dir.dy;
    final ny =  dir.dx;
    final halfT = wallThickCurrent / 2;

    double startShift = 0.0;
    for (final w in walls) {
      if ((w.a - a).distance <= 1e-6 || (w.b - a).distance <= 1e-6) {
        startShift = halfT;
        break;
      }
    }
    final aShifted = a + Offset(nx * startShift, ny * startShift);

    final p0L = aShifted + Offset(nx * halfT, ny * halfT);
    final p0R = aShifted - Offset(nx * halfT, ny * halfT);
    final p1L = b + Offset(nx * halfT, ny * halfT);
    final p1R = b - Offset(nx * halfT, ny * halfT);

    final path = Path()
      ..moveTo(mm2px(p0L).dx, mm2px(p0L).dy)
      ..lineTo(mm2px(p1L).dx, mm2px(p1L).dy)
      ..lineTo(mm2px(p1R).dx, mm2px(p1R).dy)
      ..lineTo(mm2px(p0R).dx, mm2px(p0R).dy)
      ..close();

    c.drawPath(path, Paint()..color = Colors.white.withOpacity(.72)..isAntiAlias = true);

    final labelAt = (dragFingerPx != null)
        ? dragFingerPx! + const Offset(-30, -26)
        : mm2px((aShifted + b) / 2) + const Offset(6, -22);
    _label(c, labelAt, '${len.toStringAsFixed(0)} мм');

    c.drawLine(
      mm2px(aShifted),
      mm2px(b),
      Paint()
        ..color = Colors.black.withOpacity(.30)
        ..strokeWidth = 1.0
        ..isAntiAlias = true,
    );
  }

  void _paintPreviewOpening(Canvas c) {
    if (previewOpening == null) return;

    final o = previewOpening!;
    if (o.wallIdx < 0 || o.wallIdx >= walls.length) return;

    final w = walls[o.wallIdx];
    final ab = w.b - w.a;
    final len = ab.distance;
    if (len <= 0) return;

    final ux = ab.dx / len, uy = ab.dy / len;
    final nx = -uy, ny = ux;
    final halfT = w.thickMm / 2;
    final center = Offset(w.a.dx + ab.dx * o.t, w.a.dy + ab.dy * o.t);
    final halfW = o.widthMm / 2;

    final pL = center - Offset(ux * halfW, uy * halfW);
    final pR = center + Offset(ux * halfW, uy * halfW);

    final pL1 = pL + Offset(nx * halfT, ny * halfT);
    final pL2 = pL - Offset(nx * halfT, ny * halfT);
    final pR1 = pR + Offset(nx * halfT, ny * halfT);
    final pR2 = pR - Offset(nx * halfT, ny * halfT);

    final edge = Paint()..color = Colors.white.withOpacity(.85)..strokeWidth = 1.0;
    c.drawLine(mm2px(pL1), mm2px(pL2), edge);
    c.drawLine(mm2px(pR1), mm2px(pR2), edge);

    final above = Offset(nx * (halfT + 12.0 / k), ny * (halfT + 12.0 / k));
    c.drawLine(mm2px(w.a + above), mm2px(pL + above), Paint()..color = Colors.white60..strokeWidth = 1.0);
    c.drawLine(mm2px(pR + above), mm2px(w.b + above), Paint()..color = Colors.white60..strokeWidth = 1.0);

    const tickMm = 6.0;
    void tick(Offset base) {
      final t1 = base + above + Offset(nx * tickMm, ny * tickMm);
      final t2 = base + above - Offset(nx * tickMm, ny * tickMm);
      c.drawLine(mm2px(t1), mm2px(t2), Paint()..color = Colors.white60..strokeWidth = 1.0);
    }
    tick(w.a); tick(pL); tick(pR); tick(w.b);

    final distAL = (o.t * len) - halfW;
    final distRB = (1 - o.t) * len - halfW;
    _label(c, mm2px((w.a + pL) / 2 + above) + const Offset(6, -16),
        '${distAL.toStringAsFixed(0)} мм');
    _label(c, mm2px((pR + w.b) / 2 + above) + const Offset(6, -16),
        '${distRB.toStringAsFixed(0)} мм');
  }

  // Две ближайшие стены — для лучей от точек
  List<({int idx, double t, Offset foot, double dist})> _twoNearestWallsLocal(Offset p) {
    final res = <({int idx,double t,Offset foot,double dist})>[];
    for (int i=0; i<walls.length; i++) {
      final w = walls[i];
      final ab = w.b - w.a;
      final len2 = ab.distanceSquared;
      if (len2 == 0) continue;
      final t = ((p - w.a).dx * ab.dx + (p - w.a).dy * ab.dy) / len2;
      final tt = t.clamp(0.0, 1.0);
      final foot = w.a + ab * tt;
      final d = (p - foot).distance;
      res.add((idx:i, t:tt, foot:foot, dist:d));
    }
    res.sort((x,y)=>x.dist.compareTo(y.dist));
    return res.take(2).toList();
  }

  void _drawPointWithRays(Canvas c, Offset atMm, String label, Color color, [bool bold=false]) {
    final p = mm2px(atMm);
    c.drawCircle(p, 7, Paint()..color = color);
    c.drawCircle(p, 7, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.black45);

    final two = _twoNearestWallsLocal(atMm);
    if (two.isNotEmpty) {
      final paint = Paint()..color = Colors.white70..strokeWidth = bold?1.6:1.2;
      for (final pr in two) {
        final footPx = mm2px(pr.foot);
        c.drawLine(p, footPx, paint);
        final off = (atMm - pr.foot).distance;
        _label(c, footPx + const Offset(8,-16), '${off.toStringAsFixed(0)} мм');
      }
    }
    _label(c, p + const Offset(10, -16), label);
  }

  /* ====== ШТРИХОВКИ ====== */

  void _hatch(Canvas c, Path path, _WallMat mat) {
    final r = path.getBounds();
    c.save();
    c.clipPath(path);

    double toStepMm(double px) => (px / k).clamp(0.6, 40.0);

    final pMain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x33000000);
    final pLight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = const Color(0x22000000);

    void lines(double angleRad, double stepMm, {Paint? p}) {
      final step = stepMm * k;
      final pnt = p ?? pMain;
      final cosA = math.cos(angleRad), sinA = math.sin(angleRad);
      final diag = r.width + r.height;
      for (double d = -diag; d <= diag; d += step) {
        final p1 = Offset(r.left, r.top) + Offset(d*cosA, d*sinA);
        final p2 = p1 + Offset(r.width * -sinA, r.width * cosA) + Offset(r.height * cosA, r.height * sinA);
        c.drawLine(p1, p2, pnt);
      }
    }

    if (mat == _WallMat.brick) {
      final brickH = toStepMm(10);
      final brickW = toStepMm(32);
      final joint = (toStepMm(1.8)).clamp(1.0, 3.0);
      final paintJoint = Paint()
        ..color = const Color(0x33000000)
        ..strokeWidth = joint;

      for (double y = r.top; y <= r.bottom + 1; y += brickH * k) {
        c.drawLine(Offset(r.left, y), Offset(r.right, y), paintJoint);
      }
      int row = 0;
      for (double y = r.top; y <= r.bottom + brickH*k; y += brickH * k, row++) {
        final offset = (row.isEven ? 0.0 : (brickW * 0.5) * k);
        for (double x = r.left - brickW*k; x <= r.right + brickW*k; x += brickW * k) {
          final xx = x + offset;
          final y1 = y;
          final y2 = (y + brickH * k).clamp(r.top, r.bottom);
          c.drawLine(Offset(xx, y1), Offset(xx, y2), paintJoint);
        }
      }
    } else if (mat == _WallMat.concrete) {
      lines(math.pi/6, toStepMm(4));
      lines(-math.pi/6, toStepMm(12), p: pLight);

      final dots = Paint()
        ..color = const Color(0x33000000)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;
      final rnd = math.Random(r.left.toInt() ^ r.top.toInt() ^ r.width.toInt());
      final pts = <Offset>[];
      final density = (r.width * r.height / 380).clamp(10, 900).toInt();
      for (int i=0; i<density; i++) {
        final p = Offset(r.left + rnd.nextDouble()*r.width, r.top + rnd.nextDouble()*r.height);
        if (path.contains(p)) pts.add(p);
      }
      if (pts.isNotEmpty) c.drawPoints(ui.PointMode.points, pts, dots);
    } else if (mat == _WallMat.drywall) {
      final step = toStepMm(12);
      final sw = (toStepMm(1.4)).clamp(0.8, 2.2);
      final pGrid = Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = sw;

      for (double x = r.left; x <= r.right + 1; x += step * k) {
        c.drawLine(Offset(x, r.top), Offset(x, r.bottom), pGrid);
      }
      for (double y = r.top; y <= r.bottom + 1; y += step * k) {
        c.drawLine(Offset(r.left, y), Offset(r.right, y), pGrid);
      }
    }

    c.restore();
  }

  void _label(Canvas c, Offset at, String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(at.dx - 4, at.dy - 2, tp.width + 8, tp.height + 4),
      const Radius.circular(4),
    );
    c.drawRRect(bg, Paint()..color = const Color(0x66000000));
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(covariant _FloorPainter old) =>
      old.walls != walls ||
      old.openings != openings ||
      old.points != points ||
      old.k != k ||
      old.pan != pan ||
      old.pad != pad ||
      old.dragStart != dragStart ||
      old.dragCur != dragCur ||
      old.dragFingerPx != dragFingerPx ||
      old.gridMm != gridMm ||
      old.previewOpening != previewOpening ||
      old.previewPoint != previewPoint ||
      old.wallThickCurrent != wallThickCurrent ||
      old.selectedWallIdx != selectedWallIdx ||
      old.contourClosed != contourClosed;
}