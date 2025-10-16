import 'dart:ui' as ui;
import '../core/wall_model.dart';

class RoomRect {
  final ui.Rect rectMm;
  RoomRect(this.rectMm);

  double get areaM2 => rectMm.width * rectMm.height / 1e6;
}

/// Простейший детектор прямоугольных помещений по четырём стенам
List<RoomRect> detectRectRooms(List<WallSeg> walls, {double tol = 1.0}) {
  // здесь оставь свою прежнюю логику; важно, что используется ui.Rect/ui.Offset
  return [];
}