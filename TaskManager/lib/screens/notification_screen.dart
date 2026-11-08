import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'task_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _service = NotificationService();

  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  bool get _hasUnread => _items.any((n) => !n.isRead);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.getNotifications();
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _goToLogin();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể kết nối đến máy chủ');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _goToLogin() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ----- Bấm vào thông báo: đánh dấu đã đọc rồi mở công việc -----
  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      setState(() {
        final i = _items.indexWhere((x) => x.id == n.id);
        if (i != -1) _items[i] = n.copyWith(isRead: true);
      });
      try {
        await _service.markRead(n.id);
      } catch (_) {
        // Lỗi đánh dấu đã đọc không chặn việc mở công việc
      }
    }

    if (n.taskId == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: n.taskId!)),
    );
  }

  // ----- Đánh dấu tất cả đã đọc -----
  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      if (!mounted) return;
      setState(() {
        _items = _items.map((n) => n.copyWith(isRead: true)).toList();
      });
      _showMessage('Đã đánh dấu tất cả là đã đọc');
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Không thể kết nối đến máy chủ');
    }
  }

  // ---------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------
  IconData _iconFor(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind;
      case 'task_shared':
        return Icons.share;
      case 'due_date_changed':
        return Icons.event;
      case 'task_completed':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'task_assigned':
        return Colors.blue;
      case 'task_shared':
        return Colors.purple;
      case 'due_date_changed':
        return Colors.orange;
      case 'task_completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: _hasUnread ? _markAllRead : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Center(child: Text('Chưa có thông báo nào')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = _items[index];
              final color = _colorFor(n.type);

              return ListTile(
                tileColor: n.isRead
                    ? null
                    : Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.35),
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(_iconFor(n.type), color: color),
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(n.message),
                    const SizedBox(height: 4),
                    Text(
                      _fmt(n.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: n.isRead
                    ? null
                    : const Icon(Icons.circle, size: 10, color: Colors.blue),
                isThreeLine: true,
                onTap: () => _open(n),
              );
            },
          ),
        ),
      ),
    );
  }
}