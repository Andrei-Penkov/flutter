import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/task.dart';
import '../managers/task_status_manager.dart';
import '../screens/tasks_screen.dart';
import '../widgets/common_scaffold.dart';

class TasksTopicsScreen extends StatefulWidget {
  const TasksTopicsScreen({super.key});

  @override
  State<TasksTopicsScreen> createState() => _TasksTopicsScreenState();
}

class _TasksTopicsScreenState extends State<TasksTopicsScreen> {
  Map<String, Task> allTasks = {};
  Map<String, List<Task>> tasksByTopic = {};
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 TasksTopicsScreen initState - начинаем загрузку');
    loadTasks();
  }

  Future<void> loadTasks() async {
    try {
      final data = await rootBundle.loadString('assets/tasks.txt');
      final taskJson = json.decode(data) as Map<String, dynamic>;
      final loadedTasks = taskJson.map((k, v) => MapEntry(k, Task.fromJson(v)));

      await TaskStatusManager.instance.applyTaskStatusesByName(loadedTasks);

      Map<String, List<Task>> mapByTopic = {};
      for (var task in loadedTasks.values) {
        mapByTopic.putIfAbsent(task.topic, () => []).add(task);
      }

      setState(() {
        allTasks = loadedTasks;
        tasksByTopic = mapByTopic;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Ошибка загрузки задач: $e';
        isLoading = false;
      });
    }
  }

  void refreshStatuses() async {
    await TaskStatusManager.instance.applyTaskStatuses(allTasks);
    setState(() {
      Map<String, List<Task>> mapByTopic = {};
      for (var task in allTasks.values) {
        mapByTopic.putIfAbsent(task.topic, () => []).add(task);
      }
      tasksByTopic = mapByTopic;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }

    return CommonScaffold(
      title: 'Темы заданий',
      body: ListView(
        children: tasksByTopic.entries
            .map((entry) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(entry.key),
                    subtitle: Text('Количество заданий: ${entry.value.length}'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TasksScreen(
                            tasks: entry.value,
                            topicName: entry.key,
                          ),
                        ),
                      );
                      refreshStatuses();
                    },
                  ),
                ))
            .toList(),
      ),
    );
  }
}
