import 'package:flutter/material.dart';
import 'floor_editor.dart';

class FloorEditorScreen extends StatelessWidget {
  const FloorEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Delegate to FloorEditor which contains the AppBar with Undo/Redo/Clear
    // and the InteractiveViewer for zoom/pan.
    return const FloorEditor();
  }
}
