import 'package:flutter/material.dart';
import 'profile_screen.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc'),
        actions: [
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
      body: const Center(
        child: Text('Đăng nhập thành công!\nDanh sách công việc sẽ làm ở nhóm B.',
            textAlign: TextAlign.center),
      ),
    );
  }
}