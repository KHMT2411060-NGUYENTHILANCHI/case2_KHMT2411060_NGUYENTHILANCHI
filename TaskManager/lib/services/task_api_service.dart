import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';
import 'auth_service.dart';

class TaskApiService {
  // Dùng chung địa chỉ với AuthService (Chrome: localhost, Android: 10.0.2.2)
  static final String _tasksUrl = '${AuthService.baseUrl}/tasks';

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

  // Lấy thông báo lỗi từ response của server
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

  // GET /api/tasks?scope=&status=&priority=&q=&sortBy=&order=
  Future<List<Task>> getTasks({
    String? scope, // created | assigned (null = tất cả)
    String? status,
    String? priority,
    String? q,
    String sortBy = 'createdAt', // createdAt | dueDate | priority
    String order = 'desc', // asc | desc
  }) async {
    final params = <String, String>{
      if (scope != null) 'scope': scope,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      'sortBy': sortBy,
      'order': order,
    };

    final response = await http.get(
      Uri.parse(_tasksUrl).replace(queryParameters: params),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw _error(response, 'Không thể tải danh sách công việc');
    }

    final List data = jsonDecode(response.body) as List;
    return data
        .map((json) => Task.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // POST /api/tasks
  Future<Task> createTask({
    required String title,
    String description = '',
    DateTime? startDate,
    DateTime? dueDate,
    String priority = 'medium',
    String status = 'todo',
  }) async {
    final response = await http.post(
      Uri.parse(_tasksUrl),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'description': description,
        if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
        if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
        'priority': priority,
        'status': status,
      }),
    );

    if (response.statusCode != 201) {
      throw _error(response, 'Không thể tạo công việc');
    }

    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}