// lib/widgets/floor_preview.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Компактное превью плана этажа.
/// plan ожидает структуру из вашего редактора:
/// {
///   "walls":[{"x":double,"y":double}, ...],
///   "openings":[{"type":"door"|"window","x":double,"y":double}, ...],
///   "points":[{"type":"socket"|...,"x":double,"y":double}, ...]
/// }
class FloorPreview extends StatelessWidget {
  final Map? plan;
  final double width;
  final double height;
  final EdgeInsets pad;

  const FloorPreview({
    super.key,
    required this.plan,
    required this.width,
    required this.height,
    this.pad = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _PreviewPainter(plan, pad),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final Map? plan;
  final EdgeInsets pad;
  _PreviewPainter(this.plan, this.pad);

  @override
  void paint(Canvas c, Size s) {
    // фон
    c.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(10)),
      Paint()..color = const Color(0xFF0E1114),
    );

    final data = plan ?? const {};
    final List wallsRaw = (data['walls'] as List?) ?? const [];
    final walls = wallsRaw
        .map<Offset>((e) => Offset(
              ((e['x'] as num?) ?? 0).toDouble(),
              ((e['y'] as num?) ?? 0).toDouble(),
            ))
        .toList();

    final List openingsRaw = (data['openings'] as List?) ?? const [];
    final openings = openingsRaw
        .map<_PrevOpening>((e) => _PrevOpening(
              ((e['type'] as String?) ?? 'door'),
              Offset(((e['x'] as num?) ?? 0).toDouble(),
                     ((e['y'] as num?) ?? 0).toDouble()),
            ))
        .toList();

    final List pointsRaw = (data['points'] as List?) ?? const [];
    final points = pointsRaw
        .map<_PrevPoint>((e) => _PrevPoint(
              ((e['type'] as String?) ?? 'socket'),
              Offset(((e['x'] as num?) ?? 0).toDouble(),
                     ((e['y'] as num?) ?? 0).toDouble()),
            ))
        .toList();

    if (walls.isEmpty && openings.isEmpty && points.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Нет плана',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset((s.width - tp.width) / 2, (s.height - tp.height) / 2));
      return;
    }

    // --- Рассчитываем границы содержимого (в мм)
    Rect bounds = _computeBounds(walls, openings, points);

    // Подгоняем под доступное место:
    final avail = Size(s.width - pad.horizontal, s.height - pad.vertical);
    final kx = avail.width / bounds.width;
    final ky = avail.height / bounds.height;
    final k = 0.9 * math.min(kx, ky); // небольшой внутренний отступ

    // Центрируем:
    final boundsCenter = Offset(
      (bounds.left + bounds.right) / 2,
      (bounds.top + bounds.bottom) / 2,
    );
    final canvasCenter = Offset(pad.left + avail.width / 2, pad.top + avail.height / 2);
    final origin = canvasCenter - boundsCenter * k;

    Offset mm2px(Offset mm) => origin + mm * k;

    // Сетка (лёгкая)
    _drawGrid(c, s, origin, k);

    // Стены (линии-превью)
    if (walls.isNotEmpty) {
      final p = Path();
      p.moveTo(mm2px(walls.first).dx, mm2px(walls.first).dy);
      for (int i = 1; i < walls.length; i++) {
        final pt = mm2px(walls[i]);
        p.lineTo(pt.dx, pt.dy);
      }
      c.drawPath(
        p,
        Paint()
          ..color = Colors.white.withValues(alpha: .9)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    // Проёмы — точечные значки
    for (final o in openings) {
      final p = mm2px(o.at);
      final color = (o.type == 'door') ? const Color(0xFF8EE7A8) : const Color(0xFF6EC1FF);
      c.drawCircle(p, 3, Paint()..color = color);
    }

    // Точки — мелкие
    for (final pt in points) {
      final p = mm2px(pt.at);
      c.drawCircle(p, 2.5, Paint()..color = Colors.amberAccent);
    }
  }

  Rect _computeBounds(
    List<Offset> walls,
    List<_PrevOpening> openings,
    List<_PrevPoint> points,
  ) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    void acc(Offset o) {
      minX = math.min(minX, o.dx);
      minY = math.min(minY, o.dy);
      maxX = math.max(maxX, o.dx);
      maxY = math.max(maxY, o.dy);
    }

    for (final w in walls) {
      acc(w);
    }
    for (final o in openings) {
      acc(o.at);
    }
    for (final p in points) {
      acc(p.at);
    }

    if (!minX.isFinite || minX == maxX || minY == maxY) {
      // защитимся от вырожденных случаев
      minX = 0; minY = 0; maxX = 100; maxY = 100;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _drawGrid(Canvas c, Size s, Offset origin, double k) {
    // шаг «визуальных» 1000 мм (1 м) в пикселях
    final stepPx = 1000 * k;
    if (stepPx < 10) return; // слишком мелко — не рисуем

    final rect = Offset.zero & s;
    final gridPaint = Paint()..color = const Color(0x14FFFFFF)..strokeWidth = 1;

    final startX = rect.left - (rect.left - origin.dx) % stepPx;
    for (double x = startX; x <= rect.right; x += stepPx) {
      c.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
    }
    final startY = rect.top - (rect.top - origin.dy) % stepPx;
    for (double y = startY; y <= rect.bottom; y += stepPx) {
      c.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) =>
      old.plan != plan || old.pad != pad;
}

class _PrevOpening {
  final String type; // 'door'|'window'
  final Offset at;
  _PrevOpening(this.type, this.at);
}

class _PrevPoint {
  final String type;
  final Offset at;
  _PrevPoint(this.type, this.at);
}
