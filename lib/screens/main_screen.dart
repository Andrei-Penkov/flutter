import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/tip.dart';
import '../screens/task_test_screen.dart';
import '../screens/tips_detail_screen.dart';
import '../widgets/common_scaffold.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Map<String, Task> tasks = {}; // Словарь заданий по ключу
  Map<String, Tip> tips = {};   // Словарь советов по ключу
  bool isLoading = true;        // Индикатор загрузки данных
  String? error;                // Ошибка загрузки (если есть)

  // Ключи для сохранения статусов заданий и советов в SharedPreferences
  static const String taskStatusKey = 'task_statuses';
  static const String tipStatusKey = 'tip_statuses';

  @override
  void initState() {
    super.initState();
    _loadData(); // При инициализации экрана загрузга данных
  }

  // Метод для асинхронной загрузки данных из assets и сохранённых статусов
  Future<void> _loadData() async {
    try {
      // JSON из assets
      final taskJsonStr = await rootBundle.loadString('assets/tasks.txt');
      final tipJsonStr = await rootBundle.loadString('assets/tips.txt');

      // JSON в Map
      final taskJson = json.decode(taskJsonStr) as Map<String, dynamic>;
      final tipJson = json.decode(tipJsonStr) as Map<String, dynamic>;

      // JSON в объекты Task и Tip
      final loadedTasks = taskJson.map((k, v) => MapEntry(k, Task.fromJson(v)));
      final loadedTips = tipJson.map((k, v) => MapEntry(k, Tip.fromJson(v)));

      // экземпляр SharedPreferences для чтения сохранённых статусов
      final prefs = await SharedPreferences.getInstance();

      // Считываение сохранённые статусы
      final savedTaskStatuses = prefs.getString(taskStatusKey) ?? '{}';
      final savedTipStatuses = prefs.getString(tipStatusKey) ?? '{}';

      // сохранённые статусы в Map
      final taskStatusesMap = json.decode(savedTaskStatuses) as Map<String, dynamic>;
      final tipStatusesMap = json.decode(savedTipStatuses) as Map<String, dynamic>;

      // сохранённые статусы к загруженным заданиям
      for (final key in loadedTasks.keys) {
        if (taskStatusesMap.containsKey(key)) {
          loadedTasks[key]!.status = taskStatusesMap[key];
        }
      }

      // сохранённые статусы к загруженным советам
      for (final key in loadedTips.keys) {
        if (tipStatusesMap.containsKey(key)) {
          loadedTips[key]!.status = tipStatusesMap[key];
        }
      }

      // Обновляение состояние
      setState(() {
        tasks = loadedTasks;
        tips = loadedTips;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Ошибка загрузки данных: $e';
        isLoading = false;
      });
    }
  }

  // статусы заданий в SharedPreferences
  Future<void> _saveTaskStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (var e in tasks.entries) e.key: e.value.status};
    await prefs.setString(taskStatusKey, json.encode(map));
  }

  // статусы советов в SharedPreferences
  Future<void> _saveTipStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (var e in tips.entries) e.key: e.value.status};
    await prefs.setString(tipStatusKey, json.encode(map));
  }

  // Открыть случайное задание для прохождения
  void _openRandomTask() {
    if (tasks.isEmpty) return;
    // случайный ключ задания
    final randomKey = (tasks.keys.toList()..shuffle()).first;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TaskTestScreen(
                task: tasks[randomKey]!,
                onStatusChanged: (status) async {
                  // Обновляение статуса состояния
                  setState(() {
                    tasks[randomKey]!.status = status;
                  });
                  await _saveTaskStatuses();
                },
              )),
    );
  }

  // Открыть случайный совет для прочтения
  void _openRandomTip() {
    if (tips.isEmpty) return;
    // случайный ключ совета
    final randomTipKey = (tips.keys.toList()..shuffle()).first;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TipDetailScreen(
            tipKey: randomTipKey,
            tip: tips[randomTipKey]!,
            onStatusChanged: (status) async {
              // изменение статуса
              setState(() {
                tips[randomTipKey]!.status = status;
              });
              await _saveTipStatuses();
            },
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    // индикатор загрузки
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // показать сообщение об ошибке
    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }
    // Основной экран с кнопками для случайного задания и совета
    return CommonScaffold(
      title: 'Главная',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _openRandomTask,
              child: const Text('СЛУЧАЙНОЕ ЗАДАНИЕ'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openRandomTip,
              child: const Text('СЛУЧАЙНЫЙ СОВЕТ'),
            ),
          ],
        ),
      ),
    );
  }
}
