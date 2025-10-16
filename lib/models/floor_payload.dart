// lib/models/floor_payload.dart
class FloorsData {
  final List<FloorItem> floors;

  FloorsData({required this.floors});

  Map<String, dynamic> toMap() => {
        'floors': floors.map((e) => e.toMap()).toList(),
      };

  static FloorsData fromProjectPayload(Map<String, dynamic> payload) {
    final list = (payload['floors'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return FloorsData(
      floors: list.map(FloorItem.fromMap).toList(),
    );
  }
}

class FloorItem {
  final String id;
  String title;
  int roomWmm;
  int roomHmm;

  /// тут можешь сохранять данные из RoutePlannerScreen
  Map<String, dynamic> routeData;

  FloorItem({
    required this.id,
    required this.title,
    this.roomWmm = 5000,
    this.roomHmm = 4000,
    Map<String, dynamic>? routeData,
  }) : routeData = routeData ?? {};

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'roomWmm': roomWmm,
        'roomHmm': roomHmm,
        'routeData': routeData,
      };

  static FloorItem fromMap(Map<String, dynamic> m) => FloorItem(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? 'Этаж',
        roomWmm: (m['roomWmm'] as num?)?.toInt() ?? 5000,
        roomHmm: (m['roomHmm'] as num?)?.toInt() ?? 4000,
        routeData: (m['routeData'] as Map?)?.cast<String, dynamic>() ?? {},
      );
}