// lib/screens/assembly_preview.dart
import 'package:flutter/material.dart';
import 'calculator_screen.dart'; // если нет — закомментируй этот импорт и endDrawer

class AssemblyPreview extends StatelessWidget {
  final Map<String, dynamic> cheap;
  AssemblyPreview({super.key, required this.cheap});

  // ключ для RepaintBoundary (экспорт в PNG/PDF потом)
  final GlobalKey _rbKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final model = _Assembly.fromCheap(cheap);

    return Scaffold(
      appBar: AppBar(title: const Text('Сборка (черновик)')),
      // правая выезжающая панель с калькулятором
      endDrawer: Drawer(
  child: Align(
    alignment: Alignment.centerRight,
    child: FractionallySizedBox(
      widthFactor: 0.55,  // ширина (55% от экрана, можно 0.4–0.6)
      heightFactor: 0.85, // высота (85% от экрана)
      child: const Card(
        margin: EdgeInsets.all(12),
        child: CalculatorScreen(),
      ),
    ),
  ),
),
      body: Stack(
        children: [
          // зум/панорама
          InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 3.0,
            boundaryMargin: const EdgeInsets.all(200),
            child: RepaintBoundary(
              key: _rbKey,
              child: Center(
                child: CustomPaint(
                  size: const Size(1200, 800), // «лист» под сборку
                  painter: _AssemblyPainter(model),
                ),
              ),
            ),
          ),

          // «ручка» открытия боковой панели
          Positioned(
            right: 0,
            top: MediaQuery.of(context).size.height * .35,
            child: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => Scaffold.of(ctx).openEndDrawer(),
                child: Container(
                  width: 28,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.chevron_left, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== МОДЕЛЬ ДЛЯ ОТРИСОВКИ ===================== */

class _Assembly {
  _Assembly(this.rails, this.freeDin);

  final List<_Rail> rails;
  final int freeDin;

  // геометрия
  static const double leftMargin = 60;
  static const double topMargin = 80;
  static const double railGap = 150;
  static const double modW = 18;   // DIN-модуль ширина
  static const double modH = 30;   // DIN-модуль высота
  static const int railModules = 24;

  static _Assembly fromCheap(Map<String, dynamic> cheap) {
    // ожидаем cheap['lines'] как список линий
    final lines = (cheap['lines'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    // простое раскладывание по рейкам слева направо
    List<_Rail> rails = [ _Rail(0), _Rail(1), _Rail(2), _Rail(3) ];
    int currentRail = 0;
    int usedOnRail = 0;

    for (final l in lines) {
      final title = (l['title'] ?? '').toString();
      final inA = l['breaker_In'] ?? 16;
      final char = (l['breaker_char'] ?? '').toString();
      final need = 1; // пока по 1 модулю на линию (заглушка)
      if (usedOnRail + need > railModules) {
        currentRail = (currentRail + 1).clamp(0, rails.length - 1);
        usedOnRail = 0;
      }
      rails[currentRail].groups.add(_Group(
        title: title,
        moduleCount: need,
        mark: '$inA$char',
      ));
      usedOnRail += need;
    }

    // свободные модули считаем грубо
    int used = rails.fold(0, (sum, r) => sum + r.totalModules);
    int free = rails.length * railModules - used;
    if (free < 0) free = 0;

    return _Assembly(rails, free);
  }
}

class _Rail {
  _Rail(this.index);
  final int index;
  final List<_Group> groups = [];

  int get totalModules => groups.fold(0, (s, g) => s + g.moduleCount);
}

class _Group {
  _Group({required this.title, required this.moduleCount, required this.mark});
  final String title;       // подпись группы
  final int moduleCount;    // ширина в мод.
  final String mark;        // например: "16C"
}

/* ===================== ОТРИСОВКА ===================== */

class _AssemblyPainter extends CustomPainter {
  _AssemblyPainter(this.m);
  final _Assembly m;

  // «шины» сверху (L / N / PE)
  final Paint _busL  = Paint()..color = const Color(0xFFE74C3C)..strokeWidth = 3;
  final Paint _busN  = Paint()..color = const Color(0xFF3498DB)..strokeWidth = 3;
  final Paint _busPE = Paint()..color = const Color(0xFF2ECC71)..strokeWidth = 3;

  // провода вниз к автоматам
  final Paint _wireL  = Paint()..color = const Color(0xFFE74C3C)..strokeWidth = 2;
  final Paint _wireN  = Paint()..color = const Color(0xFF3498DB)..strokeWidth = 2;
  final Paint _wirePe = Paint()..color = const Color(0xFF2ECC71)..strokeWidth = 2;

  final _bgBox = Paint()..color = const Color(0xFF101317);
  final _railLine = Paint()
    ..color = Colors.white24
    ..strokeWidth = 1;

  @override
  void paint(Canvas c, Size size) {
    // фон «панели»
    c.drawRect(Offset.zero & size, _bgBox);

    final left = _Assembly.leftMargin;
    final top  = _Assembly.topMargin;
    final modW = _Assembly.modW;
    final modH = _Assembly.modH;

    // заголовок
    _text(c, 'Сборка (cheap)', const Offset(24, 24),
        const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600));

    // шины L/N/PE вверху
    final busLeft = left;
    final busRight = left + _Assembly.railModules * modW + 120;
    final busY = top - 40;
    c.drawLine(Offset(busLeft, busY), Offset(busRight, busY), _busL);
    c.drawLine(Offset(busLeft, busY + 10), Offset(busRight, busY + 10), _busN);
    c.drawLine(Offset(busLeft, busY + 20), Offset(busRight, busY + 20), _busPE);
    _text(c, 'L', Offset(busLeft - 18, busY - 8), const TextStyle(color: Colors.white));
    _text(c, 'N', Offset(busLeft - 18, busY + 2), const TextStyle(color: Colors.white));
    _text(c, 'PE', Offset(busLeft - 26, busY + 12), const TextStyle(color: Colors.white));

    // рисуем рейки и группы
    for (int r = 0; r < m.rails.length; r++) {
      final y = top + r * _Assembly.railGap;

      // линия рейки
      c.drawLine(Offset(left, y + modH / 2), Offset(busRight - 60, y + modH / 2), _railLine);
      _text(c, 'Рейка ${r + 1}', Offset(left - 54, y + modH / 2 - 10),
          const TextStyle(color: Colors.white70, fontSize: 12));

      // выкладка групп слева направо
      double x = left;
      for (final g in m.rails[r].groups) {
        final w = g.moduleCount * modW;
        final rect = Rect.fromLTWH(x, y, w, modH);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));

        // пунктирная рамка устройства + подпись
        _dashedRRect(c, rr);
        _text(c, g.title, Offset(x, y - 18),
            const TextStyle(color: Colors.white, fontSize: 12));
        _rectDevice(c, rect, name: 'QF', mark: g.mark);

        // проводники вниз от шин
        _wireDown(c, Offset(x + w * .50, busY), _wireL);   // фаза
        _wireDown(c, Offset(x + w * .32, busY + 10), _wireN);
        _wireDown(c, Offset(x + w * .68, busY + 20), _wirePe);

        x += w + 6;
      }

      // подпись свободного места (на последней рейке)
      if (r == m.rails.length - 1 && m.freeDin > 0) {
        final free = m.freeDin;
        final rx = left + (_Assembly.railModules - free) * modW + 8;
        final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(rx, y, free * modW - 8, modH),
          const Radius.circular(4),
        );
        _hatch(c, rr, ' $free DIN ');
      }
    }
  }

  // прямоугольник устройства с подписями
  void _rectDevice(Canvas c, Rect r, {required String name, required String mark}) {
    final fill = Paint()..color = Colors.white.withValues(alpha: .08);
    final stroke = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), fill);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), stroke);

    _text(c, name, r.topLeft + const Offset(6, 3),
        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12));
    _text(c, mark, r.bottomLeft + const Offset(6, -18),
        const TextStyle(color: Colors.white70, fontSize: 12));
  }

  // вертикальный провод от шины до устройства
  void _wireDown(Canvas c, Offset from, Paint p) {
    final to = Offset(from.dx, from.dy + 70);
    c.drawLine(from, to, p);
  }

  // пунктирная рамка — исправлено с computeMetrics()
  void _dashedRRect(Canvas c, RRect rr) {
    const dash = 6.0;
    const gap = 4.0;
    final path = Path()..addRRect(rr);
    for (final metric in path.computeMetrics()) {
      double d = 0.0;
      while (d < metric.length) {
        final seg = metric.extractPath(d, (d + dash).clamp(0, metric.length));
        c.drawPath(
          seg,
          Paint()
            ..color = Colors.white30
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        d += dash + gap;
      }
    }
  }

  // штриховка зоны (свободные DIN)
  void _hatch(Canvas c, RRect rr, String label) {
    final r = rr.outerRect;
    final paint = Paint()..color = Colors.white12;
    c.drawRRect(rr, paint);

    // диагонали
    final diag = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (double x = r.left; x < r.right + r.height; x += 8) {
      c.drawLine(Offset(x, r.top), Offset(x - r.height, r.bottom), diag);
    }

    _text(c, label, Offset(r.center.dx - 24, r.center.dy - 8),
        const TextStyle(color: Colors.white, fontSize: 12));
  }

  void _text(Canvas c, String text, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(covariant _AssemblyPainter old) => old.m != m;
}
