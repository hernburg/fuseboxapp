import '../core/wall_model.dart';
import '../core/vec2.dart';

enum SnapKind { none, node, edge }

class SnapHit {
  final SnapKind kind;
  final Vec2 snapped;
  final WallSegment? wall;
  final bool isLeftSide;

  SnapHit({
    required this.kind,
    required this.snapped,
    this.wall,
    this.isLeftSide = true,
  });
}
