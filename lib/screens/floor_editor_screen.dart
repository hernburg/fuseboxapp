import 'package:flutter/material.dart';
import '../screens/floor_editor.dart';
import '../floor/core/vec2.dart';
import '../floor/draw/wall_painter.dart';

class FloorEditorScreen extends StatefulWidget {
  const FloorEditorScreen({super.key});

  @override
  State<FloorEditorScreen> createState() => _FloorEditorScreenState();
}

class _FloorEditorScreenState extends State<FloorEditorScreen> {
  late final FloorEditorController editorController;

  @override
  void initState() {
    super.initState();
    editorController = FloorEditorController();
    editorController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    editorController.removeListener(() {});
    editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактор этажа')),

      body: Listener(
        onPointerDown: (event) {
          editorController.startDraw(Vec2(event.localPosition.dx, event.localPosition.dy));
        },
        onPointerMove: (event) {
          editorController.updateDraw(Vec2(event.localPosition.dx, event.localPosition.dy));
        },
        onPointerUp: (event) {
          editorController.endDraw();
        },

        child: CustomPaint(
          painter: WallPainter(editorController.walls, preview: editorController.previewWalls),
          child: Container(),
        ),
      ),
    );
  }
}
