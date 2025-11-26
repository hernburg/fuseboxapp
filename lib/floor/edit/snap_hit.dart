import 'dart:ui' as ui;
import '../core/wall_model.dart';

enum SnapKind {
  none,
  vertex,
  edge,
}

class SnapHit {
  final SnapKind kind;
  final ui.Offset snapped;       // куда привязались
  final WallSeg? wall;           // если edge
  final ui.Offset? vertex;       // если vertex
  final bool isLeftSide;         // для edge

  const SnapHit({
    required this.kind,
    required this.snapped,
    this.wall,
    this.vertex,
    this.isLeftSide = true,
  });

  static const noneHit = SnapHit(kind: SnapKind.none, snapped: ui.Offset.zero);
}

class SnapSettings {
  final bool enabled;
  final double vertexRadiusMm;

  const SnapSettings({
    required this.enabled,
    this.vertexRadiusMm = 120,
  });
}
