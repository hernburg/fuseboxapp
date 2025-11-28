import 'geometry.dart';
import 'node_graph.dart';
import 'vec2.dart';

class WallSegment {
  static const double defaultThickness = 100.0;
  final int id;
  Vec2 p1;
  Vec2 p2;
  double thickness;
  bool thickToLeft;
  WallNode? nodeStart;
  WallNode? nodeEnd;
  late Vec2 l1, r1, l2, r2;

  WallSegment({
    required this.id,
    required this.p1,
    required this.p2,
    this.thickness = defaultThickness,
    this.thickToLeft = true,
    this.nodeStart,
    this.nodeEnd,
  }) {
    _updateCorners();
  }

  void _updateCorners() {
    Vec2 direction = (p2 - p1).normalized();
    Vec2 normalLeft = direction.rotated90CCW();
    Vec2 normalRight = direction.rotated90CW();

    Vec2 outerOffset;
    Vec2 innerOffset;
    if (thickToLeft) {
      outerOffset = normalLeft * (thickness / 2);
      innerOffset = normalRight * (thickness / 2);
    } else {
      outerOffset = normalRight * (thickness / 2);
      innerOffset = normalLeft * (thickness / 2);
    }

    l1 = p1 + outerOffset;
    r1 = p1 + innerOffset;
    l2 = p2 + outerOffset;
    r2 = p2 + innerOffset;
  }

  void updateCorners() => _updateCorners();

  void attachToNodes() {
    if (nodeStart != null) p1 = nodeStart!.position;
    if (nodeEnd != null) p2 = nodeEnd!.position;
    _updateCorners();
  }

  List<WallSegment> splitAt(Vec2 splitPoint) {
    WallNode nodeMid = WallNode(position: splitPoint);
    WallSegment part1 = WallSegment(
      id: NodeGraph.newSegmentId(),
      p1: p1,
      p2: splitPoint,
      thickness: thickness,
      thickToLeft: thickToLeft,
      nodeStart: nodeStart,
      nodeEnd: nodeMid,
    );
    WallSegment part2 = WallSegment(
      id: NodeGraph.newSegmentId(),
      p1: splitPoint,
      p2: p2,
      thickness: thickness,
      thickToLeft: thickToLeft,
      nodeStart: nodeMid,
      nodeEnd: nodeEnd,
    );
    nodeMid.attachSegments([part1, part2]);
    nodeStart?.replaceSegment(oldSeg: this, newSeg: part1);
    nodeEnd?.replaceSegment(oldSeg: this, newSeg: part2);
    return [part1, part2];
  }
}

class WallNode {
  static int _nextId = 0;
  final int id;
  Vec2 position;
  final List<WallSegment> segments = [];

  WallNode({required this.position}) : id = _nextId++;

  void attachSegments(List<WallSegment> segs) {
    for (var seg in segs) {
      if ((seg.p1 - position).length() < 1e-6) {
        seg.nodeStart = this;
      }
      if ((seg.p2 - position).length() < 1e-6) {
        seg.nodeEnd = this;
      }
      segments.add(seg);
    }
  }

  void replaceSegment({required WallSegment oldSeg, required WallSegment newSeg}) {
    segments.remove(oldSeg);
    segments.add(newSeg);
    if ((newSeg.p1 - position).length() < 1e-6) {
      newSeg.nodeStart = this;
    }
    if ((newSeg.p2 - position).length() < 1e-6) {
      newSeg.nodeEnd = this;
    }
  }
}
