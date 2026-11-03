import 'dart:async';

import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/task_api_service.dart';
import 'login_screen.dart';

class AssignTaskScreen extends StatefulWidget {
  final Task task;

  const AssignTaskScreen({super.key, required this.task});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _service = TaskApiService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  late Task _task;
  List<UserSummary> _results = [];
  final Map<String, UserSummary> _selected = {};

  bool _searching = false;
  bool _busy = false;
  bool _changed = false; // có thay đổi thì báo màn hình chi tiết tải lại
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------- Hỗ trợ ----------
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleError(Object e) async {
    if (!mounted) return;
    if (e is ApiException) {
      if (e.statusCode == 401) {
        await AuthService().logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
        return;
      }
      _showMessage(e.message);
    } else {
      _showMessage('Không thể kết nối đến máy chủ');
    }
  }

  bool _isAssigned(String userId) =>
      _task.assignees.any((u) => u.id == userId);

  Future<void> _reloadTask() async {
    final fresh = await _service.getTask(_task.id);
    if (!mounted) return;
    setState(() => _task = fresh);
  }

  // ---------- Tìm người dùng ----------
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();

    if (q.length < 2) {
      setState(() {
        _results = [];
        _lastQuery = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final users = await _service.searchUsers(q);
      if (!mounted) return;
      setState(() {
        _results = users;
        _lastQuery = q;
      });
    } catch (e) {
      await _handleError(e);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _toggleSelect(UserSummary user) {
    setState(() {
      if (_selected.containsKey(user.id)) {
        _selected.remove(user.id);
      } else {
        _selected[user.id] = user;
      }
    });
  }

  // ---------- Giao việc ----------
  Future<void> _assign() async {
    if (_selected.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      await _service.addAssignees(
        _task.id,
        userIds: _selected.keys.toList(),
      );
      await _reloadTask();
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _changed = true;
      });
      _showMessage('Đã giao việc');
    } catch (e) {
      await _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPrimary(UserSummary user) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.setPrimaryAssignee(_task.id, user.id);
      await _reloadTask();
      if (mounted) setState(() => _changed = true);
      _showMessage('${user.fullName} là người phụ trách chính');
    } catch (e) {
      await _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(UserSummary user) async {
    if (_busy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy giao việc'),
        content: Text('Hủy giao việc cho ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hủy giao'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _service.removeAssignee(_task.id, user.id);
      await _reloadTask();
      if (mounted) setState(() => _changed = true);
      _showMessage('Đã hủy giao việc');
    } catch (e) {
      await _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Giao công việc')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _task.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCurrentAssignees(),
                const SizedBox(height: 16),
                _buildSearchSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentAssignees() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Người được giao (${_task.assignees.length})',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_task.assignees.isEmpty)
              const Text('Chưa giao cho ai',
                  style: TextStyle(color: Colors.grey))
            else
              ..._task.assignees.map((u) {
                final isPrimary = _task.primaryAssignee?.id == u.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(
                      u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(u.fullName),
                  subtitle: Text(
                    isPrimary ? '${u.email} • Phụ trách chính' : u.email,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: isPrimary
                            ? 'Người phụ trách chính'
                            : 'Đặt làm người phụ trách chính',
                        icon: Icon(
                          isPrimary ? Icons.star : Icons.star_border,
                          color: isPrimary ? Colors.amber : null,
                        ),
                        onPressed:
                        (isPrimary || _busy) ? null : () => _setPrimary(u),
                      ),
                      IconButton(
                        tooltip: 'Hủy giao việc',
                        icon: const Icon(Icons.person_remove,
                            color: Colors.red),
                        onPressed: _busy ? null : () => _remove(u),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Giao thêm cho người khác',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Nhập tên hoặc email (ít nhất 2 ký tự)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),

            // Những người đã chọn
            if (_selected.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _selected.values
                    .map((u) => InputChip(
                  label: Text(u.fullName),
                  onDeleted: () => _toggleSelect(u),
                ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Kết quả tìm kiếm
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_lastQuery.isNotEmpty && _results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Không tìm thấy người dùng phù hợp',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ..._results.map((u) {
                final assigned = _isAssigned(u.id);
                final selected = _selected.containsKey(u.id);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: assigned ? true : selected,
                  onChanged: assigned ? null : (_) => _toggleSelect(u),
                  title: Text(u.fullName),
                  subtitle: Text(
                    assigned ? '${u.email} • Đã được giao' : u.email,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }),

            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: (_selected.isEmpty || _busy) ? null : _assign,
                icon: _busy
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.assignment_ind),
                label: Text(_selected.isEmpty
                    ? 'Chọn người để giao việc'
                    : 'Giao việc cho ${_selected.length} người'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}