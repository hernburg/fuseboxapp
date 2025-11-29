// lib/utils/log.dart
//
// Универсальный логгер для FuseboxApp
// Пишет логи в:
//   /Users/hernburg/Downloads/logs/*.log
//
// Работает на iOS Simulator и macOS.
// На реальном устройстве путь будет другой (Documents)

import 'dart:io';

/// Имя лог-файла по умолчанию
const String _defaultLogName = 'app.log';

/// Внутренний метод: вычисляет корректный путь к файлу
Future<String> _ensureLogPath([String fileName = _defaultLogName]) async {
  // Если приложение работает на симуляторе/маке — пишем в твою папку
  final customDir = Directory('/Users/hernburg/Downloads/logs');
  if (!customDir.existsSync()) {
    customDir.createSync(recursive: true);
  }
  return '${customDir.path}/$fileName';
}

/// Основной метод логирования
Future<void> logMsg(String tag, String msg, {String file = _defaultLogName}) async {
  final time = DateTime.now().toIso8601String();
  final line = "$time  [$tag] $msg\n";

  try {
    final path = await _ensureLogPath(file);
    final f = File(path);
    await f.writeAsString(line, mode: FileMode.append, flush: true);
  } catch (e) {
    // fallback — на всякий случай
    // ignore: avoid_print
    print('[LOG ERROR] $e');
  }
}

/// Чтение лог-файла
Future<String> readLogs({String file = _defaultLogName}) async {
  final path = await _ensureLogPath(file);
  final f = File(path);
  if (!f.existsSync()) return "";
  return f.readAsString();
}

/// Очистка
Future<void> clearLogs({String file = _defaultLogName}) async {
  final path = await _ensureLogPath(file);
  final f = File(path);
  if (f.existsSync()) {
    await f.writeAsString("");
  }
}
