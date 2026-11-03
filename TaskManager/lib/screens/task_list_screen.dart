import 'dart:async';

import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/task_api_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _taskService = TaskApiService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _requestId = 0; // bỏ qua kết quả của request cũ

  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;

  // ----- Bộ lọc -----
  String? _scope; // null = tất cả | created | assigned
  String? _statusFilter;
  String? _priorityFilter;
  String _sortBy = 'createdAt';
  String _order = 'desc';

  bool get _hasFilter =>
      _scope != null ||
          _statusFilter != null ||
          _priorityFilter != null ||
          _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final myRequest = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tasks = await _taskService.getTasks(
        scope: _scope,
        status: _statusFilter,
        priority: _priorityFilter,
        q: _searchController.text,
        sortBy: _sortBy,
        order: _order,
      );
      if (!mounted || myRequest != _requestId) return;
      setState(() => _tasks = tasks);
    } on ApiException catch (e) {
      if (!mounted || myRequest != _requestId) return;
      if (e.statusCode == 401) {
        await AuthService().logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted || myRequest != _requestId) return;
      setState(() => _error = 'Không thể kết nối đến máy chủ');
    }

    if (mounted && myRequest == _requestId) {
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadTasks);
    setState(() {}); // cập nhật nút xóa ô tìm kiếm
  }

  void _clearFilters() {
    setState(() {
      _scope = null;
      _statusFilter = null;
      _priorityFilter = null;
      _searchController.clear();
    });
    _loadTasks();
  }

  Future<void> _openDetail(Task task) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
    );
    if (mounted) _loadTasks(); // tải lại sau khi sửa, xóa hoặc đổi trạng thái
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TaskCreateScreen()),
    );
    if (created == true) {
      await _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo công việc')),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _loadTasks,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Cá nhân',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Thêm công việc'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ô tìm kiếm
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm công việc theo tên...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                  _loadTasks();
                },
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),

          // Phạm vi: tất cả / tôi tạo / được giao
          Wrap(
            spacing: 8,
            children: [
              _scopeChip('Tất cả', null),
              _scopeChip('Tôi tạo', 'created'),
              _scopeChip('Được giao cho tôi', 'assigned'),
              _scopeChip('Được chia sẻ', 'shared'),
            ],
          ),
          const SizedBox(height: 8),

          // Lọc trạng thái, ưu tiên, sắp xếp
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _dropdown(
                label: 'Trạng thái',
                value: _statusFilter,
                items: const {
                  null: 'Tất cả',
                  'todo': 'Chưa thực hiện',
                  'in_progress': 'Đang thực hiện',
                  'completed': 'Đã hoàn thành',
                },
                onChanged: (v) {
                  setState(() => _statusFilter = v);
                  _loadTasks();
                },
              ),
              _dropdown(
                label: 'Ưu tiên',
                value: _priorityFilter,
                items: const {
                  null: 'Tất cả',
                  'high': 'Cao',
                  'medium': 'Trung bình',
                  'low': 'Thấp',
                },
                onChanged: (v) {
                  setState(() => _priorityFilter = v);
                  _loadTasks();
                },
              ),
              _dropdown(
                label: 'Sắp xếp theo',
                value: _sortBy,
                items: const {
                  'createdAt': 'Ngày tạo',
                  'dueDate': 'Hạn hoàn thành',
                  'priority': 'Mức ưu tiên',
                },
                onChanged: (v) {
                  setState(() => _sortBy = v ?? 'createdAt');
                  _loadTasks();
                },
              ),
              IconButton.outlined(
                tooltip: _order == 'desc' ? 'Giảm dần' : 'Tăng dần',
                icon: Icon(_order == 'desc'
                    ? Icons.arrow_downward
                    : Icons.arrow_upward),
                onPressed: () {
                  setState(() => _order = _order == 'desc' ? 'asc' : 'desc');
                  _loadTasks();
                },
              ),
              if (_hasFilter)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Xóa bộ lọc'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scopeChip(String label, String? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _scope == value,
      onSelected: (_) {
        setState(() => _scope = value);
        _loadTasks();
      },
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required Map<String?, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 175,
      child: DropdownButtonFormField<String?>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: items.entries
            .map((e) => DropdownMenuItem<String?>(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang tải dữ liệu...'),
          ],
        ),
      );
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
            ElevatedButton(
              onPressed: _loadTasks,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(_hasFilter
                  ? 'Không có công việc phù hợp với bộ lọc'
                  : 'Chưa có công việc nào'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openDetail(task),
            child: _TaskCard(task: task),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Thẻ hiển thị một công việc
// ---------------------------------------------------------------------
class _TaskCard extends StatelessWidget {
  final Task task;

  const _TaskCard({required this.task});

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String statusLabel(String s) {
    switch (s) {
      case 'in_progress':
        return 'Đang thực hiện';
      case 'completed':
        return 'Đã hoàn thành';
      default:
        return 'Chưa thực hiện';
    }
  }

  static Color statusColor(String s) {
    switch (s) {
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static String priorityLabel(String p) {
    switch (p) {
      case 'high':
        return 'Cao';
      case 'low':
        return 'Thấp';
      default:
        return 'Trung bình';
    }
  }

  static Color priorityColor(String p) {
    switch (p) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                decoration:
                task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Badge(
                  label: statusLabel(task.status),
                  color: statusColor(task.status),
                ),
                _Badge(
                  label: 'Ưu tiên: ${priorityLabel(task.priority)}',
                  color: priorityColor(task.priority),
                ),
              ],
            ),
            if (task.dueDate != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 16,
                    color: task.isOverdue ? Colors.red : Colors.grey[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Hạn: ${_formatDate(task.dueDate!)}'
                        '${task.isOverdue ? ' (quá hạn)' : ''}',
                    style: TextStyle(
                      color: task.isOverdue ? Colors.red : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}