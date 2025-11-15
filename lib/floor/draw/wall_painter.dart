import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/wall_model.dart';
import '../rooms/room_detector.dart';

class WallPainter extends CustomPainter {
  final List<WallSeg> walls;
  final List<RoomRect> rooms;

  final double k;
  final Offset panPx;
  final EdgeInsets pad;

  final double gridMm;
  final bool gridOn;

  final Offset? dragA;
  final Offset? dragB;
  final double previewThickMm;

  final bool showDims;
  final Rect? marqueeWorld;
  final Set<int> selected;
  final int? hoverIndex;

  WallPainter({
    required this.walls,
    required this.rooms,
    required this.k,
    required this.panPx,
    required this.pad,
    required this.gridMm,
    required this.gridOn,
    required this.dragA,
    required this.dragB,
    required this.previewThickMm,
    required this.showDims,
    required this.marqueeWorld,
    required this.selected,
    required this.hoverIndex,
  });

  // ---------- UTILS ----------
  Offset _mm2px(Offset mm) =>
      Offset(mm.dx * k + panPx.dx + pad.left, mm.dy * k + panPx.dy + pad.top);

  Offset _px2mm(Offset px) =>
      Offset((px.dx - panPx.dx - pad.left) / k, (px.dy - panPx.dy - pad.top) / k);

  // ---------------------------------------------------------------
  //                      GRID
  // ---------------------------------------------------------------
  void _drawAdaptiveGrid(Canvas c, Size s) {
    if (!gridOn || k <= 0) return;

    final baseStepPx = gridMm * k;
    if (baseStepPx < 4) return;

    double stepMm = gridMm;
    if (baseStepPx < 20) stepMm = gridMm * 5;
    if (baseStepPx < 10) stepMm = gridMm * 10;
    if (baseStepPx > 120) stepMm = gridMm / 2;
    if (baseStepPx > 240) stepMm = gridMm / 5;

    final topLeftMm = _px2mm(Offset(0, 0));
    final bottomRightMm = _px2mm(Offset(s.width, s.height));

    double startX = (topLeftMm.dx / stepMm).floorToDouble() * stepMm;
    double startY = (topLeftMm.dy / stepMm).floorToDouble() * stepMm;

    final minor = Paint()
      ..color = Colors.grey.withOpacity(0.22)
      ..strokeWidth = 1;

    final major = Paint()
      ..color = Colors.grey.withOpacity(0.45)
      ..strokeWidth = 1.3;

    for (double xMm = startX; xMm <= bottomRightMm.dx; xMm += stepMm) {
      final xPx = _mm2px(Offset(xMm, 0)).dx;
      final isMajor = ((xMm / stepMm).round() % 5 == 0);
      c.drawLine(Offset(xPx, 0), Offset(xPx, s.height), isMajor ? major : minor);
    }

    for (double yMm = startY; yMm <= bottomRightMm.dy; yMm += stepMm) {
      final yPx = _mm2px(Offset(0, yMm)).dy;
      final isMajor = ((yMm / stepMm).round() % 5 == 0);
      c.drawLine(
          Offset(0, yPx), Offset(s.width, yPx), isMajor ? major : minor);
    }
  }

  // ---------------------------------------------------------------
  //                         ROOMS FILL
  // ---------------------------------------------------------------
  void _drawRoomsFill(Canvas c) {
    if (rooms.isEmpty) return;

    final paintFill = Paint()
      ..color = Colors.greenAccent.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = Colors.greenAccent.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final r in rooms) {
      final rectPx = Rect.fromPoints(
        _mm2px(r.rectMm.topLeft),
        _mm2px(r.rectMm.bottomRight),
      );

      c.drawRect(rectPx, paintFill);
      c.drawRect(rectPx, border);
    }
  }

  // ---------------------------------------------------------------
  //                         DIMENSIONS
  // ---------------------------------------------------------------
  void _drawSegmentedDims(Canvas c, WallSeg w) {
    final ab = w.b - w.a;
    final abLen = ab.distance;
    if (abLen < 1e-6) return;

    final n = Offset(-ab.dy / abLen, ab.dx / abLen);
    final mid = Offset((w.a.dx + w.b.dx) / 2, (w.a.dy + w.b.dy) / 2);

    final segLen = abLen;
    final textPx = _mm2px(mid) + n * 20;

    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ))
      ..addText('${segLen.toStringAsFixed(0)} мм');

    final para = pb.build()
      ..layout(const ui.ParagraphConstraints(width: 200));

    c.drawParagraph(para, textPx + const Offset(-100, -8));
  }

  // ---------------------------------------------------------------
  //                         WALLS
  // ---------------------------------------------------------------
  @override
  void paint(Canvas c, Size s) {
    _drawAdaptiveGrid(c, s);
    _drawRoomsFill(c); // ← заливка комнат ПОД стенами

    for (int i = 0; i < walls.length; i++) {
      final w = walls[i];

      final aPx = _mm2px(w.a);
      final bPx = _mm2px(w.b);
      final dir = bPx - aPx;
      final len = dir.distance;
      if (len == 0) continue;

      final n = Offset(-dir.dy / len, dir.dx / len);
      final halfPx = w.thickMm * k / 2;

      final p1 = aPx + n * halfPx;
      final p2 = bPx + n * halfPx;
      final p3 = bPx - n * halfPx;
      final p4 = aPx - n * halfPx;

      final fill = Paint()
        ..color = selected.contains(i)
            ? Colors.blueAccent.withOpacity(0.9)
            : hoverIndex == i
                ? Colors.blueAccent.withOpacity(0.8)
                : Colors.blueAccent.withOpacity(0.55);

      final path = Path()..addPolygon([p1, p2, p3, p4], true);
      c.drawPath(path, fill);

      if (showDims) _drawSegmentedDims(c, w);
    }

    if (dragA != null && dragB != null) {
      final p = Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      c.drawLine(_mm2px(dragA!), _mm2px(dragB!), p);

      final ab = dragB! - dragA!;
      final len = ab.distance;
      if (len > 0) {
        final n = Offset(-ab.dy / len, ab.dx / len);
        final mid = Offset(
          (dragA!.dx + dragB!.dx) / 2,
          (dragA!.dy + dragB!.dy) / 2,
        );

        final pos = _mm2px(mid) + n * 20;

        final pb = ui.ParagraphBuilder(
          ui.ParagraphStyle(textAlign: TextAlign.center),
        )
          ..pushStyle(ui.TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600))
          ..addText('${len.toStringAsFixed(0)} мм');

        final para = pb.build()
          ..layout(const ui.ParagraphConstraints(width: 200));

        c.drawParagraph(para, pos + const Offset(-100, -8));
      }
    }

    if (marqueeWorld != null) {
      final r = marqueeWorld!;
      final rectPx = Rect.fromPoints(_mm2px(r.topLeft), _mm2px(r.bottomRight));

      final fill = Paint()..color = Colors.blue.withOpacity(0.15);
      final stroke = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      c.drawRect(rectPx, fill);
      c.drawRect(rectPx, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant WallPainter old) =>
      old.walls != walls ||
      old.rooms != rooms ||
      old.k != k ||
      old.panPx != panPx ||
      old.gridOn != gridOn ||
      old.dragA != dragA ||
      old.dragB != dragB ||
      old.showDims != showDims ||
      old.marqueeWorld != marqueeWorld ||
      old.selected != selected;
}
