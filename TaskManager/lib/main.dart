import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'task_list_screen.dart';
import 'services/shared_prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Kiểm tra xem user đã đăng nhập hay chưa (có token hay chưa)
  final token = await SharedPrefs.getToken();
  
  runApp(MyApp(initialRoute: token != null ? '/tasks' : '/login'));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({Key? key, required this.initialRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/tasks': (context) => const TaskListScreen(),
      },
    );
  }
}