import 'package:flutter/material.dart';
import '../core/wall_model.dart';

class WallPainter extends CustomPainter {
  final List<WallSegment> walls;
  final List<WallSegment> preview;

  WallPainter(this.walls, {this.preview = const []});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[800]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (var wall in walls) {
      canvas.drawLine(Offset(wall.p1.x, wall.p1.y), Offset(wall.p2.x, wall.p2.y), paint);
    }

    if (preview.isNotEmpty) {
      final previewPaint = Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (var wall in preview) {
        canvas.drawLine(
          Offset(wall.p1.x, wall.p1.y),
          Offset(wall.p2.x, wall.p2.y),
          previewPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant WallPainter oldDelegate) {
    return oldDelegate.walls != walls || oldDelegate.preview != preview;
  }
}
