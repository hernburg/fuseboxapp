// lib/models/project.dart
import 'dart:convert';

class Project {
  final String id;
  String title;
  Map<String, dynamic> payload;

  DateTime? createdAt;
  DateTime? updatedAt;

  Project({
    required this.id,
    required this.title,
    Map<String, dynamic>? payload,
    this.createdAt,
    this.updatedAt,
  }) : payload = payload ?? <String, dynamic>{};

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      payload: (json['payload'] is Map<String, dynamic>)
          ? (json['payload'] as Map<String, dynamic>)
          : (json['payload'] is String && (json['payload'] as String).isNotEmpty)
              ? (jsonDecode(json['payload'] as String) as Map<String, dynamic>)
              : <String, dynamic>{},
      createdAt: _parseDateSafe(json['createdAt']),
      updatedAt: _parseDateSafe(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'payload': payload,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Project copyWith({
    String? id,
    String? title,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      payload: payload ?? Map<String, dynamic>.from(this.payload),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Обновляет updatedAt (и createdAt, если её ещё нет)
  void touch() {
    final now = DateTime.now();
    createdAt ??= now;
    updatedAt = now;
  }

  static DateTime? _parseDateSafe(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) {
      if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String && v.isNotEmpty) {
      try { return DateTime.parse(v); } catch (_) {}
    }
    return null;
  }
}