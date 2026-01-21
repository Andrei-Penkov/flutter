import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/tip.dart';
import '../managers/task_status_manager.dart';
import '../widgets/common_scaffold.dart';
import './favorites_tips_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Task> tasks = [];
  List<Tip> tips = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadStats();
  }
  
  // Цвета для темной темы
  Color getCardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2D2D2D) : Colors.white;
  }

  Color getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black87;
  }

  Color getSecondaryTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white70 : Colors.black54;
  }

  Future<void> loadStats() async {
    try {
      debugPrint('📊 Загрузка статистики...');
      
      // Загружаем задачи
      final taskData = await rootBundle.loadString('assets/tasks.txt');
      final taskJson = json.decode(taskData) as Map<String, dynamic>;
      final taskMap = taskJson.map((k, v) => MapEntry(k, Task.fromJson(v)));
      await TaskStatusManager.instance.applyTaskStatusesByName(taskMap);
      tasks = taskMap.values.toList();

      // Загружаем советы
      final tipData = await rootBundle.loadString('assets/tips.txt');
      final tipJson = json.decode(tipData) as Map<String, dynamic>;
      final tipMap = <String, Tip>{};
      for (final entry in tipJson.entries) {
        final tipKey = entry.key.trim();
        if (tipKey.isNotEmpty) {
          tipMap[tipKey] = Tip.fromJson(entry.value, key: tipKey);
        }
      }
      
      // Применяем статусы и избранное
      await TaskStatusManager.instance.applyTipStatuses(tipMap);
      await TaskStatusManager.instance.applyFavoriteStatuses(tipMap);
      tips = tipMap.values.toList();

      debugPrint('✅ Статистика загружена:');
      debugPrint('   📝 Заданий: ${tasks.length}');
      debugPrint('   💡 Советов: ${tips.length}');
      debugPrint('   ❤️  Избранных советов: $favoriteTips');

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Ошибка загрузки статистики: $e');
      setState(() {
        error = 'Ошибка загрузки: $e';
        isLoading = false;
      });
    }
  }

  // 📊 СТАТИСТИКА ЗАДАНИЙ
  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((t) => t.status == 1).length;
  double get tasksProgress => totalTasks > 0 ? completedTasks / totalTasks : 0;

  // 📊 СТАТИСТИКА СОВЕТОВ
  int get totalTips => tips.length;
  int get readTips => tips.where((t) => t.status == 1).length;
  double get tipsProgress => totalTips > 0 ? readTips / totalTips : 0;

  // 📊 НОВАЯ СТАТИСТИКА ИЗБРАННЫХ
  int get favoriteTips => tips.where((t) => t.isFavorite).length;
  double get favoriteTipsPercent => totalTips > 0 ? favoriteTips / totalTips : 0;
  
  // Распределение избранных по темам
  Map<String, int> get favoriteTopics {
    final favoriteTipsList = tips.where((t) => t.isFavorite);
    final topics = <String, int>{};
    
    for (final tip in favoriteTipsList) {
      topics.update(tip.topic, (value) => value + 1, ifAbsent: () => 1);
    }
    
    // Сортируем по убыванию
    return Map.fromEntries(
      topics.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
    );
  }

  // 📈 Данные для графиков по уровням
  Map<int, int> get tasksByLevel => {
    for (int level = 1; level <= 5; level++)
      level: tasks.where((t) => t.level == level && t.status == 1).length
  };

  Map<int, int> get tipsByLevel => {
    for (int level = 1; level <= 5; level++)
      level: tips.where((t) => t.level == level && t.status == 1).length
  };

  // Сброс прочтения советов
  // screens/stats_screen.dart - обновляем метод _resetTipsReadStatus
// screens/stats_screen.dart - упрощенный метод _resetTipsReadStatus
Future<void> _resetTipsReadStatus() async {
  bool? confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Сбросить прочтение советов'),
      content: const Text(
        'Вы уверены, что хотите сбросить статус прочтения всех советов? '
        'Это действие нельзя отменить.\n\n'
        'Обратите внимание: избранные советы НЕ будут удалены.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Сбросить'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    try {
      debugPrint('🔄 Начинаем сброс статусов прочтения советов...');
      
      // Используем SharedPreferences напрямую
      final prefs = await SharedPreferences.getInstance();
      
      // ПРОСТО УДАЛЯЕМ ВСЕ СТАТУСЫ ПРОЧТЕНИЯ СОВЕТОВ
      await prefs.remove('tip_statuses');
      debugPrint('✅ Ключ "tip_statuses" удален из SharedPreferences');
      
      // Избранное остается - ключ 'favorite_tips' НЕ трогаем!
      
      // Перезагружаем статистику
      await loadStats();
      debugPrint('🔄 Статистика перезагружена');
      
      // Показываем сообщение об успехе
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Статус прочтения советов сброшен'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Ошибка при сбросе статусов: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при сбросе: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        body: Center(child: Text(error!)),
      );
    }

    return CommonScaffold(
      title: '📊 Статистика',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎯 ОСНОВНЫЕ ПРОГРЕСС БАРЫ
            _buildProgressCard('Задания', completedTasks, totalTasks, tasksProgress, Icons.task),
            const SizedBox(height: 16),
            _buildProgressCard('Советы', readTips, totalTips, tipsProgress, Icons.lightbulb),
            const SizedBox(height: 16),
            
            // ❤️ РАЗДЕЛ ИЗБРАННЫХ
            _buildFavoritesSection(),
            const SizedBox(height: 16),

            // 📊 ДЕТАЛЬНАЯ СТАТИСТИКА
            _buildDetailStats(),
            
            // КНОПКА СБРОСА СТАТУСА СОВЕТОВ
            if (readTips > 0) ...[
              const SizedBox(height: 16),
              _buildResetButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(String title, int completed, int total, double progress, IconData icon) {
    final color = progress > 0.7 ? Colors.green 
        : progress > 0.3 ? Colors.orange : Colors.red;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  label: Text('${(progress * 100).toInt()}%'),
                  backgroundColor: color.withOpacity(0.1),
                  labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completed из $total',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  progress == 1 ? '🎉 Выполнено!' : 'Продолжайте в том же духе!',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesSection() {
    final hasFavorites = favoriteTips > 0;
    
    return GestureDetector(
      onTap: hasFavorites ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FavoritesTipsScreen(),
          ),
        );
      } : null,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: hasFavorites 
                ? Border.all(color: Colors.red.withOpacity(0.3), width: 2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: hasFavorites ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Избранные советы',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hasFavorites ? null : Colors.grey,
                        ),
                      ),
                    ),
                    if (hasFavorites) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '$favoriteTips',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '0',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Прогресс избранных
                LinearProgressIndicator(
                  value: favoriteTipsPercent,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasFavorites ? Colors.red : Colors.grey,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  '$favoriteTips из $totalTips советов в избранном (${(favoriteTipsPercent * 100).toInt()}%)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: hasFavorites ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
                
                // Распределение по темам
                if (favoriteTopics.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Топ темы:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  ...favoriteTopics.entries.take(3).map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  
                  if (favoriteTopics.length > 3) ...[
                    const SizedBox(height: 4),
                    Text(
                      '... и ещё ${favoriteTopics.length - 3} тем',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ] else if (!hasFavorites) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Нажимайте ♡ в списке советов, чтобы добавить в избранное',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Индикатор кликабельности
                if (hasFavorites) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Нажмите для просмотра всех избранных',
                      style: TextStyle(
                        fontSize: 10,
                        color: const Color.fromRGBO(244, 67, 54, 1),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStats() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Общая статистика',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 400;
                
                return isWide
                    ? Row(
                        children: [
                          Expanded(child: _buildStatsColumn('Задания', _getTaskStats())),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatsColumn('Советы', _getTipStats())),
                        ],
                      )
                    : Column(
                        children: [
                          _buildStatsColumn('Задания', _getTaskStats()),
                          const SizedBox(height: 16),
                          _buildStatsColumn('Советы', _getTipStats()),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _getTaskStats() {
    return {
      'Всего заданий': totalTasks.toString(),
      'Выполнено': completedTasks.toString(),
      'Не выполнено': (totalTasks - completedTasks).toString(),
      'Прогресс': '${(tasksProgress * 100).toInt()}%',
    };
  }

  Map<String, String> _getTipStats() {
    return {
      'Всего советов': totalTips.toString(),
      'Прочитано': readTips.toString(),
      'В избранном': favoriteTips.toString(),
      'Не прочитано': (totalTips - readTips).toString(),
      'Прогресс чтения': '${(tipsProgress * 100).toInt()}%',
    };
  }

  Widget _buildStatsColumn(String title, Map<String, String> stats) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final isTasks = title == 'Задания';
  
  Color backgroundColor;
  Color borderColor;
  Color iconColor;
  Color textColor;
  
  if (isDark) {
    // Темная тема
    backgroundColor = isTasks 
        ? const Color(0xFF1E3A5F) // Темно-синий для заданий
        : const Color(0xFF4A235A); // Темно-фиолетовый для советов
    borderColor = isTasks 
        ? const Color(0xFF2E5090) 
        : const Color(0xFF6A3485);
    iconColor = isTasks 
        ? const Color(0xFF90CAF9) 
        : const Color(0xFFCE93D8);
    textColor = Colors.white;
  } else {
    // Светлая тема
    backgroundColor = isTasks 
        ? Colors.blue.shade50 
        : Colors.purple.shade50;
    borderColor = isTasks 
        ? Colors.blue.shade200 
        : Colors.purple.shade200;
    iconColor = isTasks 
        ? Colors.blue 
        : Colors.purple;
    textColor = Colors.black87;
  }
  
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: borderColor,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isTasks ? Icons.task_alt : Icons.lightbulb,
              color: iconColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...stats.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withOpacity(0.9),
                    ),
                  ),
                ),
                Text(
                  entry.value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}

  Widget _buildResetButton() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.refresh,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Управление чтением',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Прочитано советов: $readTips',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Хотите начать читать советы заново? Эта функция сбросит статус прочтения всех советов (не затронет избранные).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetTipsReadStatus,
                icon: Icon(
                  Icons.refresh,
                  color: Colors.orange,
                ),
                label: Text(
                  'Сбросить прочтение советов',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}