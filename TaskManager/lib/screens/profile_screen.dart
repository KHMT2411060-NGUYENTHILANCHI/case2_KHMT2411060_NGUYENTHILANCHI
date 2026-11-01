import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();

  bool _loading = true;
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _obscure = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  // ---------- Tải thông tin ----------
  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final user = await _authService.getMe();
      _nameController.text = (user['fullName'] ?? '').toString();
      _emailController.text = (user['email'] ?? '').toString();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _goToLogin();
        return;
      }
      _loadError = e.message;
    } catch (_) {
      _loadError = 'Không thể kết nối đến máy chủ';
    }
    if (mounted) setState(() => _loading = false);
  }

  // ---------- Cập nhật thông tin ----------
  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      await _authService.updateMe(fullName: _nameController.text.trim());
      _showMessage('Cập nhật thông tin thành công');
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Không thể kết nối đến máy chủ');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  // ---------- Đổi mật khẩu ----------
  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    try {
      await _authService.changePassword(
        currentPassword: _currentPwController.text,
        newPassword: _newPwController.text,
      );
      _currentPwController.clear();
      _newPwController.clear();
      _confirmPwController.clear();
      _showMessage('Đổi mật khẩu thành công');
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Không thể kết nối đến máy chủ');
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  // ---------- Đăng xuất ----------
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _authService.logout();
    await _goToLogin();
  }

  Future<void> _goToLogin() async {
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

  // ---------- Giao diện ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProfile,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    final name = _nameController.text.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                child: Text(initial, style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 24),

            // ----- Thông tin cá nhân -----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _profileFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thông tin cá nhân',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Họ tên',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Họ tên không được để trống'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Email (không thể thay đổi)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _savingProfile ? null : _saveProfile,
                          child: _savingProfile
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                              : const Text('Lưu thông tin'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ----- Đổi mật khẩu -----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đổi mật khẩu',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _currentPwController,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu hiện tại',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Vui lòng nhập mật khẩu hiện tại'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPwController,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu mới',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Vui lòng nhập mật khẩu mới';
                          }
                          if (v.length < 6) {
                            return 'Mật khẩu mới tối thiểu 6 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPwController,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'Xác nhận mật khẩu mới',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v != _newPwController.text
                            ? 'Mật khẩu xác nhận không khớp'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _savingPassword ? null : _changePassword,
                          child: _savingPassword
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                              : const Text('Đổi mật khẩu'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ----- Đăng xuất -----
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}