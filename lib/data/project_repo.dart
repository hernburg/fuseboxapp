// lib/data/project_repo.dart
import 'dart:convert';
import 'package:collection/collection.dart';
import '../models/project.dart';

class ProjectRepo {
  // это пример in-memory/файлового хранилища — подстрой под свою реализацию
  final List<Project> _items = [];

  List<Project> all() => List.unmodifiable(_items..sort(
    (a,b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    },
  ));

  void upsert(Project p) {
    final i = _items.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      _items[i] = p..updatedAt = DateTime.now();
    } else {
      p.createdAt ??= DateTime.now();
      p.updatedAt = DateTime.now();
      _items.add(p);
    }
  }

  Project? byId(String id) => _items.firstWhereOrNull((e) => e.id == id);

  // примеры (если где-то читаешь/пишешь json)
  List<Map<String, dynamic>> dumpJson() => _items.map((e) => e.toJson()).toList();

  void restoreJson(List<dynamic> raw) {
    _items
      ..clear()
      ..addAll(raw
          .whereType<Map<String, dynamic>>()
          .map(Project.fromJson));
  }
}