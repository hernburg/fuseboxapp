import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/wall_model.dart';

class WallDebugOverlay {
  final ui.Offset? snapPoint;
  final ui.Offset? offsetPoint;
  final ui.Offset? baseNormalOrigin;
  final ui.Offset? baseNormalVector;
  final ui.Offset? newNormalOrigin;
  final ui.Offset? newNormalVector;

  const WallDebugOverlay({
    this.snapPoint,
    this.offsetPoint,
    this.baseNormalOrigin,
    this.baseNormalVector,
    this.newNormalOrigin,
    this.newNormalVector,
  });

  static const empty = WallDebugOverlay();
}

class WallPainter extends CustomPainter {
  final List<WallSeg> walls;
  final double k;        // масштаб
  final ui.Offset panPx;
  final EdgeInsets pad;
  final bool debugMode;
  final WallDebugOverlay debugOverlay;
  final ui.Offset? highlightCorner;

  WallPainter({
    required this.walls,
    required this.k,
    required this.panPx,
    required this.pad,
    this.debugMode = false,
    WallDebugOverlay? debugOverlay,
    this.highlightCorner,
  }) : debugOverlay = debugOverlay ?? WallDebugOverlay.empty;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // трансформация
    canvas.translate(panPx.dx + pad.left, panPx.dy + pad.top);
    canvas.scale(k);

    _drawBackground(canvas, size);
    _drawWalls(canvas);
    if (debugMode) {
      _drawDebugOverlay(canvas);
    }

    canvas.restore();

    if (highlightCorner != null) {
      final px = _toPx(highlightCorner!, panPx, k, pad);
      final fill = Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(px, 10, fill);

      canvas.drawCircle(
        px,
        10,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  // -------------------------------------------------------------
  //  СЕТКА / ФОН
  // -------------------------------------------------------------
  void _drawBackground(Canvas c, Size s) {
    final bg = Paint()
      ..color = const Color(0xFF2F3542); // мягкий тёмный фон

    c.drawRect(
      Rect.fromLTWH(-50000, -50000, 100000, 100000),
      bg,
    );

    final gridPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;

    const step = 500.0;
    for (double x = -50000; x <= 50000; x += step) {
      c.drawLine(Offset(x, -50000), Offset(x, 50000), gridPaint);
    }
    for (double y = -50000; y <= 50000; y += step) {
      c.drawLine(Offset(-50000, y), Offset(50000, y), gridPaint);
    }
  }

  // -------------------------------------------------------------
  //  ТОЛСТЫЕ СТЕНЫ
  // -------------------------------------------------------------
  void _drawWalls(Canvas c) {
    for (var i = 0; i < walls.length; i++) {
      _drawWall(c, walls[i], i);
    }
  }

  void _drawWall(Canvas canvas, WallSeg wall, int index) {
    final quad = wall.quad;

    final pA = worldToScreen(quad[0]);
    final pB = worldToScreen(quad[1]);
    final pC = worldToScreen(quad[2]);
    final pD = worldToScreen(quad[3]);

    // --- рисуем саму стену ---
    final path = Path()
      ..moveTo(pA.dx, pA.dy)
      ..lineTo(pB.dx, pB.dy)
      ..lineTo(pC.dx, pC.dy)
      ..lineTo(pD.dx, pD.dy)
      ..close();

    canvas.drawPath(path, wallFillPaintFor(wall));
    canvas.drawPath(path, wallStrokePaint);

    // --- подписи углов ---
    _drawLabel(canvas, "a", pA + const Offset(-8, 12));
    _drawLabel(canvas, "b", pB + const Offset(-8, -12));
    _drawLabel(canvas, "c", pC + const Offset(8, -12));
    _drawLabel(canvas, "d", pD + const Offset(8, 12));

    // --- подписи сторон с индексом стены ---
    final idx = "_$index";

    _drawLabel(canvas, "X1$idx", _mid(pA, pB) + const Offset(-6, 0));
    _drawLabel(canvas, "Y1$idx", _mid(pB, pC) + const Offset(0, -6));
    _drawLabel(canvas, "X2$idx", _mid(pD, pC) + const Offset(6, 0));
    _drawLabel(canvas, "Y2$idx", _mid(pA, pD) + const Offset(0, 6));
  }

  Offset worldToScreen(Offset p) => p;

  ui.Offset _toPx(
    ui.Offset world,
    ui.Offset pan,
    double scale,
    EdgeInsets padding,
  ) {
    return ui.Offset(
      world.dx * scale + pan.dx + padding.left,
      world.dy * scale + pan.dy + padding.top,
    );
  }

  Paint wallFillPaintFor(WallSeg wall) => Paint()
    ..color = const Color(0xFFDEE2E6).withOpacity(0.45)
    ..style = PaintingStyle.fill;

  Paint get wallStrokePaint => Paint()
    ..color = const Color(0xFFADB5BD)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  Offset _mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  void _drawLabel(Canvas canvas, String text, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 25,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, pos);
  }

  void _drawDebugOverlay(Canvas c) {
    const normalLen = 600.0;
    final stroke = 4 / k;

    final basePaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = stroke;

    final newPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = stroke;

    if (debugOverlay.baseNormalOrigin != null &&
        debugOverlay.baseNormalVector != null) {
      final a = debugOverlay.baseNormalOrigin!;
      final vec = debugOverlay.baseNormalVector!;
      final len = vec.distance;
      final dir = len < 1e-6 ? const ui.Offset(1, 0) : vec / len;
      final b = a + dir * normalLen;
      c.drawLine(a, b, basePaint);
    }

    if (debugOverlay.newNormalOrigin != null &&
        debugOverlay.newNormalVector != null) {
      final a = debugOverlay.newNormalOrigin!;
      final vec = debugOverlay.newNormalVector!;
      final len = vec.distance;
      final dir = len < 1e-6 ? const ui.Offset(1, 0) : vec / len;
      final b = a + dir * normalLen;
      c.drawLine(a, b, newPaint);
    }

    if (debugOverlay.offsetPoint != null) {
      c.drawCircle(
        debugOverlay.offsetPoint!,
        80,
        Paint()
          ..color = Colors.greenAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
    }

    if (debugOverlay.snapPoint != null) {
      final p = debugOverlay.snapPoint!;
      final crossPaint = Paint()
        ..color = Colors.pinkAccent
        ..strokeWidth = stroke;
      c.drawLine(p + const ui.Offset(-80, -80), p + const ui.Offset(80, 80), crossPaint);
      c.drawLine(p + const ui.Offset(-80, 80), p + const ui.Offset(80, -80), crossPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WallPainter old) {
    return old.walls != walls ||
        old.k != k ||
        old.panPx != panPx ||
        old.debugMode != debugMode ||
        old.debugOverlay != debugOverlay ||
        old.highlightCorner != highlightCorner;
  }
}
