import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/tips_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tasks & Tips App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MainScreen(),
        routes: {
          '/tasks': (context) => const TasksScreen(),
          '/tips': (context) => const TipsScreen(),
        },
      );
}
