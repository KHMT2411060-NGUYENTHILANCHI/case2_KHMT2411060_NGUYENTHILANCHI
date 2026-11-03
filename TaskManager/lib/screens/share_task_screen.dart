import 'dart:async';

import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/task_api_service.dart';
import 'login_screen.dart';

class ShareTaskScreen extends StatefulWidget {
  final Task task;

  const ShareTaskScreen({super.key, required this.task});

  @override
  State<ShareTaskScreen> createState() => _ShareTaskScreenState();
}

class _ShareTaskScreenState extends State<ShareTaskScreen> {
  final _service = TaskApiService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<TaskShare> _shares = [];
  List<UserSummary> _results = [];
  final Map<String, UserSummary> _selected = {};

  String _permission = 'viewer'; // quyền cấp cho người sắp chia sẻ
  bool _loading = true;
  bool _searching = false;
  bool _busy = false;
  bool _changed = false; // có thay đổi thì báo màn hình chi tiết tải lại
  String _lastQuery = '';

  static const _permissionLabels = {
    'viewer': 'Chỉ xem',
    'editor': 'Chỉnh sửa',
  };

  @override
  void initState() {
    super.initState();
    _loadShares();
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

  bool _isShared(String userId) =>
      _shares.any((s) => s.user != null && s.user!.id == userId);

  // ---------- Tải danh sách chia sẻ ----------
  Future<void> _loadShares() async {
    setState(() => _loading = true);
    try {
      final shares = await _service.getShares(widget.task.id);
      if (!mounted) return;
      setState(() => _shares = shares);
    } catch (e) {
      await _handleError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  // ---------- Chia sẻ ----------
  Future<void> _share() async {
    if (_selected.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      final shares = await _service.addShares(
        widget.task.id,
        userIds: _selected.keys.toList(),
        permission: _permission,
      );
      if (!mounted) return;
      setState(() {
        _shares = shares;
        _selected.clear();
        _changed = true;
      });
      _showMessage('Đã chia sẻ công việc');
    } catch (e) {
      await _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Đổi quyền ----------
  Future<void> _changePermission(TaskShare share, String permission) async {
    if (_busy || permission == share.permission) return;

    setState(() => _busy = true);
    try {
      final shares = await _service.updateShare(
        widget.task.id,
        share.id,
        permission,
      );
      if (!mounted) return;
      setState(() {
        _shares = shares;
        _changed = true;
      });
      _showMessage('Đã đổi quyền');
    } catch (e) {
      await _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Thu hồi quyền ----------
  Future<void> _revoke(TaskShare share) async {
    if (_busy) return;

    final name = share.user?.fullName ?? 'người này';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi quyền truy cập'),
        content: Text('Thu hồi quyền truy cập của $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final shares = await _service.deleteShare(widget.task.id, share.id);
      if (!mounted) return;
      setState(() {
        _shares = shares;
        _changed = true;
      });
      _showMessage('Đã thu hồi quyền');
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
        appBar: AppBar(title: const Text('Chia sẻ công việc')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.task.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCurrentShares(),
                const SizedBox(height: 16),
                _buildShareSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentShares() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Người được chia sẻ (${_shares.length})',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_shares.isEmpty)
              const Text('Chưa chia sẻ cho ai',
                  style: TextStyle(color: Colors.grey))
            else
              ..._shares.map((s) {
                final name = s.user?.fullName ?? 'Không rõ';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                  ),
                  title: Text(name),
                  subtitle: Text(s.user?.email ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: s.permission,
                        underline: const SizedBox.shrink(),
                        items: _permissionLabels.entries
                            .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (v) {
                          if (v != null) _changePermission(s, v);
                        },
                      ),
                      IconButton(
                        tooltip: 'Thu hồi quyền',
                        icon: const Icon(Icons.person_remove,
                            color: Colors.red),
                        onPressed: _busy ? null : () => _revoke(s),
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

  Widget _buildShareSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chia sẻ cho người khác',
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
                final shared = _isShared(u.id);
                final selected = _selected.containsKey(u.id);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: shared ? true : selected,
                  onChanged: shared ? null : (_) => _toggleSelect(u),
                  title: Text(u.fullName),
                  subtitle: Text(
                    shared ? '${u.email} • Đã được chia sẻ' : u.email,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }),

            const SizedBox(height: 12),
            Text('Quyền cấp cho người được chọn',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'viewer',
                  icon: Icon(Icons.visibility),
                  label: Text('Chỉ xem'),
                ),
                ButtonSegment(
                  value: 'editor',
                  icon: Icon(Icons.edit),
                  label: Text('Chỉnh sửa'),
                ),
              ],
              selected: {_permission},
              onSelectionChanged: (s) =>
                  setState(() => _permission = s.first),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: (_selected.isEmpty || _busy) ? null : _share,
                icon: _busy
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.share),
                label: Text(_selected.isEmpty
                    ? 'Chọn người để chia sẻ'
                    : 'Chia sẻ cho ${_selected.length} người'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}