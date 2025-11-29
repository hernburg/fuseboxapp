import 'package:flutter/material.dart';
import '../core/wall_model.dart';
import '../core/vec2.dart';

class WallPainter extends CustomPainter {
  final List<WallSegment> walls;
  final List<WallSegment> preview;
  final Matrix4 transform;
  WallPainter(this.walls, {this.preview = const [], Matrix4? transform}) : transform = transform ?? Matrix4.identity();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transform.storage);

    final paint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.fill;

    for (var wall in walls) {
      _paintWall(canvas, wall, paint);
    }

    if (preview.isNotEmpty) {
      final previewPaint = Paint()
        ..color = Colors.orangeAccent.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;

      for (var wall in preview) {
        _paintWall(canvas, wall, previewPaint);
      }
    }

    canvas.restore();
  }

  void _paintWall(Canvas canvas, WallSegment wall, Paint paint) {
    final dir = (wall.p2 - wall.p1).normalized();
    final normal = Vec2(-dir.y, dir.x);

    final half = wall.thickness / 2;

    final p1l = Offset(wall.p1.x + normal.x * half, wall.p1.y + normal.y * half);
    final p1r = Offset(wall.p1.x - normal.x * half, wall.p1.y - normal.y * half);

    final p2l = Offset(wall.p2.x + normal.x * half, wall.p2.y + normal.y * half);
    final p2r = Offset(wall.p2.x - normal.x * half, wall.p2.y - normal.y * half);

    final path = Path()
      ..moveTo(p1l.dx, p1l.dy)
      ..lineTo(p2l.dx, p2l.dy)
      ..lineTo(p2r.dx, p2r.dy)
      ..lineTo(p1r.dx, p1r.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WallPainter oldDelegate) {
    return oldDelegate.walls != walls || oldDelegate.preview != preview || oldDelegate.transform != transform;
  }
}
