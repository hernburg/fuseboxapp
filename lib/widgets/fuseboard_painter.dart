import 'package:flutter/material.dart';

class FuseboardPainter extends CustomPainter {
  final int mainIn;
  final int? mainRcd;
  final int phases; // пока 1
  final List<Map<String, dynamic>> lines;

  static const double railGap = 90;
  static const double margin = 20;
  static const double modW = 18;
  static const double modH = 36;
  static const int perRail = 20;

  FuseboardPainter({
    required this.mainIn,
    required this.mainRcd,
    required this.lines,
    required this.phases,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    canvas.drawRRect(panel, Paint()..color = const Color(0xFF2C3446));

    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(margin, margin, size.width - margin * 2, size.height - margin * 2),
      const Radius.circular(10),
    );
    canvas.drawRRect(inner, Paint()..color = const Color(0xFF374155));

    // шины L/N
    final busX = margin + 24;
    final busTop = margin + 14;
    final busLen = size.height - margin * 2 - 28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(busX, busTop, 6, busLen), const Radius.circular(3)),
      Paint()..color = Colors.redAccent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(busX + 10, busTop, 6, busLen), const Radius.circular(3)),
      Paint()..color = Colors.blueAccent,
    );

    // рейки
    final railsTop = margin + 46;
    final railsCount = 3;
    final railPaint = Paint()
      ..color = Colors.black.withOpacity(.35)
      ..strokeWidth = 2;
    for (int r = 0; r < railsCount; r++) {
      final y = railsTop + r * railGap;
      canvas.drawLine(Offset(margin + 50, y), Offset(size.width - margin - 20, y), railPaint);
    }

    // утилиты
    TextPainter tp(String s, {double size = 12, FontWeight w = FontWeight.w500}) {
      final t = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: Colors.white, fontSize: size, fontWeight: w)),
        textDirection: TextDirection.ltr,
      )..layout();
      return t;
    }

    Rect drawDevice(double x, double y, int modules,
        {String? label, Color color = const Color(0xFF596380)}) {
      final w = modules * modW + 8;
      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, modH), const Radius.circular(4));
      canvas.drawRRect(rr, Paint()..color = color);
      if (label != null) {
        final t = tp(label, size: 11);
        t.paint(canvas, Offset(x + 6, y + modH / 2 - t.height / 2));
      }
      return rr.outerRect;
    }

    double railY(int r) => railsTop + r * railGap - modH / 2;
    double railX(int c) => margin + 60 + c * modW;

    int col = 0, row = 0;
    void place(String label, int modules, {Color color = const Color(0xFF596380)}) {
      if (col + modules > perRail) {
        col = 0;
        row++;
      }
      final x = railX(col);
      final y = railY(row);
      drawDevice(x, y, modules, label: label, color: color);

      final wire = Paint()
        ..color = Colors.redAccent.withOpacity(.8)
        ..strokeWidth = 2;
      final anchorY = y + modH / 2;
      canvas.drawLine(Offset(busX + 3, anchorY), Offset(x - 6, anchorY), wire);

      col += modules + 1;
    }

    // ввод
    place('Ввод ${mainIn}A', 2, color: const Color(0xFF7380A0));
    if (mainRcd != null) {
      place('RCD ${mainRcd}mA', 2, color: const Color(0xFF6A8F7B));
    }

    // линии
    for (final l in lines) {
      final breaker = '${l['breaker_In']}A ${l['breaker_char']}';
      final rcd = l['rcd_mA'] as int?;
      final title = (l['title'] ?? '').toString();
      place('$title\n$breaker', 2, color: const Color(0xFF596380));
      if (rcd != null) {
        place('RCD ${rcd}mA', 2, color: const Color(0xFF6A8F7B));
      }
    }

    // заголовок
    final head = tp('Однофазный щит • дешёвый вариант', size: 13, w: FontWeight.w600);
    head.paint(canvas, Offset(margin + 60, margin + 12));
  }

  @override
  bool shouldRepaint(covariant FuseboardPainter old) =>
      old.mainIn != mainIn || old.mainRcd != mainRcd || old.phases != phases || old.lines != lines;
}