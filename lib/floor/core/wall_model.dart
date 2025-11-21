// lib/floor/core/wall_model.dart
import 'dart:ui' as ui;
import 'dart:math' as math;

/// Материал стены.
enum WallMaterial {
  concrete,
  brick,
  aerated,      // газобетон
  wood,
  gypsumBlock,  // пазогребень (новое имя)
  drywall,      // ГКЛ (новое имя)

  // алиасы под старые имена
  pgp,          // пазогребень (старое имя)
  gkl,          // ГКЛ (старое имя)
}

/// Сегмент стены по осевой линии в мм.
class WallSeg {
  /// Концы оси (в мм, мировые координаты)
  ui.Offset a;
  ui.Offset b;

  /// Толщина / высота
  double thickMm;
  double heightMm;

  /// Материал
  WallMaterial material;

  /// Группа (на будущее)
  int? groupId;

  /// Флаг выделения
  bool selected;

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

  double get lengthMm => (b - a).distance;

  ui.Offset get centerMm => ui.Offset(
        (a.dx + b.dx) / 2,
        (a.dy + b.dy) / 2,
      );

  /// Нормализованный вектор вдоль стены
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

/// Возвращает 4 точки граней стены (левый и правый контуры).
/// Порядок: [leftA, leftB, rightA, rightB]
List<ui.Offset> wallEdges(WallSeg wall) {
  final n = wall.leftNormal;
  final halfT = wall.thickMm / 2;
  final leftShift = n * halfT;
  final rightShift = -n * halfT;

  final leftA = wall.a + leftShift;
  final leftB = wall.b + leftShift;
  final rightA = wall.a + rightShift;
  final rightB = wall.b + rightShift;

  return [leftA, leftB, rightB, rightA];
}

/// Одна грань (true = левая, false = правая)
List<ui.Offset> wallEdge(WallSeg wall, {bool left = true}) {
  final n = wall.leftNormal;
  final shift = n * (wall.thickMm / 2) * (left ? 1 : -1);
  return [wall.a + shift, wall.b + shift];
}
// ---------------- ГЕОМЕТРИЯ ДЛЯ СТЕН ----------------

double _dot(ui.Offset a, ui.Offset b) => a.dx * b.dx + a.dy * b.dy;

/// Расстояние от точки p до прямой (a-b), в тех же единицах (мм)
double _pointLineDistance(ui.Offset p, ui.Offset a, ui.Offset b) {
  final ab = b - a;
  final ap = p - a;
  final area2 = (ab.dx * ap.dy - ab.dy * ap.dx).abs();
  final len = ab.distance;
  if (len < 1e-6) return ap.distance;
  return area2 / len;
}

/// Почти одинаковые отрезки (с учётом направления), дубликаты.
bool _areSegmentsAlmostEqual(
  WallSeg a,
  WallSeg b, {
  double tolMm = 5,
}) {
  final d1 = (a.a - b.a).distance;
  final d2 = (a.b - b.b).distance;
  final d3 = (a.a - b.b).distance;
  final d4 = (a.b - b.a).distance;

  // Совпадают по прямому или обратному направлению
  return (d1 <= tolMm && d2 <= tolMm) || (d3 <= tolMm && d4 <= tolMm);
}

/// Находятся ли стены на одной прямой и перекрываются по длине.
bool _areCollinearAndOverlapping(
  WallSeg w1,
  WallSeg w2, {
  double tolMm = 5,
  double angTolDeg = 2,
}) {
  final v1 = w1.b - w1.a;
  final v2 = w2.b - w2.a;

  final len1 = v1.distance;
  final len2 = v2.distance;
  if (len1 < 1e-3 || len2 < 1e-3) return false;

  // проверяем параллельность (угол ~ 0° или 180°)
  final cosAng = _dot(v1, v2).abs() / (len1 * len2);
  final maxAngleRad = angTolDeg * (math.pi / 180.0);
  final cosMin = math.cos(maxAngleRad);
  if (cosAng < cosMin) return false;

  // обе точки второй стены должны лежать близко к прямой первой
  final dA = _pointLineDistance(w2.a, w1.a, w1.b);
  final dB = _pointLineDistance(w2.b, w1.a, w1.b);
  if (dA > tolMm || dB > tolMm) return false;

  // проверяем перекрытие проекций
  double proj(ui.Offset p) {
    if (v1.dx.abs() >= v1.dy.abs()) {
      return p.dx;
    } else {
      return p.dy;
    }
  }

  final a1 = proj(w1.a);
  final b1 = proj(w1.b);
  final a2 = proj(w2.a);
  final b2 = proj(w2.b);

  final min1 = math.min(a1, b1);
  final max1 = math.max(a1, b1);
  final min2 = math.min(a2, b2);
  final max2 = math.max(a2, b2);

  final overlapMin = math.max(min1, min2);
  final overlapMax = math.min(max1, max2);

  // если есть пересечение интервалов (с небольшим запасом) — перекрываются
  return overlapMax >= overlapMin - tolMm;
}

/// Объединяет две коллинеарные перекрывающиеся стены в одну.
WallSeg _mergeCollinear(WallSeg w1, WallSeg w2) {
  final v = w1.b - w1.a;

  double proj(ui.Offset p) {
    if (v.dx.abs() >= v.dy.abs()) {
      return p.dx;
    } else {
      return p.dy;
    }
  }

  final allPoints = <ui.Offset>[
    w1.a,
    w1.b,
    w2.a,
    w2.b,
  ];

  // выбираем самую "левую" и самую "правую" точки вдоль оси
  allPoints.sort((p, q) => proj(p).compareTo(proj(q)));
  final newA = allPoints.first;
  final newB = allPoints.last;

  return WallSeg(
    a: newA,
    b: newB,
    thickMm: w1.thickMm,
    heightMm: w1.heightMm,
    material: w1.material,
    groupId: w1.groupId,
  );
}
/// Возвращает точку пересечения двух отрезков p1–p2 и p3–p4.
/// Если пересечения нет — вернёт null.
ui.Offset? segmentIntersection(
  ui.Offset p1,
  ui.Offset p2,
  ui.Offset p3,
  ui.Offset p4,
) {
  final x1 = p1.dx, y1 = p1.dy;
  final x2 = p2.dx, y2 = p2.dy;
  final x3 = p3.dx, y3 = p3.dy;
  final x4 = p4.dx, y4 = p4.dy;

  final denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
  if (denom.abs() < 1e-6) return null; // параллельные линии

  final px = ((x1 * y2 - y1 * x2) * (x3 - x4) -
              (x1 - x2) * (x3 * y4 - y3 * x4)) / denom;

  final py = ((x1 * y2 - y1 * x2) * (y3 - y4) -
              (y1 - y2) * (x3 * y4 - y3 * x4)) / denom;

  final p = ui.Offset(px, py);

  bool onSegment(ui.Offset a, ui.Offset b, ui.Offset p) {
    return p.dx >= math.min(a.dx, b.dx) - 0.1 &&
           p.dx <= math.max(a.dx, b.dx) + 0.1 &&
           p.dy >= math.min(a.dy, b.dy) - 0.1 &&
           p.dy <= math.max(a.dy, b.dy) + 0.1;
  }

  if (!onSegment(p1, p2, p)) return null;
  if (!onSegment(p3, p4, p)) return null;

  return p;
}
/// Делит стену на две в точке p.
/// Возвращает два новых сегмента (или один, если p слишком близко).
List<WallSeg> splitWallAtPoint(WallSeg wall, ui.Offset p, {double tolMm = 2}) {
  final dA = (wall.a - p).distance;
  final dB = (wall.b - p).distance;

  // если точка фактически совпадает с концом — не разрезаем
  if (dA < tolMm || dB < tolMm) return [wall];

  return [
    WallSeg(
      a: wall.a,
      b: p,
      thickMm: wall.thickMm,
      heightMm: wall.heightMm,
      material: wall.material,
      groupId: wall.groupId,
    ),
    WallSeg(
      a: p,
      b: wall.b,
      thickMm: wall.thickMm,
      heightMm: wall.heightMm,
      material: wall.material,
      groupId: wall.groupId,
    ),
  ];
}
/// Умная вставка стены:
/// - притягивает концы к существующим узлам
/// - отбрасывает дубликаты
/// - сливает коллинеарные перекрывающиеся стены
void insertWallSmart(
  List<WallSeg> walls,
  WallSeg candidate, {
  double snapTolMm = 3,        // МАЛЕНЬКИЙ толеранс только для склейки вершин
  double collinearTolMm = 5,   // Толеранс для объединения коллинеарных
  double angTolDeg = 2,        // Угол для коллинеарности
}) {

  // 0) ОТБРАСЫВАЕМ слишком короткие стены
  if (candidate.lengthMm < 1.0) return;

  // ===========================================================
  // 1) ПОДТЯГИВАЕМ ТОЛЬКО К ВЕРШИНАМ (не к рёбрам!)
  // ===========================================================

  for (final w in walls) {
    // — проверяем A
    if ((candidate.a - w.a).distance <= snapTolMm) {
      candidate.a = w.a;
    } else if ((candidate.a - w.b).distance <= snapTolMm) {
      candidate.a = w.b;
    }

    // — проверяем B
    if ((candidate.b - w.a).distance <= snapTolMm) {
      candidate.b = w.a;
    } else if ((candidate.b - w.b).distance <= snapTolMm) {
      candidate.b = w.b;
    }
  }

  // ===========================================================
  // 2) ПРОВЕРКА НА ПОЛНЫЙ ДУБЛИКАТ
  // ===========================================================
  for (final w in walls) {
    if (_areSegmentsAlmostEqual(candidate, w, tolMm: collinearTolMm)) {
      return; // уже есть такая стена
    }
  }

  // ===========================================================
  // 3) СЛИЯНИЕ КОЛЛИНЕАРНЫХ ПЕРЕКРЫВАЮЩИХСЯ СТЕН
  // ===========================================================

  final toRemove = <WallSeg>[];
  var merged = candidate;

  for (final w in walls) {
    if (_areCollinearAndOverlapping(
      merged,
      w,
      tolMm: collinearTolMm,
      angTolDeg: angTolDeg,
    )) {
      merged = _mergeCollinear(merged, w);
      toRemove.add(w);
    }
  }

  if (toRemove.isNotEmpty) {
    walls.removeWhere((w) => toRemove.contains(w));
  }

  // ===========================================================
  // 4) РЕЗКА ПЕРЕСЕЧЕНИЙ
  // ===========================================================

  final pieces = <WallSeg>[merged];
  final wallsToRemove = <WallSeg>[];
  final wallsToAdd = <WallSeg>[];

  for (final w in walls) {
    for (final piece in List<WallSeg>.from(pieces)) {
      final ip = segmentIntersection(piece.a, piece.b, w.a, w.b);

      if (ip != null) {
        // режем существующую
        final splitOld = splitWallAtPoint(w, ip);
        if (splitOld.length == 2) {
          wallsToRemove.add(w);
          wallsToAdd.addAll(splitOld);
        }

        // режем кандидата
        final splitNew = splitWallAtPoint(piece, ip);
        if (splitNew.length == 2) {
          pieces.remove(piece);
          pieces.addAll(splitNew);
        }
      }
    }
  }

  if (wallsToRemove.isNotEmpty) {
    walls.removeWhere((w) => wallsToRemove.contains(w));
    walls.addAll(wallsToAdd);
  }

  // ===========================================================
  // 5) ДОБАВЛЯЕМ ВСЕ КУСОЧКИ НОВОЙ СТЕНЫ
  // ===========================================================

  walls.addAll(pieces);
}
