import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/task_list_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Kiểm tra token đã lưu: còn hợp lệ thì vào danh sách công việc,
/// không thì về màn hình đăng nhập.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _isLoggedIn() async {
    final authService = AuthService();

    final token = await authService.getToken();
    if (token == null) return false;

    try {
      await authService.getMe(); // xác minh token với server
      return true;
    } on ApiException {
      // Token hết hạn / không hợp lệ
      await authService.logout();
      return false;
    } catch (_) {
      // Lỗi mạng: coi như chưa đăng nhập để người dùng thử lại
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == true
            ? const TaskListScreen()
            : const LoginScreen();
      },
    );
  }
}