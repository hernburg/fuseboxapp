import 'package:uuid/uuid.dart';
import '../models/project.dart';

class MemRepo {
  static final MemRepo _i = MemRepo._();
  MemRepo._();
  factory MemRepo() => _i;

  final List<Project> _items = [];

  /// Список проектов, новые сверху
  List<Project> all() {
    final copy = [..._items];
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(copy);
  }

  Project create({String title = 'Новый проект'}) {
    final p = Project(
      id: const Uuid().v4(),
      title: title,
      payload: {
        "settings": {"phases": 1, "mainBreakerA": 63, "railWidthModules": 12, "voltageStd": 220},
        "devices": {
          "voltageRelay": true, "spdClass2": false, "afdd": false,
          "contactor": false, "meter": false, "dinSocket": false,
          "fireRCD": true, "nonDisconnectable": false
        },
        "grouping": {"perGroup": {"sockets": 2, "lights": 2}, "perFloorOverride": false, "floorRCD": false},
        "floors": [
          {
            "title": "Этаж 1",
            "rooms": [
              {
                "title": "Помещение 1",
                "sockets": 2,
                "lights": 1,
                "wet": false,
                "powerW": {"sockets": 300, "lights": 100}
              }
            ]
          }
        ]
      },
    );
    _items.insert(0, p);
    return p;
  }

  void upsert(Project p) {
    p.touch();

    // где сортируешь проекты:
   copy.sort((a, b) {
   final au = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
   final bu = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
   return bu.compareTo(au);
   });
  }

  void delete(String id) => _items.removeWhere((e) => e.id == id);

  Project? byId(String id) {
    for (final e in _items) {
      if (e.id == id) return e;
    }
    return null;
  }
}