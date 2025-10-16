import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_base.dart';

class CalcApi {
  static Future<Map<String, dynamic>> calc(Map<String, dynamic> payload) async {
    final uri = Uri.parse('${apiBase()}/calc');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload));
    if (res.statusCode != 200) {
      throw Exception('calc ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}