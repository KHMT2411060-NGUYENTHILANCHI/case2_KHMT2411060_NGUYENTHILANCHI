import 'package:flutter/material.dart';

import '../models/statistics.dart';
import '../services/auth_service.dart';
import '../services/statistics_service.dart';
import 'login_screen.dart';

class ActivityScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const ActivityScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _service = StatisticsService();

  List<TaskActivity> _items = [];
  bool _loading = true;
  String? _error;

  static const _statusLabels = {
    'todo': 'Chưa thực hiện',
    'in_progress': 'Đang thực hiện',
    'completed': 'Đã hoàn thành',
  };

  static const _fieldLabels = {
    'title': 'tên',
    'description': 'mô tả',
    'startDate': 'ngày bắt đầu',
    'dueDate': 'hạn hoàn thành',
    'priority': 'mức ưu tiên',
  };

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
      final items = await _service.getActivities(widget.taskId);
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService().logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể kết nối đến máy chủ');
    }

    if (mounted) setState(() => _loading = false);
  }

  // Câu mô tả một hoạt động
  String _describe(TaskActivity a) {
    final d = a.details;
    String names(dynamic v) =>
        v is List ? v.map((e) => e.toString()).join(', ') : '';

    switch (a.action) {
      case 'created':
        return 'đã tạo công việc';
      case 'updated':
        final fields = d['fields'] is List
            ? (d['fields'] as List)
            .map((e) => _fieldLabels[e.toString()] ?? e.toString())
            .join(', ')
            : '';
        return fields.isEmpty
            ? 'đã cập nhật công việc'
            : 'đã cập nhật $fields';
      case 'status_changed':
        final from = _statusLabels[d['from']] ?? d['from'];
        final to = _statusLabels[d['to']] ?? d['to'];
        return 'đã đổi trạng thái từ "$from" sang "$to"';
      case 'assigned':
        return 'đã giao việc cho ${names(d['users'])}';
      case 'unassigned':
        return 'đã hủy giao việc của ${d['user'] ?? ''}';
      case 'primary_changed':
        return 'đã đặt ${d['user'] ?? ''} làm người phụ trách chính';
      case 'shared':
        final perm = d['permission'] == 'editor' ? 'chỉnh sửa' : 'chỉ xem';
        return 'đã chia sẻ cho ${names(d['users'])} (quyền $perm)';
      case 'share_updated':
        final perm = d['permission'] == 'editor' ? 'chỉnh sửa' : 'chỉ xem';
        return 'đã đổi quyền của ${d['user'] ?? ''} thành $perm';
      case 'share_revoked':
        return 'đã thu hồi quyền của ${d['user'] ?? ''}';
      default:
        return a.action;
    }
  }

  IconData _iconFor(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle;
      case 'updated':
        return Icons.edit;
      case 'status_changed':
        return Icons.sync_alt;
      case 'assigned':
      case 'unassigned':
      case 'primary_changed':
        return Icons.assignment_ind;
      case 'shared':
      case 'share_updated':
      case 'share_revoked':
        return Icons.share;
      default:
        return Icons.history;
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
        title: const Text('Lịch sử hoạt động'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _load,
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.taskTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                child: Text('Chưa có hoạt động nào được ghi lại'),
              )
                  : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final a = _items[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(_iconFor(a.action), size: 20),
                      ),
                      title: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: a.userName.isEmpty
                                  ? 'Ai đó'
                                  : a.userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: ' ${_describe(a)}'),
                          ],
                        ),
                      ),
                      subtitle: Text(_fmt(a.createdAt)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}