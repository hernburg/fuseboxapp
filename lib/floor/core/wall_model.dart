import 'dart:ui' as ui;
import '../../utils/log.dart';

/// Сегмент стены.
/// a/b — это направляющая Y2 (ось Z). Толщина полностью откладывается
/// в одну сторону (X1 → Y1 → X2).
class WallSeg {
  /// Начало направляющей (угол A на схеме)
  final ui.Offset a;

  /// Конец направляющей (угол D)
  final ui.Offset b;

  /// Толщина стены (сплошь в одну сторону) в мм
  final double thickMm;

  /// true  — толщина идёт влево от a→b (normalLeft)
  /// false — толщина идёт вправо (normalRight)
  final bool thickToLeft;

  const WallSeg({
    required this.a,
    required this.b,
    required this.thickMm,
    this.thickToLeft = true,
  });

  /// Нормализованное направление направляющей (Y2)
  ui.Offset get dir {
    final d = b - a;
    final len = d.distance;
    if (len < 1e-6) return const ui.Offset(1, 0);
    return d / len;
  }

  /// Левая нормаль (вектор внутрь при thickToLeft = true)
  ui.Offset get normalLeft => ui.Offset(-dir.dy, dir.dx);

  /// Правая нормаль
  ui.Offset get normalRight => ui.Offset(dir.dy, -dir.dx);

  /// Нормаль, вдоль которой откладываем толщину
  ui.Offset get thicknessNormal =>
      thickToLeft ? normalLeft : normalRight;

  /// Длина направляющей
  double get length => (b - a).distance;

  /// Четырёхугольник стены A-B-C-D (см. схему)
  List<ui.Offset> get quad {
    final n = thicknessNormal;
    final t = thickMm;
    final pA = a;
    final pD = b;
    final pB = pA + n * t;
    final pC = pD + n * t;
    return [pA, pB, pC, pD];
  }

  ui.Offset get cornerA => quad[0];
  ui.Offset get cornerB => quad[1];
  ui.Offset get cornerC => quad[2];
  ui.Offset get cornerD => quad[3];

  WallSeg copyWith({
    ui.Offset? a,
    ui.Offset? b,
    double? thickMm,
    bool? thickToLeft,
  }) {
    return WallSeg(
      a: a ?? this.a,
      b: b ?? this.b,
      thickMm: thickMm ?? this.thickMm,
      thickToLeft: thickToLeft ?? this.thickToLeft,
    );
  }

  factory WallSeg.fromGuide({
    required ui.Offset start,
    required ui.Offset end,
    required double thickMm,
    bool thickToLeft = true,
  }) {
    return WallSeg(
      a: start,
      b: end,
      thickMm: thickMm,
      thickToLeft: thickToLeft,
    );
  }

  // ==============================
  //        ЛОГ УГЛОВ A1 B1 C1 D1
  // ==============================
  void logWall(String title) {
    logMsg(
      'WALL',
      '$title '
      'a1=${cornerA.dx.toStringAsFixed(2)},${cornerA.dy.toStringAsFixed(2)} '
      'b1=${cornerB.dx.toStringAsFixed(2)},${cornerB.dy.toStringAsFixed(2)} '
      'c1=${cornerC.dx.toStringAsFixed(2)},${cornerC.dy.toStringAsFixed(2)} '
      'd1=${cornerD.dx.toStringAsFixed(2)},${cornerD.dy.toStringAsFixed(2)}'
    );
  }
}

/// --------------------------------------------------------------
///    ОТДЕЛЬНОЕ RUNTIME-РАСШИРЕНИЕ ДЛЯ ПОИСКА БЛИЖАЙШЕГО УГЛА
/// --------------------------------------------------------------
extension WallSegCorners on WallSeg {
  ui.Offset nearestCornerTo(ui.Offset p) {
    final q = quad;
    ui.Offset best = q[0];
    double bestD = (p - q[0]).distanceSquared;

    for (int i = 1; i < 4; i++) {
      final d = (p - q[i]).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = q[i];
      }
    }
    return best;
  }
}
