import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/task.dart';
import '../models/tip.dart';
import '../managers/task_status_manager.dart';
import '../screens/task_test_screen.dart';
import '../screens/tips_detail_screen.dart';
import '../screens/tasks_topics_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/tips_topics_screen.dart';
import '../screens/tips_screen.dart';
import '../widgets/common_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Map<String, Task> tasks = {};
  Map<String, Tip> tips = {};
  List<Tip> featuredTips = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('🧹 SharedPreferences ОЧИЩЕНЫ');
  }

  Future<void> _loadData() async {
    try {
      final taskJsonStr = await rootBundle.loadString('assets/tasks.txt');
      final tipJsonStr = await rootBundle.loadString('assets/tips.txt');

      final taskJson = json.decode(taskJsonStr) as Map<String, dynamic>;
      final tipJson = json.decode(tipJsonStr) as Map<String, dynamic>;

      final loadedTasks = taskJson.map((k, v) => MapEntry(k, Task.fromJson(v)));
      final loadedTips = tipJson.map((k, v) => MapEntry(k, Tip.fromJson(v, key: k)));

      await TaskStatusManager.instance.applyTaskStatusesByName(loadedTasks);
      await TaskStatusManager.instance.applyTipStatuses(loadedTips);

      featuredTips = _getSmartRecommendations(loadedTips);

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

  List<Tip> _getSmartRecommendations(Map<String, Tip> allTips) {
    final tipsByLevel = <int, List<Tip>>{};

    for (var tip in allTips.values) {
      tipsByLevel.putIfAbsent(tip.level, () => []).add(tip);
    }

    for (int level = 0; level <= 3; level++) {
      final uncompletedTips = tipsByLevel[level]
          ?.where((tip) => tip.status != 1)
          .toList() ?? [];

      if (uncompletedTips.isNotEmpty) {
        return uncompletedTips.take(3).toList();
      }
    }

    return allTips.values
        .where((tip) => tip.level <= 2)
        .take(3)
        .toList();
  }



  void _openRandomTask() {
    if (tasks.isEmpty) return;
    final randomKey = (tasks.keys.toList()..shuffle()).first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskTestScreen(
          task: tasks[randomKey]!,
          onStatusChanged: (status) async {
            setState(() {
              tasks[randomKey]!.status = status;
            });
            await TaskStatusManager.instance.updateTaskStatus(randomKey, status);
          },
        ),
      ),
    );
  }

  void _openRandomTip() {
    if (tips.isEmpty) return;
    final randomTipKey = (tips.keys.toList()..shuffle()).first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TipDetailScreen(
          tipKey: randomTipKey,
          tip: tips[randomTipKey]!,
          onStatusChanged: (tipKey, status) {
            setState(() {
              tips[tipKey]!.status = status;
            });
            TaskStatusManager.instance.updateTipStatus(tipKey, status);
          },
        ),
      ),
    );
  }

  void _openTipDetail(String tipKey) {
  final tip = tips[tipKey];
  if (tip != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TipDetailScreen(
          tipKey: tipKey,
          tip: tip,
          onStatusChanged: (key, status) {
            if (mounted) {
              setState(() {
                tips[key]!.status = status;
              });
            }
            TaskStatusManager.instance.updateTipStatus(key, status);
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          featuredTips = _getSmartRecommendations(tips);
        });
      }
    });
  }
}


  void _openTasksByTopic(String topic) {
  final topicTasks = tasks.values.where((task) => task.topic == topic).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TasksScreen(
          tasks: topicTasks,
          topicName: topic,
        ),
      ),
    );
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
      title: 'Главная',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Column(
              children: [
                ElevatedButton(
                  onPressed: _openRandomTask,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: const Text('🎯 СЛУЧАЙНОЕ ЗАДАНИЕ'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _openRandomTip,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: const Text('💡 СЛУЧАЙНЫЙ СОВЕТ'),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/tasks_topics'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: const Text('📚 Задания по темам'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/tips_topics'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: const Text('💭 Советы по темам'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final isNarrow = screenWidth < 380;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '📰 Рекомендуем почитать',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: isNarrow ? 20 : 24,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // IconButton(
                        //   onPressed: () => Navigator.pushNamed(context, '/tips_topics'),
                        //   icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        //   tooltip: 'Все советы',
                        //   padding: EdgeInsets.zero,
                        //   constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        // ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    ...featuredTips.map((tip) => _buildAdaptiveTipCard(tip, isNarrow)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveTipCard(Tip tip, bool isNarrow) {
    return Container(
      height: isNarrow ? 200 : 215,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade500,
            Colors.purple.shade500,
            Colors.purple.shade600, // Добавляем третий цвет чтобы избежать черной области
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect( // Добавляем ClipRRect для гарантированного закругления
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Убираем второй градиент или изменяем его
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.15), // Уменьшаем прозрачность
                    ],
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: EdgeInsets.all(isNarrow ? 12.0 : 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Название + статус
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tip.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isNarrow ? 14.0 : 15.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: tip.status == 1 ? Colors.green : Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tip.status == 1 ? '✓' : '○',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isNarrow ? 11.0 : 12.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Текст превью
                  Text(
                    tip.tip.length > (isNarrow ? 70 : 90)
                        ? '${tip.tip.substring(0, isNarrow ? 70 : 90)}...'
                        : tip.tip,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: isNarrow ? 12.5 : 13.5,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Адаптивные кнопки
                  _buildAdaptiveButtons(tip, isNarrow),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveButtons(Tip tip, bool isNarrow) {
      if (isNarrow) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _openTipDetail(tip.tipKey),
                icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
                label: Text(
                  'Подробнее',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _openTasksByTopic(tip.topic),
                icon: const Icon(Icons.task_alt, size: 14, color: Colors.white),
                label: Text(
                  'К тестам',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        return Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => _openTipDetail(tip.tipKey),
                icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
                label: const Text(
                  'Подробнее',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: TextButton.icon(
                onPressed: () => _openTasksByTopic(tip.topic),
                icon: const Icon(Icons.task_alt, size: 14, color: Colors.white),
                label: Text(
                  'Тесты',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

}
