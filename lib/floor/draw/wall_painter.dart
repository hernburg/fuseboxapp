import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/wall_model.dart';

class WallPainter extends CustomPainter {
  final double k;                 // px per mm
  final ui.Offset panPx;          // панорамирование (в пикселях)
  final EdgeInsets pad;           // внутренние отступы холста
  final List<WallSeg> walls;

  final double gridMm;            // шаг сетки в мм
  final bool gridOn;              // показывать сетку

  final ui.Offset? dragA;         // предпросмотр — начало
  final ui.Offset? dragB;         // предпросмотр — конец
  final double? previewThickMm;   // толщина в предпросмотре (необязательна для подписи)

  WallPainter({
    required this.k,
    required this.panPx,
    required this.pad,
    required this.walls,
    required this.gridMm,
    required this.gridOn,
    this.dragA,
    this.dragB,
    this.previewThickMm,
  });

  ui.Offset _mm2px(ui.Offset mm) =>
      ui.Offset(mm.dx * k + panPx.dx + pad.left, mm.dy * k + panPx.dy + pad.top);

  @override
  void paint(Canvas c, Size s) {
    // ---------- Сетка ----------
    if (gridOn) {
      final double step = (gridMm * k).clamp(1.0, double.infinity);
      final gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..strokeWidth = 1;

      for (double x = pad.left + panPx.dx % step; x < s.width; x += step) {
        c.drawLine(ui.Offset(x, pad.top), ui.Offset(x, s.height - pad.bottom), gridPaint);
      }
      for (double y = pad.top + panPx.dy % step; y < s.height; y += step) {
        c.drawLine(ui.Offset(pad.left, y), ui.Offset(s.width - pad.right, y), gridPaint);
      }
    }

    // ---------- Стены ----------
    final wallPaint = Paint()
      ..color = const Color(0xFFF06264)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    for (final w in walls) {
      wallPaint.strokeWidth = w.thickMm * k;
      c.drawLine(_mm2px(w.a), _mm2px(w.b), wallPaint);
    }

    // ---------- Линия предпросмотра ----------
if (dragA != null && dragB != null && previewThickMm != null) {
  final previewPaint = Paint()
    ..color = const Color(0xFF66E3A1) // зелёный цвет предпросмотра
    ..style = PaintingStyle.stroke
    ..strokeWidth = previewThickMm! * k
    ..strokeCap = StrokeCap.butt;

  c.drawLine(_mm2px(dragA!), _mm2px(dragB!), previewPaint);
}

    // ---------- Подпись длины в предпросмотре ----------
    if (dragA != null && dragB != null) {
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left),
      )
        ..pushStyle(ui.TextStyle(
          color: Colors.teal,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ))
        ..addText('${(dragA! - dragB!).distance.toStringAsFixed(0)} мм');

      final para = pb.build()..layout(const ui.ParagraphConstraints(width: 200));
      final pos = _mm2px((dragA! + dragB!) / 2);
      c.drawParagraph(para, pos + const ui.Offset(6, -22));
    }
  }

  @override
  bool shouldRepaint(covariant WallPainter old) =>
      old.k != k ||
      old.panPx != panPx ||
      old.pad != pad ||
      old.gridMm != gridMm ||
      old.gridOn != gridOn ||
      old.walls != walls ||
      old.dragA != dragA ||
      old.dragB != dragB ||
      old.previewThickMm != previewThickMm;
}