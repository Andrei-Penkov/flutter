import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tip.dart';
import '../models/task.dart';
import '../screens/tips_detail_screen.dart';
import '../screens/task_test_screen.dart';
import '../screens/tasks_screen.dart';
import '../widgets/common_scaffold.dart';

class TipsScreen extends StatefulWidget {
  final String? filterTopic;
  final List<Tip>? tips;
  final String? topicName;

  const TipsScreen({super.key, this.filterTopic, this.tips, this.topicName});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  Map<String, Tip> allTips = {};
  List<Tip> displayedTips = [];
  bool isLoading = false;
  String? error;

  Map<String, Task> allTasks = {};
  List<Task> topicTasks = [];

  static const String tipStatusKey = 'tip_statuses';

  @override
  void initState() {
    super.initState();
    if (widget.tips != null && widget.topicName != null) {
      displayedTips = widget.tips!;
      isLoading = false;
    } else {
      loadTips();
    }
    loadTasks();
  }

  Future<void> loadTips() async {
    setState(() {
      isLoading = true;
    });
    try {
      final data = await rootBundle.loadString('assets/tips.txt');
      final tipJson = json.decode(data) as Map<String, dynamic>;
      final loadedTips = tipJson.map((k, v) => MapEntry(k, Tip.fromJson(v)));

      final prefs = await SharedPreferences.getInstance();
      final savedTipStatuses = prefs.getString(tipStatusKey) ?? '{}';
      final tipStatusesMap = json.decode(savedTipStatuses) as Map<String, dynamic>;
      for (final key in loadedTips.keys) {
        if (tipStatusesMap.containsKey(key)) {
          loadedTips[key]!.status = tipStatusesMap[key];
        }
      }

      setState(() {
        allTips = loadedTips;
        if (widget.filterTopic != null) {
          displayedTips = loadedTips.values.where((tip) => tip.topic == widget.filterTopic).toList();
        } else {
          displayedTips = loadedTips.values.toList();
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Ошибка загрузки советов: $e';
        isLoading = false;
      });
    }
  }

  Future<void> loadTasks() async {
    try {
      final data = await rootBundle.loadString('assets/tasks.txt');
      final taskJson = json.decode(data) as Map<String, dynamic>;
      final loadedTasks = taskJson.map((k, v) => MapEntry(k, Task.fromJson(v)));

      setState(() {
        allTasks = loadedTasks;
        if (widget.filterTopic != null) {
          topicTasks = loadedTasks.values.where((task) => task.topic == widget.filterTopic).toList();
        }
      });
    } catch (_) {
      topicTasks = [];
    }
  }

  Future<void> _saveTipStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (var e in allTips.entries) e.key: e.value.status};
    await prefs.setString(tipStatusKey, json.encode(map));
  }

  void _updateTipStatus(String key, int status) async {
    setState(() {
      allTips[key]?.status = status;
      final index = displayedTips.indexWhere((tip) => tip.name == allTips[key]?.name);
      if (index != -1) {
        displayedTips[index].status = status;
      }
    });
    await _saveTipStatuses();
  }

  void _openTaskScreen(Task task) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TasksScreen(
                  tasks: [task],
                  topicName: task.topic,
                )));
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
      title: widget.topicName ?? 'Советы',
      body: ListView.builder(
        itemCount: displayedTips.length + (topicTasks.isNotEmpty ? 1 : 0),
        itemBuilder: (context, idx) {
          if (idx < displayedTips.length) {
            final tip = displayedTips[idx];
            return ListTile(
              title: Text(tip.name),
              subtitle: Text(
                  'Уровень: ${tip.level} | Статус: ${tip.status == 1 ? "Прочитано" : "Не прочитано"}'),
              trailing: ElevatedButton(
                child: const Text('Прочитать'),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => TipDetailScreen(
                                tipKey: tip.tipKey,
                                tip: tip,
                                onStatusChanged: (tipKey, status) => _updateTipStatus(tipKey, status),
                              )));
                },
              ),
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Задания по теме "${widget.filterTopic ?? widget.topicName}"',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...topicTasks.map((task) {
                  return ListTile(
                    title: Text(task.name),
                    subtitle:
                        Text('Уровень: ${task.level} | Статус: ${task.status == 1 ? "Выполнено" : "Не выполнено"}'),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => TaskTestScreen(
                                      task: task,
                                      onStatusChanged: (status) {
                                        setState(() {
                                          task.status = status;
                                        });
                                      },
                                    )));
                      },
                      child: const Text('Пройти'),
                    ),
                  );
                }),
              ],
            );
          }
        },
      ),
    );
  }
}
