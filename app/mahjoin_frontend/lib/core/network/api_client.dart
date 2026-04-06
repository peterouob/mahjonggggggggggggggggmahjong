import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/session.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://168.138.210.65:8080',
  );

  static Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    final userId = Session.instance.userId;
    if (userId != null) headers['X-User-ID'] = userId;
    return headers;
  }

  static Future<dynamic> get(String path, {Map<String, String>? params}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (params != null) uri = uri.replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final response =
        await http.post(uri, headers: _headers, body: jsonEncode(body));
    _checkStatus(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.delete(uri, headers: _headers);
    _checkStatus(response);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final response =
        await http.put(uri, headers: _headers, body: jsonEncode(body));
    _checkStatus(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final response =
        await http.patch(uri, headers: _headers, body: jsonEncode(body));
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  static void _checkStatus(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
