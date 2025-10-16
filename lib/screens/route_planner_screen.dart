// lib/screens/route_planner_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});
  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

/* ========================== STATE ========================== */

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  // помещение (мм)
  int roomW = 5000;
  int roomH = 4000;

  // сетка (шаг мм)
  final List<int> snaps = const [10, 20, 50, 100];
  int snap = 100;

  // режимы
  _Tool tool = _Tool.add;
  _PointType pickedType = _PointType.socket;

  // точки
  final List<_Pt> pts = [];
  int? selectedIdx;

  // drag перемещение одной точки
  int? draggingIdx;

  // масштаб листа
  double scale = 1.0;

  // группы света (для «проходных» выключателей достаточно добавить 2–3 выключателя в одну группу)
  final Map<int, _LightGroup> groups = {}; // id -> group
  int _nextGroupId = 1;
  int? activeGroupId; // для режима «Связать»

  // контролы ввода координат “ввод”
  final TextEditingController ctrlX = TextEditingController();
  final TextEditingController ctrlY = TextEditingController();

  @override
  void dispose() {
    ctrlX.dispose();
    ctrlY.dispose();
    super.dispose();
  }

  /* ====================== HELPERS ====================== */

  Offset _snap(Offset mm) {
    final sx = (mm.dx / snap).roundToDouble() * snap;
    final sy = (mm.dy / snap).roundToDouble() * snap;
    return _clamp(Offset(sx, sy));
  }

  Offset _clamp(Offset mm) {
    final x = mm.dx.clamp(0, roomW).toDouble();
    final y = mm.dy.clamp(0, roomH).toDouble();
    return Offset(x, y);
  }

  bool _inside(Offset mm) =>
      mm.dx >= 0 && mm.dy >= 0 && mm.dx <= roomW && mm.dy <= roomH;

  void _addPoint(Offset mm) {
    final p = _Pt(type: pickedType, x: mm.dx.round(), y: mm.dy.round());
    setState(() => pts.add(p));
  }

  void _deletePoint(int idx) {
    // если точка состояла в группах — удалить ссылки
    for (final g in groups.values) {
      g.lightPts.remove(idx);
      g.switchPts.remove(idx);
    }
    setState(() {
      pts.removeAt(idx);
      if (selectedIdx == idx) selectedIdx = null;
    });
  }

  void _movePointTo(int idx, Offset mm) {
    final s = _snap(mm);
    setState(() {
      pts[idx] = pts[idx].copyWith(x: s.dx.round(), y: s.dy.round());
    });
  }

  bool _isLight(_PointType t) => t == _PointType.ceiling || t == _PointType.sconce;

  /* ======================= BUILD ======================= */

  @override
  Widget build(BuildContext context) {
    final wallColor = Colors.white.withOpacity(.85);

    return Scaffold(
      appBar: AppBar(title: const Text('Трассировка (черновик)')),
      body: LayoutBuilder(
        builder: (ctx, bc) {
          return Stack(
            children: [
              // Поле
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Color(0xFF111418)),
                      child: LayoutBuilder(
                        builder: (_, c) {
                          // вписываем помещение с отступом
                          const pad = 24.0;
                          final availW = c.maxWidth - pad * 2;
                          final availH = c.maxHeight - pad * 2;
                          final kx = availW / roomW;
                          final ky = availH / roomH;
                          final k = math.min(kx, ky) * scale;
                          final drawW = roomW * k;
                          final drawH = roomH * k;
                          final ox = (c.maxWidth - drawW) / 2;
                          final oy = (c.maxHeight - drawH) / 2;

                          // преобразования
                          Offset mm2px(Offset mm) => Offset(ox + mm.dx * k, oy + mm.dy * k);
                          Offset px2mm(Offset px) => Offset((px.dx - ox) / k, (px.dy - oy) / k);

                          return GestureDetector(
                            // pinch-zoom
                            onScaleUpdate: (d) {
                              if (d.pointerCount >= 2) {
                                setState(() => scale = (scale * d.scale).clamp(0.5, 2.5));
                                return;
                              }
                              if (tool == _Tool.move && draggingIdx != null) {
                                _movePointTo(draggingIdx!, px2mm(d.focalPoint));
                              }
                            },
                            onTapUp: (d) {
                              final mmRaw = px2mm(d.localPosition);
                              final mm = _snap(mmRaw);
                              if (tool == _Tool.add) {
                                if (_inside(mm)) _addPoint(mm);
                              } else if (tool == _Tool.delete) {
                                final hit = _hitTest(mm2px, d.localPosition);
                                if (hit != null) _deletePoint(hit);
                              } else if (tool == _Tool.move) {
                                final hit = _hitTest(mm2px, d.localPosition);
                                setState(() {
                                  draggingIdx = hit;
                                  selectedIdx = hit;
                                });
                              } else if (tool == _Tool.link) {
                                final hit = _hitTest(mm2px, d.localPosition);
                                if (hit != null) _linkHandleTap(hit);
                              }
                            },
                            onLongPressStart: (_) {
                              if (tool == _Tool.link) {
                                // создать новую группу и выбрать её
                                setState(() {
                                  final id = _nextGroupId++;
                                  groups[id] = _LightGroup(id);
                                  activeGroupId = id;
                                });
                              }
                            },
                            onScaleEnd: (_) => draggingIdx = null,
                            child: CustomPaint(
                              painter: _FieldPainter(
                                roomW: roomW,
                                roomH: roomH,
                                k: k,
                                origin: Offset(ox, oy),
                                wallColor: wallColor,
                                gridStepMm: snap,
                                points: pts,
                                selectedIdx: selectedIdx,
                                groups: groups,
                                toPx: mm2px,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Нижняя панель
              _BottomSheet(
                min: 0.16,
                mid: 0.40,
                max: 0.70,
                collapsedBar: _CollapsedBar(
                  tool: tool,
                  picked: pickedType,
                  onPickTool: (t) => setState(() => tool = t),
                  onPickType: (t) => setState(() => pickedType = t),
                ),
                expanded: _ExpandedPanel(
                  roomW: roomW,
                  roomH: roomH,
                  snaps: snaps,
                  snap: snap,
                  ctrlX: ctrlX,
                  ctrlY: ctrlY,
                  groups: groups,
                  activeGroupId: activeGroupId,
                  onSelectGroup: (id) => setState(() => activeGroupId = id),
                  onNewGroup: () {
                    setState(() {
                      final id = _nextGroupId++;
                      groups[id] = _LightGroup(id);
                      activeGroupId = id;
                    });
                  },
                  onDeleteGroup: (id) {
                    setState(() {
                      groups.remove(id);
                      if (activeGroupId == id) activeGroupId = null;
                    });
                  },
                  onChangeRoomW: (v) => setState(() => roomW = int.tryParse(v) ?? roomW),
                  onChangeRoomH: (v) => setState(() => roomH = int.tryParse(v) ?? roomH),
                  onSnap: (v) => setState(() => snap = v),
                  onApplyInput: () {
                    final x = int.tryParse(ctrlX.text);
                    final y = int.tryParse(ctrlY.text);
                    if (x == null || y == null) return;
                    final mm = _clamp(Offset(x.toDouble(), y.toDouble()));
                    if (tool == _Tool.add) {
                      _addPoint(_snap(mm));
                    } else if (tool == _Tool.move && selectedIdx != null) {
                      _movePointTo(selectedIdx!, mm);
                    }
                  },
                  onDeleteSelected: () {
                    if (selectedIdx != null) _deletePoint(selectedIdx!);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // логика связывания в группе
  void _linkHandleTap(int idx) {
    final p = pts[idx];
    // если нет активной группы — создать
    activeGroupId ??= (_nextGroupId++); // резервируем id
    groups.putIfAbsent(activeGroupId!, () => _LightGroup(activeGroupId!));

    final g = groups[activeGroupId!]!;
    if (_isLight(p.type)) {
      g.lightPts.add(idx);
    } else if (p.type == _PointType.switcher) {
      g.switchPts.add(idx);
    }
    setState(() {
      selectedIdx = idx;
    });
  }

  int? _hitTest(Offset Function(Offset mm) toPx, Offset tapPx) {
    const r = 18.0; // радиус хитбокса (px)
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      final c = toPx(Offset(p.x.toDouble(), p.y.toDouble()));
      if ((c - tapPx).distance <= r) {
        selectedIdx = i;
        return i;
      }
    }
    return null;
  }
}

/* =================== ВИДЖЕТ НИЖНЕГО ЛИСТА =================== */

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.min,
    required this.mid,
    required this.max,
    required this.collapsedBar,
    required this.expanded,
  });

  final double min;
  final double mid;
  final double max;
  final Widget collapsedBar;
  final Widget expanded;

  @override
  Widget build(BuildContext context) {
    final radius = const Radius.circular(18);

    return DraggableScrollableSheet(
      initialChildSize: min,
      minChildSize: min,
      maxChildSize: max,
      snap: true,
      snapSizes: [min, mid, max],
      builder: (ctx, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F26),
            borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
            border: Border.all(color: Colors.white10),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: [
                  // внутренний граббер
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  collapsedBar,
                  const SizedBox(height: 10),
                  expanded,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ==================== КОМПАКТНАЯ ПАНЕЛЬ ==================== */

class _CollapsedBar extends StatelessWidget {
  const _CollapsedBar({
    required this.tool,
    required this.picked,
    required this.onPickTool,
    required this.onPickType,
  });

  final _Tool tool;
  final _PointType picked;
  final ValueChanged<_Tool> onPickTool;
  final ValueChanged<_PointType> onPickType;

  @override
  Widget build(BuildContext context) {
    final chips = [
      _chipType(context, _PointType.socket, 'Роз.', Icons.power),
      _chipType(context, _PointType.ceiling, 'Свет', Icons.light_mode_outlined),
      _chipType(context, _PointType.sconce, 'Бра', Icons.wb_twighlight),
      _chipType(context, _PointType.box, 'Кор.', Icons.crop_square),
      _chipType(context, _PointType.switcher, 'Выкл.', Icons.toggle_on_outlined),
    ];

    final modes = [
      _chipTool(context, _Tool.add, 'Добавить', Icons.add),
      _chipTool(context, _Tool.move, 'Двигать', Icons.open_with),
      _chipTool(context, _Tool.delete, 'Удалить', Icons.delete_outline),
      _chipTool(context, _Tool.link, 'Связать', Icons.link),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 4),
          ...chips.expand((w) => [w, const SizedBox(width: 8)]),
          const SizedBox(width: 6),
          ...modes.expand((w) => [w, const SizedBox(width: 8)]),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _chipType(BuildContext context, _PointType t, String label, IconData ic) {
    final sel = picked == t;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(ic, size: 18),
      selected: sel,
      onSelected: (_) => onPickType(t),
    );
  }

  Widget _chipTool(BuildContext context, _Tool t, String label, IconData ic) {
    final sel = tool == t;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(ic, size: 18),
      selected: sel,
      onSelected: (_) => onPickTool(t),
    );
  }
}

/* ===================== РАСШИРЕННАЯ ПАНЕЛЬ ===================== */

class _ExpandedPanel extends StatelessWidget {
  const _ExpandedPanel({
    required this.roomW,
    required this.roomH,
    required this.snaps,
    required this.snap,
    required this.ctrlX,
    required this.ctrlY,
    required this.groups,
    required this.activeGroupId,
    required this.onSelectGroup,
    required this.onNewGroup,
    required this.onDeleteGroup,
    required this.onChangeRoomW,
    required this.onChangeRoomH,
    required this.onSnap,
    required this.onApplyInput,
    required this.onDeleteSelected,
  });

  final int roomW;
  final int roomH;
  final List<int> snaps;
  final int snap;

  final TextEditingController ctrlX;
  final TextEditingController ctrlY;

  final Map<int, _LightGroup> groups;
  final int? activeGroupId;
  final ValueChanged<int?> onSelectGroup;
  final VoidCallback onNewGroup;
  final ValueChanged<int> onDeleteGroup;

  final ValueChanged<String> onChangeRoomW;
  final ValueChanged<String> onChangeRoomH;
  final ValueChanged<int> onSnap;
  final VoidCallback onApplyInput;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final styleLbl = TextStyle(color: Colors.white70.withOpacity(.9));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          runSpacing: 10,
          spacing: 10,
          children: [
            _field('Ширина, мм', roomW.toString(), onChangeRoomW),
            _field('Высота, мм', roomH.toString(), onChangeRoomH),
            _snapPicker(snaps, snap, onSnap),
            _coordInput('Ввод X, мм', ctrlX),
            _coordInput('Ввод Y, мм', ctrlY),
            SizedBox(
              width: 120,
              child: FilledButton(onPressed: onApplyInput, child: const Text('Применить')),
            ),
            SizedBox(
              width: 120,
              child: OutlinedButton.icon(
                onPressed: onDeleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Del'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: onNewGroup,
              icon: const Icon(Icons.add_link),
              label: const Text('Новая группа'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: activeGroupId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Активная группа'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('— нет —')),
                  ...groups.values.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text('Группа ${g.id}  • свет:${g.lightPts.length}  • выкл:${g.switchPts.length}'),
                      )),
                ],
                onChanged: onSelectGroup,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // список групп с удалением
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: groups.values.map((g) {
            return Row(
              children: [
                Text('Группа ${g.id}: свет=${g.lightPts.length}, выкл=${g.switchPts.length}'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDeleteGroup(g.id),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text('Координаты — от левой и верхней стен, в миллиметрах.', style: styleLbl),
      ],
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged) {
    return SizedBox(
      width: 190,
      child: TextField(
        controller: TextEditingController(text: value),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Widget _coordInput(String label, TextEditingController c) {
    return SizedBox(
      width: 190,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _snapPicker(List<int> snaps, int snap, ValueChanged<int> onPick) {
    return SizedBox(
      height: 56,
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: snaps
            .map((s) => ChoiceChip(
                  label: Text('$s мм'),
                  selected: snap == s,
                  onSelected: (_) => onPick(s),
                ))
            .toList(),
      ),
    );
  }
}

/* ======================== ПОЛЕ/РИСОВАЛКА ======================== */

class _FieldPainter extends CustomPainter {
  _FieldPainter({
    required this.roomW,
    required this.roomH,
    required this.k,
    required this.origin,
    required this.wallColor,
    required this.gridStepMm,
    required this.points,
    required this.selectedIdx,
    required this.groups,
    required this.toPx,
  });

  final int roomW, roomH;
  final double k;
  final Offset origin;
  final Color wallColor;
  final int gridStepMm;
  final List<_Pt> points;
  final int? selectedIdx;
  final Map<int, _LightGroup> groups;
  final Offset Function(Offset mm) toPx;

  @override
  void paint(Canvas c, Size s) {
    final rect = Rect.fromLTWH(origin.dx, origin.dy, roomW * k, roomH * k);

    // фон
    c.drawRect(rect, Paint()..color = const Color(0xFF0C0F12));

    // сетка
    final grid1 = Paint()..color = Colors.white10..strokeWidth = 1;
    final grid2 = Paint()..color = Colors.white24..strokeWidth = 1.2;
    final stepPx = gridStepMm * k;
    for (double x = rect.left; x <= rect.right + .5; x += stepPx) {
      c.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid1);
    }
    for (double y = rect.top; y <= rect.bottom + .5; y += stepPx) {
      c.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid1);
    }
    for (double x = rect.left; x <= rect.right + .5; x += stepPx * 5) {
      c.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid2);
    }
    for (double y = rect.top; y <= rect.bottom + .5; y += stepPx * 5) {
      c.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid2);
    }

    // стены
    c.drawRect(rect.deflate(1), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = wallColor);

    // связи групп (пунктиры)
    for (final g in groups.values) {
      for (final swIdx in g.switchPts) {
        if (swIdx < 0 || swIdx >= points.length) continue;
        final sw = points[swIdx];
        final swC = toPx(Offset(sw.x.toDouble(), sw.y.toDouble()));
        for (final lIdx in g.lightPts) {
          if (lIdx < 0 || lIdx >= points.length) continue;
          final lp = points[lIdx];
          final lpC = toPx(Offset(lp.x.toDouble(), lp.y.toDouble()));
          _dashedLine(c, swC, lpC, color: Colors.white70);
        }
      }
    }

    // точки
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final center = toPx(Offset(p.x.toDouble(), p.y.toDouble()));
      final isSel = i == selectedIdx;

      if (isSel) {
        c.drawCircle(center, 13, Paint()..color = p.color.withOpacity(.25));
        c.drawCircle(center, 11, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = p.color.withOpacity(.9));
      }

      // маркер
      final fill = Paint()..color = p.color.withOpacity(isSel ? .95 : .80);
      final stroke = Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      c.drawCircle(center, 8, fill);
      c.drawCircle(center, 8, stroke);

      // подпись типа
      final tType = TextPainter(
        text: TextSpan(text: p.short, style: const TextStyle(color: Colors.white, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tType.paint(c, center + const Offset(10, -18));
    }

    // направляющие/векторы для выбранной точки
    if (selectedIdx != null && selectedIdx! >= 0 && selectedIdx! < points.length) {
      final p = points[selectedIdx!];
      final center = toPx(Offset(p.x.toDouble(), p.y.toDouble()));

      final guide = Paint()..color = Colors.white70..strokeWidth = 1.2;
      // до левой стены
      c.drawLine(Offset(rect.left, center.dy), Offset(center.dx, center.dy), guide);
      // до верхней стены
      c.drawLine(Offset(center.dx, rect.top), Offset(center.dx, center.dy), guide);

      _label(c,
          text: '${p.x} мм',
          at: Offset((rect.left + center.dx) / 2, center.dy - 12),
          centerOn: true);
      _label(c,
          text: '${p.y} мм',
          at: Offset(center.dx + 10, (rect.top + center.dy) / 2),
          centerOn: false);
    }
  }

  void _label(Canvas c, {required String text, required Offset at, required bool centerOn}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = centerOn ? at - Offset(tp.width / 2, tp.height / 2) : at - const Offset(0, 7);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx - 4, offset.dy - 2, tp.width + 8, tp.height + 4),
      const Radius.circular(4),
    );
    c.drawRRect(bgRect, Paint()..color = const Color(0x66000000));
    tp.paint(c, offset);
  }

  void _dashedLine(Canvas c, Offset a, Offset b, {Color color = Colors.white70, double dash = 6, double gap = 4}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final total = (b - a).distance;
    final dir = (b - a) / total;
    double t = 0;
    while (t < total) {
      final p1 = a + dir * t;
      final p2 = a + dir * math.min(t + dash, total);
      c.drawLine(p1, p2, paint);
      t += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) =>
      old.roomW != roomW ||
      old.roomH != roomH ||
      old.k != k ||
      old.origin != origin ||
      old.gridStepMm != gridStepMm ||
      old.points != points ||
      old.selectedIdx != selectedIdx ||
      old.groups != groups;
}

/* ============================= МОДЕЛИ ============================= */

enum _Tool { add, move, delete, link }

enum _PointType { socket, ceiling, sconce, box, switcher }

class _Pt {
  final _PointType type;
  final int x;
  final int y;

  const _Pt({required this.type, required this.x, required this.y});

  _Pt copyWith({_PointType? type, int? x, int? y}) =>
      _Pt(type: type ?? this.type, x: x ?? this.x, y: y ?? this.y);

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

// группа света: светильники + выключатели
class _LightGroup {
  final int id;
  final Set<int> lightPts = {};
  final Set<int> switchPts = {};
  _LightGroup(this.id);
}