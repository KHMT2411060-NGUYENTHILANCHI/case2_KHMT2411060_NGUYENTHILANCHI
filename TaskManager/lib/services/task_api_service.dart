import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';
import 'auth_service.dart';

class TaskApiService {
  // Dùng chung địa chỉ với AuthService (Chrome: localhost, Android: 10.0.2.2)
  static final String _tasksUrl = '${AuthService.baseUrl}/tasks';
  static final String _usersUrl = '${AuthService.baseUrl}/users';

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

  // =====================================================================
  // Công việc
  // =====================================================================

  // GET /api/tasks?scope=&status=&priority=&q=&assigneeId=&sortBy=&order=
  Future<List<Task>> getTasks({
    String? scope, // created | assigned | shared (null = tất cả)
    String? status,
    String? priority,
    String? q,
    String? assigneeId,
    String sortBy = 'createdAt', // createdAt | dueDate | priority
    String order = 'desc', // asc | desc
  }) async {
    final params = <String, String>{
      if (scope != null) 'scope': scope,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (assigneeId != null) 'assigneeId': assigneeId,
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

  // GET /api/tasks/:id
  Future<Task> getTask(String id) async {
    final response = await http.get(
      Uri.parse('$_tasksUrl/$id'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw _error(response, 'Không thể tải công việc');
    }
    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
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

  // PUT /api/tasks/:id  (người tạo hoặc editor)
  Future<Task> updateTask(
      String id, {
        required String title,
        String description = '',
        DateTime? startDate,
        DateTime? dueDate,
        required String priority,
        required String status,
      }) async {
    final response = await http.put(
      Uri.parse('$_tasksUrl/$id'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'description': description,
        'startDate': startDate?.toUtc().toIso8601String(),
        'dueDate': dueDate?.toUtc().toIso8601String(),
        'priority': priority,
        'status': status,
      }),
    );

    if (response.statusCode != 200) {
      throw _error(response, 'Không thể cập nhật công việc');
    }
    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // PATCH /api/tasks/:id/status
  Future<Task> updateStatus(String id, String status) async {
    final response = await http.patch(
      Uri.parse('$_tasksUrl/$id/status'),
      headers: await _headers(),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw _error(response, 'Không thể cập nhật trạng thái');
    }
    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // DELETE /api/tasks/:id  (chỉ người tạo)
  Future<void> deleteTask(String id) async {
    final response = await http.delete(
      Uri.parse('$_tasksUrl/$id'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw _error(response, 'Không thể xóa công việc');
    }
  }

  // =====================================================================
  // Tìm người dùng
  // =====================================================================

  // GET /api/users/search?q=
  Future<List<UserSummary>> searchUsers(String q) async {
    final response = await http.get(
      Uri.parse('$_usersUrl/search').replace(queryParameters: {'q': q}),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw _error(response, 'Không thể tìm người dùng');
    }
    final List data = jsonDecode(response.body) as List;
    return data
        .map((json) => UserSummary.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // =====================================================================
  // Giao việc
  // =====================================================================

  // POST /api/tasks/:id/assignees
  Future<void> addAssignees(
      String taskId, {
        required List<String> userIds,
        String? primaryAssigneeId,
      }) async {
    final response = await http.post(
      Uri.parse('$_tasksUrl/$taskId/assignees'),
      headers: await _headers(),
      body: jsonEncode({
        'userIds': userIds,
        if (primaryAssigneeId != null) 'primaryAssigneeId': primaryAssigneeId,
      }),
    );

    if (response.statusCode != 200) {
      throw _error(response, 'Không thể giao việc');
    }
  }

  // PATCH /api/tasks/:id/assignees/:userId  -> đặt người phụ trách chính
  Future<void> setPrimaryAssignee(String taskId, String userId) async {
    final response = await http.patch(
      Uri.parse('$_tasksUrl/$taskId/assignees/$userId'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw _error(response, 'Không thể đổi người phụ trách chính');
    }
  }

  // DELETE /api/tasks/:id/assignees/:userId  -> hủy giao việc
  Future<void> removeAssignee(String taskId, String userId) async {
    final response = await http.delete(
      Uri.parse('$_tasksUrl/$taskId/assignees/$userId'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw _error(response, 'Không thể hủy giao việc');
    }
  }

  // =====================================================================
  // Chia sẻ và phân quyền (dùng ở bước C3)
  // =====================================================================

  List<TaskShare> _parseShares(String body) {
    final List data = jsonDecode(body) as List;
    return data
        .map((json) => TaskShare.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // GET /api/tasks/:id/shares
  Future<List<TaskShare>> getShares(String taskId) async {
    final response = await http.get(
      Uri.parse('$_tasksUrl/$taskId/shares'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'Không thể tải danh sách chia sẻ');
    }
    return _parseShares(response.body);
  }

  // POST /api/tasks/:id/shares
  Future<List<TaskShare>> addShares(
      String taskId, {
        required List<String> userIds,
        required String permission, // viewer | editor
      }) async {
    final response = await http.post(
      Uri.parse('$_tasksUrl/$taskId/shares'),
      headers: await _headers(),
      body: jsonEncode({'userIds': userIds, 'permission': permission}),
    );
    if (response.statusCode != 201) {
      throw _error(response, 'Không thể chia sẻ công việc');
    }
    return _parseShares(response.body);
  }

  // PATCH /api/tasks/:id/shares/:shareId
  Future<List<TaskShare>> updateShare(
      String taskId,
      String shareId,
      String permission,
      ) async {
    final response = await http.patch(
      Uri.parse('$_tasksUrl/$taskId/shares/$shareId'),
      headers: await _headers(),
      body: jsonEncode({'permission': permission}),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'Không thể đổi quyền');
    }
    return _parseShares(response.body);
  }

  // DELETE /api/tasks/:id/shares/:shareId
  Future<List<TaskShare>> deleteShare(String taskId, String shareId) async {
    final response = await http.delete(
      Uri.parse('$_tasksUrl/$taskId/shares/$shareId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'Không thể thu hồi quyền');
    }
    return _parseShares(response.body);
  }
}