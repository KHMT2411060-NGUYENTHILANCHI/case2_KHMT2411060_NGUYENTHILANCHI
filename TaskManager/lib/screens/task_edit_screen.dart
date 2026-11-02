import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/task_api_service.dart';

class TaskEditScreen extends StatefulWidget {
  final Task task;

  const TaskEditScreen({super.key, required this.task});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taskService = TaskApiService();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  DateTime? _startDate;
  DateTime? _dueDate;
  late String _priority;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t.title);
    _descController = TextEditingController(text: t.description);
    _startDate = t.startDate;
    _dueDate = t.dueDate;
    _priority = t.priority;
    _status = t.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Chưa chọn';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart ? _startDate : _dueDate;
    final initial = current ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(
          (current != null && current.year < now.year - 1)
              ? current.year
              : now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _dueDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate != null &&
        _dueDate != null &&
        _dueDate!.isBefore(_startDate!)) {
      _showMessage('Hạn hoàn thành phải sau ngày bắt đầu');
      return;
    }

    setState(() => _saving = true);
    try {
      await _taskService.updateTask(
        widget.task.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        startDate: _startDate,
        dueDate: _dueDate,
        priority: _priority,
        status: _status,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true); // báo cho màn hình chi tiết tải lại
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Không thể kết nối đến máy chủ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa công việc')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tên công việc *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên công việc'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(isStart: true),
                          icon: const Icon(Icons.event_available),
                          label: Text('Bắt đầu: ${_formatDate(_startDate)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(isStart: false),
                          icon: const Icon(Icons.event),
                          label: Text('Hạn: ${_formatDate(_dueDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Mức độ ưu tiên',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Thấp')),
                      DropdownMenuItem(
                          value: 'medium', child: Text('Trung bình')),
                      DropdownMenuItem(value: 'high', child: Text('Cao')),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'todo', child: Text('Chưa thực hiện')),
                      DropdownMenuItem(
                          value: 'in_progress', child: Text('Đang thực hiện')),
                      DropdownMenuItem(
                          value: 'completed', child: Text('Đã hoàn thành')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'todo'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Lưu thay đổi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}