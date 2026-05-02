import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8001/api',
  );

  final http.Client _client;
  String? accessToken;
  String? currentUserId;

  Future<List<dynamic>> getList(String path) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        response.body.isEmpty ? 'Không tải được dữ liệu' : response.body,
      );
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        response.body.isEmpty ? 'Thao tác thất bại' : response.body,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

final apiClient = ApiClient();
