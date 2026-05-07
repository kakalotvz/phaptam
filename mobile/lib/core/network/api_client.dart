import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8001/api',
  );

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'phaptam_access_token';
  static const _userIdKey = 'phaptam_user_id';
  static const _requestTimeout = Duration(seconds: 15);

  final http.Client _client;
  String? accessToken;
  String? currentUserId;

  Future<void> restoreSession() async {
    accessToken = await _storage.read(key: _tokenKey);
    currentUserId = await _storage.read(key: _userIdKey);
  }

  Future<void> saveSession({
    required String? token,
    required String? userId,
  }) async {
    accessToken = token;
    currentUserId = userId;
    if (token == null || token.isEmpty) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
    if (userId == null || userId.isEmpty) {
      await _storage.delete(key: _userIdKey);
    } else {
      await _storage.write(key: _userIdKey, value: userId);
    }
  }

  Future<void> clearSession() => saveSession(token: null, userId: null);

  Future<List<dynamic>> getList(String path) async {
    final response = await _send(
      () => _client.get(_uri(path), headers: _headers),
      fallbackMessage: 'Không tải được dữ liệu',
    );
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _send(
      () => _client.get(
        _uri(path, queryParameters: queryParameters),
        headers: _headers,
      ),
      fallbackMessage: 'Không tải được dữ liệu',
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      () => _client.post(_uri(path), headers: _headers, body: jsonEncode(body)),
      fallbackMessage: 'Thao tác thất bại',
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      () =>
          _client.patch(_uri(path), headers: _headers, body: jsonEncode(body)),
      fallbackMessage: 'Thao tác thất bại',
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> delete(String path) async {
    await _send(
      () => _client.delete(_uri(path), headers: _headers),
      fallbackMessage: 'Thao tác thất bại',
    );
  }

  Uri _uri(String path, {Map<String, dynamic>? queryParameters}) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        for (final entry in queryParameters.entries)
          entry.key: '${entry.value}',
      },
    );
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required String fallbackMessage,
  }) async {
    try {
      final response = await request().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          response.body.isEmpty ? fallbackMessage : response.body,
        );
      }
      return response;
    } on TimeoutException {
      throw Exception(
        'Kết nối tới máy chủ quá lâu. Kiểm tra lại API_BASE_URL hoặc mạng của thiết bị.',
      );
    }
  }
}

final apiClient = ApiClient();
