import 'dart0:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://100.92.205.85:8000';

  static Future<Map<String, dynamic>> fetchHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/api/health'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de chargement de l\'état de santé');
    }
  }

  static Future<Map<String, dynamic>> fetchProxyStats() async {
    final response = await http.get(Uri.parse('$baseUrl/api/proxy/stats'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de chargement des données proxy');
    }
  }

  static Future<Map<String, dynamic>> fetchSystemStats() async {
    final response = await http.get(Uri.parse('$baseUrl/api/system/stats'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de chargement des données système');
    }
  }

  static Future<bool> reloadProxy() async {
    final response = await http.post(Uri.parse('$baseUrl/api/proxy/reload'));
    return response.statusCode == 200;
  }
}
