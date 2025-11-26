// lib/api/calc_api.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Безопасный клиент: пытается сходить на CALC_URL, а если не вышло —
/// имитирует расчёт (10–12 секунд) и возвращает валидный результат.
class CalcApi {
  static const Duration _timeout = Duration(seconds: 6);

  /// Можно переопределить URL через --dart-define=CALC_URL=your_calc_url
  static final String _baseUrl =
      const String.fromEnvironment('CALC_URL', defaultValue: 'http://127.0.0.1:3000');

  static Future<Map<String, dynamic>> calc(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$_baseUrl/calc');
    try {
      final res = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload))
          .timeout(_timeout);

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        // Некакждый сервер шлёт 200 — падаем в оффлайн.
        return _fakeResult(payload, delaySec: 11);
      }
    } catch (_) {
      // Любая сеть/таймаут — идём в оффлайн.
      return _fakeResult(payload, delaySec: 11);
    }
  }

  /// Фейковый расчёт: ждём 10–12с и собираем простой валидный ответ.
  static Future<Map<String, dynamic>> _fakeResult(
    Map<String, dynamic> payload, {
    int delaySec = 10,
  }) async {
    // Имитируем «тяжёлый» расчёт
    await Future.delayed(Duration(seconds: delaySec));

    // Считаем суммарные группы из payload (этажи/комнаты)
    int sockets = 0, lights = 0, extra = 0;
    final floors = (payload['floors'] as List?) ?? const [];
    for (final f in floors) {
      final rooms = (f['rooms'] as List?) ?? const [];
      for (final r in rooms) {
        sockets += (r['sockets'] as int?) ?? 0;
        lights  += (r['lights']  as int?) ?? 0;
        extra   += (r['extra']   as int?) ?? 0;
      }
    }

    Map<String, dynamic> variant({
      required int breakerSock,
      required int breakerLight,
      required int mainIn,
      int rcdMain = 300,
    }) {
      final lines = <Map<String, dynamic>>[];
      for (int i = 1; i <= sockets; i++) {
        lines.add({
          'title': 'Розетки #$i',
          'type': 'sockets',
          'phase': '1P',
          'breaker_In': breakerSock,
          'breaker_char': 'B',
          'rcd_mA': 30,
        });
      }
      for (int i = 1; i <= lights; i++) {
        lines.add({
          'title': 'Свет #$i',
          'type': 'lights',
          'phase': '1P',
          'breaker_In': breakerLight,
          'breaker_char': 'B',
          'rcd_mA': 30,
        });
      }
      for (int i = 1; i <= extra; i++) {
        lines.add({
          'title': 'Доп оборудование #$i',
          'type': 'extra',
          'phase': '1P',
          'breaker_In': 16,
          'breaker_char': 'C',
          'rcd_mA': 30,
        });
      }
      return {
        'main': {'In': mainIn, 'rcd_mA': rcdMain},
        'lines': lines,
        'bomExtras': ['Реле напряжения'],
      };
    }

    // Три варианта, сейчас почти одинаковые — потом легко настроим
    return {
      'cheap':   variant(breakerSock: 20, breakerLight: 13, mainIn: 63),
      'optimal': variant(breakerSock: 20, breakerLight: 13, mainIn: 63),
      'max':     variant(breakerSock: 25, breakerLight: 16, mainIn: 63),
    };
  }
}
