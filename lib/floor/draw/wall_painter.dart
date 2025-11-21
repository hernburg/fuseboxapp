// lib/floor/draw/wall_painter.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../core/wall_model.dart';
import '../rooms/room_detector.dart';

class WallPainter extends CustomPainter {
  final List<WallSeg> walls;
  final List<Room> rooms;

  final double k;                
  final ui.Offset panPx;         
  final EdgeInsets pad;

  final double gridMm;
  final bool gridOn;

  final ui.Offset? dragA;
  final ui.Offset? dragB;
  final double previewThickMm;

  final bool showDims;

  final ui.Rect? marqueeWorld;
  final Set<int> selected;

  final int? hoverIndex;
  final ui.Offset? hoverVertex;

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
    required this.hoverVertex,
  });

  // -------------------------------------------------------------
  //                     COORDINATES
  // -------------------------------------------------------------

  ui.Offset _mm2px(ui.Offset mm) => ui.Offset(
        mm.dx * k + panPx.dx + pad.left,
        mm.dy * k + panPx.dy + pad.top,
      );

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintRooms(canvas);
    _paintWalls(canvas);
    _paintDragPreview(canvas);
    _paintMarquee(canvas);
    _paintVertexHover(canvas);
  }

  // -------------------------------------------------------------
  //                     GRID / BACKGROUND
  // -------------------------------------------------------------

  void _paintBackground(Canvas canvas, Size size) {
    if (!gridOn) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    final stepPx = gridMm * k;
    if (stepPx < 4) return;

    for (double x = (panPx.dx + pad.left) % stepPx;
        x < size.width;
        x += stepPx) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = (panPx.dy + pad.top) % stepPx;
        y < size.height;
        y += stepPx) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  // -------------------------------------------------------------
  //                      ROOMS
  // -------------------------------------------------------------

  void _paintRooms(Canvas canvas) {
    if (rooms.isEmpty) return;

    final fill = Paint()
      ..color = const Color(0xFF3C7E7B).withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final textStyle = const TextStyle(
      fontSize: 14,
      color: Colors.white,
    );

    for (final room in rooms) {
      if (room.outer.length < 3) continue;

      final path = Path()..fillType = PathFillType.evenOdd;

      // outer contour
      final p0 = _mm2px(room.outer.first);
      path.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < room.outer.length; i++) {
        final p = _mm2px(room.outer[i]);
        path.lineTo(p.dx, p.dy);
      }
      path.close();

      // holes
      for (final hole in room.holes) {
        if (hole.length < 3) continue;
        final h0 = _mm2px(hole.first);
        path.moveTo(h0.dx, h0.dy);
        for (int i = 1; i < hole.length; i++) {
          final p = _mm2px(hole[i]);
          path.lineTo(p.dx, p.dy);
        }
        path.close();
      }

      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);

      // area label
      final centerPx = _mm2px(room.centerMm);
      final tp = TextPainter(
        text: TextSpan(
          text: '${room.areaM2.toStringAsFixed(2)} м²',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        centerPx - ui.Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  // -------------------------------------------------------------
  //                      WALLS
  // -------------------------------------------------------------

  void _paintWalls(Canvas canvas) {
    final paintFill = Paint()
      ..color = const Color(0xFF44474F)
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = Colors.black.withOpacity(0.9)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final selFill = Paint()
      ..color = const Color(0xFF5C8DF6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < walls.length; i++) {
      final w = walls[i];
      final verts = wallEdges(w).map(_mm2px).toList();

      final path = Path()..addPolygon(verts, true);

      canvas.drawPath(path, selected.contains(i) ? selFill : paintFill);
      canvas.drawPath(path, paintStroke);

      // размеры пока отключены
    }
  }

   // -------------------------------------------------------------
  //             DRAG WALL PREVIEW
  // -------------------------------------------------------------

  void _paintDragPreview(Canvas canvas) {
    if (dragA == null || dragB == null) return;

    final tmp = WallSeg(a: dragA, b: dragB, thickMm: previewThickMm);
    final verts = wallEdges(tmp).map(_mm2px).toList();

    final fill = Paint()
      ..color = Colors.blueAccent.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path()..addPolygon(verts, true);

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // preview length
    final tp = TextPainter(
      text: TextSpan(
        text: '${tmp.lengthMm.round()} мм',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final centerPx = _mm2px(tmp.centerMm);
    final rect = Rect.fromCenter(
      center: centerPx,
      width: tp.width + 8,
      height: tp.height + 4,
    );

    canvas.drawRect(rect, Paint()..color = Colors.black.withOpacity(0.4));
    tp.paint(canvas, rect.topLeft + const Offset(4, 2));
  }

  // -------------------------------------------------------------
  //                      MARQUEE
  // -------------------------------------------------------------

  void _paintMarquee(Canvas canvas) {
    if (marqueeWorld == null) return;

    final p1 = _mm2px(marqueeWorld!.topLeft);
    final p2 = _mm2px(marqueeWorld!.bottomRight);

    final r = Rect.fromPoints(p1, p2);

    canvas.drawRect(
      r,
      Paint()
        ..color = Colors.blue.withOpacity(0.1)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRect(
      r,
      Paint()
        ..color = Colors.blue.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // -------------------------------------------------------------
  //                   HOVER VERTEX
  // -------------------------------------------------------------

  void _paintVertexHover(Canvas canvas) {
    if (hoverVertex == null) return;

    final p = _mm2px(hoverVertex!);

    canvas.drawCircle(
      p,
      8,
      Paint()
        ..color = Colors.blueAccent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    canvas.drawCircle(
      p,
      4,
      Paint()
        ..color = Colors.blueAccent.withOpacity(0.85)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(WallPainter old) =>
      walls != old.walls ||
      rooms != old.rooms ||
      dragA != old.dragA ||
      dragB != old.dragB ||
      hoverVertex != old.hoverVertex ||
      selected != old.selected ||
      marqueeWorld != old.marqueeWorld ||
      gridOn != old.gridOn;
}
