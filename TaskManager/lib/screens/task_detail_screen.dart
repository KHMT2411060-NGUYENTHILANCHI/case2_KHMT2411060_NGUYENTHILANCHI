import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/task_api_service.dart';
import 'assign_task_screen.dart';
import 'login_screen.dart';
import 'share_task_screen.dart';
import 'task_edit_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _taskService = TaskApiService();

  Task? _task;
  List<TaskShare> _shares = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  static const _statusLabels = {
    'todo': 'Chưa thực hiện',
    'in_progress': 'Đang thực hiện',
    'completed': 'Đã hoàn thành',
  };

  static const _priorityLabels = {
    'low': 'Thấp',
    'medium': 'Trung bình',
    'high': 'Cao',
  };

  static const _roleLabels = {
    'owner': 'Bạn là người tạo',
    'editor': 'Bạn là người chỉnh sửa',
    'assignee': 'Bạn được giao việc này',
    'viewer': 'Bạn chỉ được xem',
  };

  static const _permissionLabels = {
    'viewer': 'Chỉ xem',
    'editor': 'Chỉnh sửa',
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
      final task = await _taskService.getTask(widget.taskId);

      // Danh sách chia sẻ: nếu lỗi thì bỏ qua, không làm hỏng cả màn hình
      List<TaskShare> shares = [];
      try {
        shares = await _taskService.getShares(widget.taskId);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _task = task;
        _shares = shares;
      });
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

  Future<void> _handleError(Object e) async {
    if (!mounted) return;
    if (e is ApiException) {
      if (e.statusCode == 401) {
        await _goToLogin();
        return;
      }
      _showMessage(e.message);
    } else {
      _showMessage('Không thể kết nối đến máy chủ');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ----- Đổi trạng thái -----
  Future<void> _changeStatus(String status) async {
    if (_task == null || status == _task!.status || _busy) return;

    setState(() => _busy = true);
    try {
      final updated = await _taskService.updateStatus(_task!.id, status);
      if (!mounted) return;
      setState(() => _task = updated);
      _showMessage('Đã cập nhật trạng thái');
    } catch (e) {
      await _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----- Sửa -----
  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskEditScreen(task: _task!)),
    );
    if (updated == true) {
      await _load();
      _showMessage('Đã cập nhật công việc');
    }
  }

  // ----- Giao việc -----
  Future<void> _openAssign() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AssignTaskScreen(task: _task!)),
    );
    if (changed == true) await _load();
  }

  // ----- Chia sẻ -----
  Future<void> _openShare() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ShareTaskScreen(task: _task!)),
    );
    if (changed == true) await _load();
  }

  // ----- Xóa -----
  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc'),
        content: Text('Bạn có chắc muốn xóa "${_task!.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _taskService.deleteTask(_task!.id);
      if (!mounted) return;
      Navigator.of(context).pop(); // danh sách sẽ tự tải lại
    } catch (e) {
      await _handleError(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------
  String _fmt(DateTime? d) {
    if (d == null) return 'Chưa đặt';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  String _sharedText() {
    if (_shares.isEmpty) return 'Chưa chia sẻ cho ai';
    return _shares
        .map((s) =>
    '${s.user?.fullName ?? 'Không rõ'} (${_permissionLabels[s.permission] ?? s.permission})')
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: [
          if (task != null && task.canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Sửa',
              onPressed: _busy ? null : _edit,
            ),
          if (task != null && task.canDelete)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Xóa',
              onPressed: _busy ? null : _delete,
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

    if (_error != null || _task == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(_error ?? 'Không tìm thấy công việc'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    final task = _task!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              task.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                decoration:
                task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              task.description.isEmpty ? 'Không có mô tả' : task.description,
              style: TextStyle(
                color: task.description.isEmpty ? Colors.grey : null,
              ),
            ),
            const SizedBox(height: 16),

            // Mức ưu tiên và vai trò
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                      'Ưu tiên: ${_priorityLabels[task.priority] ?? task.priority}'),
                  side: BorderSide(color: _priorityColor(task.priority)),
                  labelStyle: TextStyle(color: _priorityColor(task.priority)),
                ),
                if (task.isOverdue)
                  const Chip(
                    label: Text('Quá hạn'),
                    labelStyle: TextStyle(color: Colors.red),
                    side: BorderSide(color: Colors.red),
                  ),
                if (task.myRole != null)
                  Chip(
                    avatar: const Icon(Icons.badge, size: 18),
                    label: Text(_roleLabels[task.myRole] ?? task.myRole!),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Đổi trạng thái
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trạng thái',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statusLabels.entries.map((e) {
                        return ChoiceChip(
                          label: Text(e.value),
                          selected: task.status == e.key,
                          selectedColor:
                          _statusColor(e.key).withValues(alpha: 0.25),
                          onSelected: (_busy || !task.canChangeStatus)
                              ? null
                              : (_) => _changeStatus(e.key),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Thông tin chi tiết
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _infoRow(Icons.person, 'Người tạo',
                        task.createdBy?.fullName ?? 'Không rõ'),
                    _infoRow(Icons.star, 'Người phụ trách',
                        task.primaryAssignee?.fullName ?? 'Chưa chỉ định'),
                    _infoRow(
                      Icons.group,
                      'Người được giao',
                      task.assignees.isEmpty
                          ? 'Chưa giao cho ai'
                          : task.assignees.map((u) => u.fullName).join(', '),
                    ),
                    _infoRow(Icons.share, 'Người được chia sẻ', _sharedText()),
                    _infoRow(Icons.event_available, 'Ngày bắt đầu',
                        _fmt(task.startDate)),
                    _infoRow(Icons.event, 'Hạn hoàn thành', _fmt(task.dueDate),
                        valueColor: task.isOverdue ? Colors.red : null),
                    _infoRow(Icons.schedule, 'Ngày tạo', _fmt(task.createdAt)),
                  ],
                ),
              ),
            ),

            // Nút giao việc và chia sẻ (chỉ người tạo)
            if (task.canManage) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _openAssign,
                      icon: const Icon(Icons.assignment_ind),
                      label: const Text('Giao việc'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _openShare,
                      icon: const Icon(Icons.share),
                      label: const Text('Chia sẻ'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (!task.canEdit) ...[
              const SizedBox(height: 12),
              Text(
                task.canChangeStatus
                    ? 'Bạn chỉ được đổi trạng thái, không được sửa hoặc xóa công việc này.'
                    : 'Bạn chỉ có quyền xem công việc này.',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: Colors.grey[700])),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}