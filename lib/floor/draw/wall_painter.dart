import 'package:flutter/material.dart';
import '../core/wall_model.dart';

class WallPainter extends CustomPainter {
  final List<WallSegment> walls;

  WallPainter(this.walls);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[800]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (var wall in walls) {
      canvas.drawLine(Offset(wall.p1.x, wall.p1.y), Offset(wall.p2.x, wall.p2.y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WallPainter oldDelegate) {
    return oldDelegate.walls != walls;
  }
}
