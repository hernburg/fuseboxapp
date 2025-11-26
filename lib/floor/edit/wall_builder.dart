// lib/floor/edit/wall_builder.dart
//
// Builder v4.0 — правильная классификация углов.
// Работает по утверждённой таблице направлений:
//
//  УГОЛ d1: ↓, →    => A2
//  УГОЛ c1: ↑, →    => B2
//  УГОЛ a1: ↓, ←    => B2
//  УГОЛ b1: ↑, ←    => A2
//
// Все остальные направления — запрещены.
//

import 'dart:ui' as ui;
import '../core/wall_model.dart';
import '../core/geometry.dart' as geom;
import '../core/pick_corner.dart';
import '../../utils/event_logger.dart';

String f2(ui.Offset o) =>
    '(${o.dx.toStringAsFixed(2)},${o.dy.toStringAsFixed(2)})';

enum _CornerRole {
  asA2, // новый A2 = baseCorner
  asB2, // новый A2 = baseCorner - n*t
}

enum _WallDir {
  lr, // left → right
  rl, // right → left
  bt, // bottom → top
  tb, // top → bottom
}

_WallDir _detectWallDir(ui.Offset a, ui.Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;

  if (dx.abs() >= dy.abs()) {
    return dx >= 0 ? _WallDir.lr : _WallDir.rl;
  } else {
    return dy >= 0 ? _WallDir.bt : _WallDir.tb;
  }
}

ui.Offset _normLeft(ui.Offset d) => ui.Offset(-d.dy, d.dx);
ui.Offset _normRight(ui.Offset d) => ui.Offset(d.dy, -d.dx);

bool _same(ui.Offset a, ui.Offset b, [double eps = 0.1]) =>
    (a - b).distance <= eps;

/// Логгер
void _logEvent(String msg) {
  EventLogger().log(msg);
  logMsg(msg);
}

/// Выбор стороны толщины
bool _chooseThickToLeft({
  required ui.Offset newDir,
  required ui.Offset baseNormal,
}) {
  final left = _normLeft(newDir);
  final right = _normRight(newDir);

  final dotL = left.dx * baseNormal.dx + left.dy * baseNormal.dy;
  final dotR = right.dx * baseNormal.dx + right.dy * baseNormal.dy;

  return dotL < dotR;
}

/// ===========================================================
/// КЛАССИФИКАТОР УГЛА
/// ===========================================================
///
///  d1: ↓, →    => A2
///  c1: ↑, →    => B2
///  a1: ↓, ←    => B2
///  b1: ↑, ←    => A2
///
_CornerRole? _classify({
  required WallSeg baseWall,
  required ui.Offset corner,
  required ui.Offset dir,
}) {
  final a1 = baseWall.cornerA;
  final b1 = baseWall.cornerB;
  final c1 = baseWall.cornerC;
  final d1 = baseWall.cornerD;

  final dx = dir.dx;
  final dy = dir.dy;

  _logEvent('[CLASSIFY] corner=${f2(corner)} dir=(${dx.toStringAsFixed(2)},${dy.toStringAsFixed(2)})');

  final isUp    = dy < 0 && dx.abs() < 1e-6;
  final isDown  = dy > 0 && dx.abs() < 1e-6;
  final isRight = dx > 0 && dy.abs() < 1e-6;
  final isLeft  = dx < 0 && dy.abs() < 1e-6;

  // ======================
  // d1
  // ======================
  if (_same(corner, d1)) {
    if (isDown) {
      _logEvent('[CLASSIFY RESULT] d1↓ → A2');
      return _CornerRole.asA2;
    }
    if (isRight) {
      _logEvent('[CLASSIFY RESULT] d1→ → A2');
      return _CornerRole.asA2;
    }
    _logEvent('[CLASSIFY RESULT] d1 INVALID');
    return null;
  }

  // ======================
  // c1
  // ======================
  if (_same(corner, c1)) {
    if (isUp) {
      _logEvent('[CLASSIFY RESULT] c1↑ → B2');
      return _CornerRole.asB2;
    }
    if (isRight) {
      _logEvent('[CLASSIFY RESULT] c1→ → B2');
      return _CornerRole.asB2;
    }
    _logEvent('[CLASSIFY RESULT] c1 INVALID');
    return null;
  }

  // ======================
  // a1
  // ======================
  if (_same(corner, a1)) {
    if (isDown) {
      _logEvent('[CLASSIFY RESULT] a1↓ → B2');
      return _CornerRole.asB2;
    }
    if (isLeft) {
      _logEvent('[CLASSIFY RESULT] a1← → B2');
      return _CornerRole.asB2;
    }
    _logEvent('[CLASSIFY RESULT] a1 INVALID');
    return null;
  }

  // ======================
  // b1
  // ======================
  if (_same(corner, b1)) {
    if (isUp) {
      _logEvent('[CLASSIFY RESULT] b1↑ → A2');
      return _CornerRole.asA2;
    }
    if (isLeft) {
      _logEvent('[CLASSIFY RESULT] b1← → A2');
      return _CornerRole.asA2;
    }
    _logEvent('[CLASSIFY RESULT] b1 INVALID');
    return null;
  }

  _logEvent('[CLASSIFY RESULT] UNMATCHED CORNER');
  return null;
}

/// ===========================================================
/// BUILDER — ОТ УГЛА
/// ===========================================================
List<WallSeg> buildWallFromCorner({
  required WallSeg baseWall,
  required ui.Offset baseCorner,
  required ui.Offset gestureEnd,
  required bool isLeftSide,
  required double newThick,
}) {
  final gesture = gestureEnd - baseCorner;
  if (gesture.distance < 1e-3) return const <WallSeg>[];

  _logEvent('[BUILDER CORNER] baseCorner=${f2(baseCorner)} gesture=${f2(gesture)}');

  final newDir = geom.computeAxisDirection(gesture);
  _logEvent('[DIRECTION] newDir=${f2(newDir)}');

  final role = _classify(baseWall: baseWall, corner: baseCorner, dir: newDir);
  if (role == null) {
    _logEvent('[DENY] classification=null → no wall built');
    return const <WallSeg>[];
  }

  final dirBase = baseWall.dir;
  final baseN =
      isLeftSide ? _normLeft(dirBase) : _normRight(dirBase);

  final thickToLeft = _chooseThickToLeft(
    newDir: newDir,
    baseNormal: baseN,
  );

  final n = thickToLeft ? _normLeft(newDir) : _normRight(newDir);

  _logEvent('[THICK] thickToLeft=$thickToLeft  n=${f2(n)}');

  final proj = gesture.dx * newDir.dx + gesture.dy * newDir.dy;
  if (proj.abs() < 1e-3) {
    _logEvent('[DENY] proj too small');
    return const <WallSeg>[];
  }
  final L = proj;

  late ui.Offset a2;

  switch (role) {
    case _CornerRole.asA2:
      a2 = baseCorner;
      _logEvent('[A2 MODE] A2 = baseCorner = ${f2(a2)}');
      break;

    case _CornerRole.asB2:
      a2 = baseCorner - n * newThick;
      _logEvent('[B2 MODE] A2 = baseCorner - n*t = ${f2(a2)}');
      break;
  }

  final d2 = a2 + newDir * L;
  _logEvent('[D2] d2=${f2(d2)} L=${L.toStringAsFixed(2)}');

  final wall = WallSeg(
    a: a2,
    b: d2,
    thickMm: newThick,
    thickToLeft: thickToLeft,
  );

  _logEvent('[RETURN CORNER] a2=${f2(a2)} d2=${f2(d2)}');

  return [wall];
}

/// ===========================================================
/// BUILDER — ОТ СТОРОНЫ
/// ===========================================================
List<WallSeg> buildWallFromSide({
  required WallSeg baseWall,
  required ui.Offset attachPoint,
  required ui.Offset gestureEnd,
  required bool isLeftSide,
  required double newThick,
}) {
  final rawGesture = gestureEnd - attachPoint;
  if (rawGesture.distance < 1e-3) return const <WallSeg>[];

  final newDir = geom.computeAxisDirection(rawGesture);

  final baseCorner = pickCornerSmart(
    baseWall: baseWall,
    dir: newDir,
    finger: attachPoint,
  );

  final gesture = gestureEnd - baseCorner;
  if (gesture.distance < 1e-3) return const <WallSeg>[];

  _logEvent('[BUILDER SIDE] attach=${f2(attachPoint)} baseCorner=${f2(baseCorner)} gesture=${f2(gesture)}');
  _logEvent('[DIRECTION] newDir=${f2(newDir)}');

  final role = _classify(baseWall: baseWall, corner: baseCorner, dir: newDir);
  if (role == null) {
    _logEvent('[DENY] classification=null → no wall built');
    return const <WallSeg>[];
  }

  final dirBase = baseWall.dir;
  final baseN =
      isLeftSide ? _normLeft(dirBase) : _normRight(dirBase);

  final thickToLeft = _chooseThickToLeft(
    newDir: newDir,
    baseNormal: baseN,
  );

  final n = thickToLeft ? _normLeft(newDir) : _normRight(newDir);

  _logEvent('[THICK] thickToLeft=$thickToLeft  n=${f2(n)}');

  final proj = gesture.dx * newDir.dx + gesture.dy * newDir.dy;
  if (proj.abs() < 1e-3) {
    _logEvent('[DENY] proj too small');
    return const <WallSeg>[];
  }

  final L = proj;

  late ui.Offset a2;

  switch (role) {
    case _CornerRole.asA2:
      a2 = baseCorner;
      _logEvent('[A2 MODE] A2 = baseCorner = ${f2(a2)}');
      break;

    case _CornerRole.asB2:
      a2 = baseCorner - n * newThick;
      _logEvent('[B2 MODE] A2 = baseCorner - n*t = ${f2(a2)}');
      break;
  }

  final d2 = a2 + newDir * L;
  _logEvent('[D2] d2=${f2(d2)} L=${L.toStringAsFixed(2)}');

  final wall = WallSeg(
    a: a2,
    b: d2,
    thickMm: newThick,
    thickToLeft: thickToLeft,
  );

  _logEvent('[RETURN SIDE] a2=${f2(a2)} d2=${f2(d2)}');

  return [wall];
}
