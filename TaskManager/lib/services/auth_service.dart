import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Lỗi trả về từ API (sai mật khẩu, token hết hạn, ...)
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthService {
  // Chrome (web) dùng localhost, Android Emulator dùng 10.0.2.2
  static final String baseUrl =
  kIsWeb ? 'http://localhost:3000/api' : 'http://10.0.2.2:3000/api';

  static const String _tokenKey = 'auth_token';

  // ---------- Token ----------
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ---------- Đăng ký ----------
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'password': password,
      }),
    );
    _checkResponse(response);
  }

  // ---------- Đăng nhập ----------
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _checkResponse(response);
    await _saveToken(data['token'] as String);
  }

  // ---------- Lấy thông tin người dùng hiện tại ----------
  Future<Map<String, dynamic>> getMe() async {
    final token = await _requireToken();

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _extractUser(_checkResponse(response));
  }

  // ---------- Cập nhật thông tin cá nhân ----------
  Future<Map<String, dynamic>> updateMe({String? fullName}) async {
    final token = await _requireToken();

    final response = await http.put(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({if (fullName != null) 'fullName': fullName}),
    );
    return _extractUser(_checkResponse(response));
  }

  // ---------- Đổi mật khẩu ----------
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await _requireToken();

    final response = await http.put(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    _checkResponse(response);
  }

  // ---------- Hàm dùng chung ----------
  Future<String> _requireToken() async {
    final token = await getToken();
    if (token == null) {
      throw ApiException('Chưa đăng nhập', statusCode: 401);
    }
    return token;
  }

  // Backend có thể trả {user: {...}} hoặc trả thẳng {...}
  Map<String, dynamic> _extractUser(Map<String, dynamic> data) {
    return (data['user'] ?? data) as Map<String, dynamic>;
  }

  Map<String, dynamic> _checkResponse(http.Response response) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw ApiException(
      (data['message'] ?? 'Đã có lỗi xảy ra').toString(),
      statusCode: response.statusCode,
    );
  }
}