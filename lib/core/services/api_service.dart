import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiService {
  // === PRIVATE CONSTRUCTOR (SINGLETON PATTERN) ===
  ApiService._internal();

  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  // === BASE URL ===
  String get baseUrl => apiBaseUrl;

  // === HEADERS DEFAULT ===
  Map<String, String> _getHeaders({String? token}) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> _getHeadersMultipart({String? token}) {
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // === HANDLE ERROR RESPONSE ===
  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final body = json.decode(response.body);
      return {'statusCode': response.statusCode, 'data': body, 'error': null};
    } catch (e) {
      return {
        'statusCode': response.statusCode,
        'data': null,
        'error': 'Error parsing response: $e',
      };
    }
  }

  // ========== GET REQUEST ==========
  Future<Map<String, dynamic>> get(String endpoint, {String? token}) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .get(url, headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 0, 'data': null, 'error': 'Network error: $e'};
    }
  }

  // ========== POST REQUEST ==========
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .post(
            url,
            headers: _getHeaders(token: token),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 0, 'data': null, 'error': 'Network error: $e'};
    }
  }

  // ========== PUT REQUEST ==========
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .put(
            url,
            headers: _getHeaders(token: token),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 0, 'data': null, 'error': 'Network error: $e'};
    }
  }

  // ========== DELETE REQUEST ==========
  Future<Map<String, dynamic>> delete(String endpoint, {String? token}) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .delete(url, headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 0, 'data': null, 'error': 'Network error: $e'};
    }
  }

  // ========== MULTIPART REQUEST (Untuk Upload File) ==========
  Future<Map<String, dynamic>> multipart(
    String endpoint, {
    required String method, // 'POST' atau 'PUT'
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
    String? token,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest(method, url);

      // Tambah headers
      request.headers.addAll(_getHeadersMultipart(token: token));

      // Tambah fields
      request.fields.addAll(fields);

      // Tambah files
      request.files.addAll(files);

      final streamResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamResponse);

      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 0, 'data': null, 'error': 'Network error: $e'};
    }
  }
}

// === INSTANCE GLOBAL (OPTIONAL) ===
final apiService = ApiService();
