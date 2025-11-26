import 'package:flutter/material.dart';
import '../utils/log.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  String _content = "Loading...";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await readLogs();
    setState(() => _content = text);
  }

  Future<void> _clear() async {
    await clearLogs();
    setState(() => _content = "");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clear,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Text(
          _content.isEmpty ? "No logs" : _content,
          style: const TextStyle(fontFamily: "monospace"),
        ),
      ),
    );
  }
}
