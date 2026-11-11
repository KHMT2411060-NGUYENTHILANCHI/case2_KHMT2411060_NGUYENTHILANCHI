import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/statistics.dart';
import 'auth_service.dart';

class StatisticsService {
  static final String _base = AuthService.baseUrl;

  final AuthService _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    if (token == null) {
      throw ApiException('Chưa đăng nhập', statusCode: 401);
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  ApiException _error(http.Response response, String fallback) {
    String message = fallback;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    return ApiException(message, statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>> _getMap(String path, String fallback) async {
    final response = await http.get(
      Uri.parse('$_base$path'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) throw _error(response, fallback);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // GET /api/statistics/tasks
  Future<TaskStats> getTaskStats() async =>
      TaskStats.fromJson(await _getMap('/statistics/tasks', 'Không thể tải thống kê'));

  // GET /api/statistics/assignments
  Future<AssignmentStats> getAssignmentStats() async => AssignmentStats.fromJson(
      await _getMap('/statistics/assignments', 'Không thể tải thống kê giao việc'));

  // GET /api/statistics/deadlines?days=7
  Future<DeadlineStats> getDeadlines({int days = 7}) async =>
      DeadlineStats.fromJson(await _getMap(
          '/statistics/deadlines?days=$days', 'Không thể tải thống kê hạn'));

  // GET /api/tasks/:id/activities
  Future<List<TaskActivity>> getActivities(String taskId) async {
    final response = await http.get(
      Uri.parse('$_base/tasks/$taskId/activities'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'Không thể tải lịch sử hoạt động');
    }
    final List data = jsonDecode(response.body) as List;
    return data
        .map((j) => TaskActivity.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}