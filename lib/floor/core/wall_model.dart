// lib/floor/core/wall_model.dart
import 'dart:ui' as ui;

/// Материал стены.
/// Оставил и "короткие" варианты (pgp/gkl) для совместимости со старым кодом.
enum WallMaterial {
  concrete,
  brick,
  aerated,      // газобетон
  wood,
  gypsumBlock,  // пазогребень (новое имя)
  drywall,      // ГКЛ (новое имя)

  // ↓ алиасы под старые имена, чтобы не падали обращения
  pgp,          // пазогребень (старое имя)
  gkl,          // ГКЛ (старое имя)
}

/// Сегмент стены в миллиметрах, линия задаётся по осевой.
class WallSeg {
  /// Конечные точки осевой линии, в мм (мировые координаты редактора)
  ui.Offset a;
  ui.Offset b;

  /// Толщина и высота, мм
  double thickMm;
  double heightMm;

  /// Материал
  WallMaterial material;

  /// Группа (для массового редактирования)
  int? groupId;

  /// Флаг выделения (ожидается в UI)
  bool selected;

  /// Универсальный конструктор:
  /// - можно передавать `a`/`b` ИЛИ `aMm`/`bMm` (для совместимости с существующим кодом).
  WallSeg({
    ui.Offset? a,
    ui.Offset? b,
    ui.Offset? aMm,
    ui.Offset? bMm,
    required this.thickMm,
    this.heightMm = 2700,
    this.material = WallMaterial.brick,
    this.groupId,
    this.selected = false,
  })  : a = a ?? aMm ?? const ui.Offset(0, 0),
        b = b ?? bMm ?? const ui.Offset(0, 0);

  /// Длина осевой (в мм)
  double get lengthMm => (b - a).distance;

  /// Центр отрезка (в мм)
  ui.Offset get centerMm => ui.Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  /// Единичный вектор вдоль стены
  ui.Offset get dir {
    final d = b - a;
    final l = d.distance;
    return l == 0 ? ui.Offset.zero : d / l;
  }

  /// Левая нормаль к оси
  ui.Offset get leftNormal {
    final d = dir;
    return ui.Offset(-d.dy, d.dx);
  }

  /// Копия с изменениями
  WallSeg copyWith({
    ui.Offset? a,
    ui.Offset? b,
    double? thickMm,
    double? heightMm,
    WallMaterial? material,
    int? groupId,
    bool? selected,
  }) {
    return WallSeg(
      a: a ?? this.a,
      b: b ?? this.b,
      thickMm: thickMm ?? this.thickMm,
      heightMm: heightMm ?? this.heightMm,
      material: material ?? this.material,
      groupId: groupId ?? this.groupId,
      selected: selected ?? this.selected,
    );
  }

  /// Простая BBox — удобно для быстрых проверок
  ui.Rect get bounds {
    final minX = _min(a.dx, b.dx);
    final minY = _min(a.dy, b.dy);
    final maxX = _max(a.dx, b.dx);
    final maxY = _max(a.dy, b.dy);
    return ui.Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

double _min(double x, double y) => x < y ? x : y;
double _max(double x, double y) => x > y ? x : y;

List<ui.Offset> wallEdges(WallSeg wall) {
  final n = wall.leftNormal;              // нормаль к стене
  final halfT = wall.thickMm / 2;
  final leftShift = n * halfT;
  final rightShift = -n * halfT;

  final leftA = wall.a + leftShift;
  final leftB = wall.b + leftShift;
  final rightA = wall.a + rightShift;
  final rightB = wall.b + rightShift;

  return [leftA, leftB, rightA, rightB];
}

/// Возвращает одну из граней (true = левая, false = правая)
List<ui.Offset> wallEdge(WallSeg wall, {bool left = true}) {
  final n = wall.leftNormal;
  final shift = n * (wall.thickMm / 2) * (left ? 1 : -1);
  return [wall.a + shift, wall.b + shift];
}