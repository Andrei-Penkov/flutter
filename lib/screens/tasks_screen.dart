import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../screens/task_test_screen.dart';
import '../widgets/common_scaffold.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  Map<String, Task> tasks = {};  // Словарь с загруженными заданиями
  bool isLoading = true;         // Флаг загрузки данных
  String? error;                 // Сообщение об ошибке при загрузке
  static const String taskStatusKey = 'task_statuses'; // Ключ для статусов в кеше

  // Инициализация: загрузка данных при создании состояния
  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Загрузка заданий из assets и сохранённых статусов из SharedPreferences
  Future<void> _loadTasks() async {
    try {
      // Загрузка JSON из файла в assets
      final data = await rootBundle.loadString('assets/tasks.txt');
      final taskJson = json.decode(data) as Map<String, dynamic>;
      final loadedTasks = taskJson.map((k, v) => MapEntry(k, Task.fromJson(v)));

      // Получение доступ к SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      // Загрузка сохранённых статусов или пустой JSON, если нет
      final savedTaskStatuses = prefs.getString(taskStatusKey) ?? '{}';
      final taskStatusesMap =
          json.decode(savedTaskStatuses) as Map<String, dynamic>;

      // Присвоение сохранённых статусов к загруженным заданиям
      for (final key in loadedTasks.keys) {
        if (taskStatusesMap.containsKey(key)) {
          loadedTasks[key]!.status = taskStatusesMap[key];
        }
      }

      // Обновление состояния
      setState(() {
        tasks = loadedTasks;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Ошибка загрузки задач: $e';
        isLoading = false;
      });
    }
  }

  // Сохранение текущих статусов заданий в SharedPreferences
  Future<void> _saveTaskStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (var e in tasks.entries) e.key: e.value.status};
    await prefs.setString(taskStatusKey, json.encode(map));
  }

  // Обновление статуса конкретного задания и сохранение изменений
  void _updateStatus(String key, int status) async {
    setState(() {
      tasks[key]?.status = status;
    });
    await _saveTaskStatuses();
  }

  // список заданий с кнопками "Пройти"
  @override
  Widget build(BuildContext context) {
    // Если идет загрузка
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Если ошибка
    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }
    // Основной Scaffold с заголовком и списком заданий
    return CommonScaffold(
      title: 'Список заданий',
      body: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, idx) {
          final key = tasks.keys.elementAt(idx);
          final task = tasks[key]!;
          return ListTile(
            title: Text(task.name),
            subtitle: Text(
                'Уровень: ${task.level} | Статус: ${task.status == 1 ? "Выполнено" : "Не выполнено"}'),
            trailing: ElevatedButton(
                onPressed: () {
                  // Переход на экран прохождения задания с передачей коллбэка для обновления статуса
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TaskTestScreen(
                              task: task,
                              onStatusChanged: (status) =>
                                  _updateStatus(key, status),
                            )),
                  );
                },
                child: const Text('Пройти')),
          );
        },
      ),
    );
  }
}
