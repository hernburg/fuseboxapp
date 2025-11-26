// // lib/floor/edit/selection.dart
// import 'dart:ui' as ui;
// import '../core/wall_model.dart';
// import '../core/geometry.dart' show pointSegDist, segsIntersect;

// /// Индекс ближайшей стены к точке pMm (мм), либо null
// int? hitWallIndex(List<WallSeg> walls, ui.Offset pMm, {double tolMm = 120}) {
//   double best = double.infinity;
//   int? idx;
//   for (var i = 0; i < walls.length; i++) {
//     final w = walls[i];
//     final d = pointSegDist(pMm, w.a, w.b);
//     if (d <= tolMm && d < best) {
//       best = d;
//       idx = i;
//     }
//   }
//   return idx;
// }

// /// Выбор стен «рамкой». Возвращает индексы попавших стен.
// /// Считаем попаданием: хотя бы одна точка внутри прямоугольника
// /// ИЛИ пересечение с любой гранью прямоугольника.
// List<int> marqueePick(List<WallSeg> walls, ui.Rect rMm) {
//   final List<int> out = [];
//   final edges = <List<ui.Offset>>[
//     [rMm.topLeft, rMm.topRight],
//     [rMm.topRight, rMm.bottomRight],
//     [rMm.bottomRight, rMm.bottomLeft],
//     [rMm.bottomLeft, rMm.topLeft],
//   ];
//   bool inside(ui.Offset p) => rMm.contains(p);

//   for (var i = 0; i < walls.length; i++) {
//     final w = walls[i];
//     final touches = inside(w.a) || inside(w.b) ||
//         edges.any((e) => segsIntersect(w.a, w.b, e[0], e[1]));
//     if (touches) out.add(i);
//   }
//   return out;
// }
