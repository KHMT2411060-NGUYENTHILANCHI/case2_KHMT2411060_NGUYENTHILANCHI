import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_notification.dart';
import 'auth_service.dart';

class NotificationService {
  static final String _url = '${AuthService.baseUrl}/notifications';

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

  // GET /api/notifications
  Future<List<AppNotification>> getNotifications() async {
    final response = await http.get(
      Uri.parse(_url),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'Không thể tải thông báo');
    }
    final List data = jsonDecode(response.body) as List;
    return data
        .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // GET /api/notifications/unread-count
  Future<int> getUnreadCount() async {
    final response = await http.get(
      Uri.parse('$_url/unread-count'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'Không thể tải số thông báo');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['count'] as num?)?.toInt() ?? 0;
  }

  // PATCH /api/notifications/:id/read
  Future<void> markRead(String id) async {
    final response = await http.patch(
      Uri.parse('$_url/$id/read'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'Không thể đánh dấu đã đọc');
    }
  }

  // PATCH /api/notifications/read-all
  Future<void> markAllRead() async {
    final response = await http.patch(
      Uri.parse('$_url/read-all'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw _error(response, 'Không thể đánh dấu tất cả đã đọc');
    }
  }
}