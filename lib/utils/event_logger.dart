import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class EventLogger {
  static final EventLogger _i = EventLogger._();
  factory EventLogger() => _i;

  File? _file;
  late final StreamController<List<String>> _streamController;
  final List<String> _buffer = <String>[];
  static const int _bufferLimit = 50;

  EventLogger._() {
    _streamController = StreamController<List<String>>.broadcast(
      onListen: () {
        if (_buffer.isNotEmpty) {
          _streamController.add(List.unmodifiable(_buffer));
        }
      },
    );
  }

  Stream<List<String>> get stream => _streamController.stream;

  Future<File> _logFile() async {
    if (_file != null) return _file!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/editor_log.txt');
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      _file = file;
      debugPrint('[EventLogger] using ${file.path}');
      return file;
    } catch (e, st) {
      debugPrint('[EventLogger] failed to resolve log file: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> log(String msg) async {
    final entry = '${DateTime.now().toIso8601String()}  $msg';
    _appendToBuffer(entry);

    try {
      final f = await _logFile();
      await f.writeAsString('$entry\n', mode: FileMode.append, flush: true);
      debugPrint('[EventLogger] $msg');
    } catch (e, st) {
      debugPrint('[EventLogger] write failed: $e');
      debugPrint('$st');
    }
  }

  void _appendToBuffer(String entry) {
    _buffer.add(entry);
    if (_buffer.length > _bufferLimit) {
      _buffer.removeAt(0);
    }
    if (!_streamController.isClosed) {
      _streamController.add(List.unmodifiable(_buffer));
    }
  }

  Future<String> readAll() async {
    final f = await _logFile();
    if (!await f.exists()) return "";
    return await f.readAsString();
  }

  Future<void> clear() async {
    final f = await _logFile();
    if (await f.exists()) await f.writeAsString("");
  }
}

void logMsg(String msg) {
  final file = File('/Users/hernburg/Downloads/logs/builder.log');
  file.writeAsStringSync(
    '${DateTime.now().toIso8601String()}  $msg\n',
    mode: FileMode.append,
  );
}
