import 'package:flutter/material.dart';

import '../models/statistics.dart';
import '../services/auth_service.dart';
import '../services/statistics_service.dart';
import 'login_screen.dart';
import 'task_detail_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _service = StatisticsService();

  TaskStats _tasks = TaskStats();
  AssignmentStats _assign = AssignmentStats();
  DeadlineStats _deadlines = DeadlineStats();
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        _service.getTaskStats(),
        _service.getAssignmentStats(),
        _service.getDeadlines(days: 7),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0] as TaskStats;
        _assign = results[1] as AssignmentStats;
        _deadlines = results[2] as DeadlineStats;
      });
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

  Future<void> _openTask(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id)),
    );
    if (mounted) _load();
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Chưa đặt';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê'),
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

    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusCard(),
              const SizedBox(height: 12),
              _buildAssignmentCard(),
              const SizedBox(height: 12),
              _buildDeadlineCard(
                title: 'Đã quá hạn (${_deadlines.overdue.length})',
                color: Colors.red,
                icon: Icons.warning_amber_rounded,
                tasks: _deadlines.overdue,
                emptyText: 'Không có công việc nào quá hạn',
              ),
              const SizedBox(height: 12),
              _buildDeadlineCard(
                title:
                'Sắp đến hạn trong ${_deadlines.days} ngày (${_deadlines.upcoming.length})',
                color: Colors.orange,
                icon: Icons.schedule,
                tasks: _deadlines.upcoming,
                emptyText: 'Không có công việc nào sắp đến hạn',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Thống kê theo trạng thái -----
  Widget _buildStatusCard() {
    final total = _tasks.total;
    final rows = [
      ('Chưa thực hiện', _tasks.todo, Colors.grey),
      ('Đang thực hiện', _tasks.inProgress, Colors.blue),
      ('Đã hoàn thành', _tasks.completed, Colors.green),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Công việc theo trạng thái',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('Tổng: $total',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...rows.map((r) {
              final value = r.$2;
              final percent = total == 0 ? 0.0 : value / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.$1),
                        const Spacer(),
                        Text('$value (${(percent * 100).round()}%)'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 10,
                        color: r.$3,
                        backgroundColor: r.$3.withValues(alpha: 0.15),
                      ),
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

  // ----- Thống kê giao việc -----
  Widget _buildAssignmentCard() {
    Widget tile(String label, int value, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text('$value',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Giao việc và phụ trách',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                tile('Được giao cho tôi', _assign.assignedToMe,
                    Icons.assignment_ind, Colors.blue),
                tile('Được giao, chưa xong', _assign.assignedToMeActive,
                    Icons.pending_actions, Colors.indigo),
                tile('Tôi phụ trách chính', _assign.primary, Icons.star,
                    Colors.amber[800]!),
                tile('Phụ trách, chưa xong', _assign.primaryActive,
                    Icons.hourglass_bottom, Colors.orange),
                tile('Tôi tạo', _assign.createdByMe, Icons.create,
                    Colors.purple),
                tile('Tôi đã giao cho người khác', _assign.assignedByMe,
                    Icons.send, Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----- Danh sách quá hạn / sắp đến hạn -----
  Widget _buildDeadlineCard({
    required String title,
    required Color color,
    required IconData icon,
    required List<DeadlineTask> tasks,
    required String emptyText,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: color)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(emptyText,
                    style: const TextStyle(color: Colors.grey)),
              )
            else
              ...tasks.map((t) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(t.title),
                subtitle: Text(
                  'Hạn: ${_fmt(t.dueDate)}'
                      '${t.primaryAssigneeName != null && t.primaryAssigneeName!.isNotEmpty ? ' • ${t.primaryAssigneeName}' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTask(t.id),
              )),
          ],
        ),
      ),
    );
  }
}