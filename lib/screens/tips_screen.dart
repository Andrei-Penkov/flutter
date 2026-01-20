import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../managers/task_status_manager.dart';
import '../models/task.dart';
import '../models/tip.dart';
import '../screens/tasks_screen.dart';
import '../screens/tips_detail_screen.dart';
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
  List<Tip> allTips = [];
  List<Tip> displayedTips = [];
  Map<String, Task> allTasks = {};
  bool isLoading = true;
  String? error;

  // Для поиска
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _updateFilteredTips();
    });
  }

  void _updateFilteredTips() {
    if (_searchQuery.isEmpty) {
      displayedTips = List.from(allTips);
    } else {
      displayedTips = allTips.where((tip) {
        return tip.name.toLowerCase().contains(_searchQuery) ||
            tip.topic.toLowerCase().contains(_searchQuery) ||
            tip.level.toString().toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  void _clearSearch() {
    _searchController.clear();
  }

  Future<void> _loadAllData() async {
    try {
      debugPrint('🚀 Загрузка данных для TipsScreen...');
      
      // Загружаем задачи
      debugPrint('📥 Загрузка задач...');
      final taskData = await rootBundle.loadString('assets/tasks.txt');
      final taskJson = json.decode(taskData) as Map<String, dynamic>;
      final loadedTasks = taskJson.map((k, v) => MapEntry(k, Task.fromJson(v)));
      await TaskStatusManager.instance.applyTaskStatusesByName(loadedTasks);
      debugPrint('✅ Загружено задач: ${loadedTasks.length}');

      // Загружаем или используем переданные советы
      Map<String, Tip> tipMap;
      
      if (widget.tips != null) {
        debugPrint('📝 Используем переданные советы: ${widget.tips!.length}');
        tipMap = <String, Tip>{};
        for (final tip in widget.tips!) {
          tipMap[tip.tipKey] = tip;
        }
      } else {
        debugPrint('📥 Загрузка всех советов...');
        final data = await rootBundle.loadString('assets/tips.txt');
        final tipJson = json.decode(data) as Map<String, dynamic>;
        
        tipMap = {};
        for (final entry in tipJson.entries) {
          final tipKey = entry.key.trim();
          if (tipKey.isNotEmpty) {
            tipMap[tipKey] = Tip.fromJson(entry.value, key: tipKey);
          }
        }
        debugPrint('✅ Загружено советов: ${tipMap.length}');
      }

      // Применяем статусы прочтения и избранного
      await TaskStatusManager.instance.applyTipStatuses(tipMap);
      await TaskStatusManager.instance.applyFavoriteStatuses(tipMap);

      // Фильтруем советы по теме если нужно
      List<Tip> filteredTips = tipMap.values.toList();
      if (widget.filterTopic != null && widget.filterTopic!.trim().isNotEmpty) {
        final filterNorm = widget.filterTopic!.trim().toLowerCase();
        debugPrint('🔍 Фильтрация по теме: "$filterNorm"');
        filteredTips = filteredTips.where((tip) => 
            tip.topic.trim().toLowerCase() == filterNorm).toList();
        debugPrint('✅ После фильтрации: ${filteredTips.length} советов');
      }
      
      setState(() {
        allTips = filteredTips;
        displayedTips = filteredTips;
        allTasks = loadedTasks;
        isLoading = false;
      });
      
      debugPrint('🎉 Загрузка завершена!');
      debugPrint('📊 Советов на экране: ${displayedTips.length}');
      debugPrint('📊 Задач загружено: ${allTasks.length}');
      
    } catch (e) {
      debugPrint('❌ Ошибка загрузки: $e');
      setState(() {
        error = 'Ошибка загрузки данных: $e';
        isLoading = false;
      });
    }
  }

  void _toggleFavorite(Tip tip) async {
    final newFavoriteStatus = !tip.isFavorite;
    
    setState(() {
      tip.isFavorite = newFavoriteStatus;
    });
    
    await TaskStatusManager.instance.toggleFavorite(
      tip.tipKey, 
      !newFavoriteStatus
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              newFavoriteStatus ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              newFavoriteStatus 
                ? 'Добавлено в избранное' 
                : 'Удалено из избранного',
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: newFavoriteStatus ? Colors.red : Colors.grey,
      ),
    );
  }

  void _openTasksByTopic(String topic) {
    debugPrint('🔍 Поиск тестов по теме: "$topic"');
    final normalizedTopic = topic.trim().toLowerCase();
    final topicTasks = allTasks.values.where((task) => 
      task.topic.trim().toLowerCase() == normalizedTopic
    ).toList();
    
    if (topicTasks.isEmpty) {
      debugPrint('❌ Тестов по теме "$topic" не найдено');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Нет тестов по теме "$topic"'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    debugPrint('✅ Найдено тестов: ${topicTasks.length}');
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

  void _updateTipStatus(String tipKey, int status) {
    if (!mounted) return;
    
    setState(() {
      final index = displayedTips.indexWhere((tip) => tip.tipKey == tipKey);
      if (index != -1) {
        displayedTips[index].status = status;
      }
    });
    
    TaskStatusManager.instance.updateTipStatus(tipKey, status);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Загрузка советов...'),
            ],
          ),
        ),
      );
    }
    
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Ошибка: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAllData,
                child: const Text('Повторить загрузку'),
              ),
            ],
          ),
        ),
      );
    }

    final currentTopic = widget.topicName ?? 
                        (displayedTips.isNotEmpty ? displayedTips.first.topic : 'Неизвестная тема');
    
    debugPrint('🎯 Текущая тема: "$currentTopic"');

    return CommonScaffold(
      title: currentTopic,
      body: Column(
        children: [
          // 🔍 ПОИСКОВАЯ ПАНЕЛЬ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Поиск советов...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[500]
                                : Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        cursorColor: Theme.of(context).primaryColor,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) {
                          // Обработка происходит через listener
                        },
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        onPressed: _clearSearch,
                        icon: Icon(
                          Icons.clear,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        tooltip: 'Очистить поиск',
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 📊 СТАТИСТИКА ПОИСКА
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Найдено советов: ${displayedTips.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),   
                ],
              ),
            ),

          // 📱 СПИСОК СОВЕТОВ
          Expanded(
            child: Stack(
              children: [
                if (displayedTips.isEmpty && _searchQuery.isNotEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Советы не найдены',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Попробуйте изменить поисковый запрос',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[500]
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _clearSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Очистить поиск'),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: displayedTips.length,
                  itemBuilder: (context, idx) {
                    final tip = displayedTips[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _toggleFavorite(tip),
                              icon: Icon(
                                tip.isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: tip.isFavorite ? Colors.red : Colors.grey,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              tooltip: tip.isFavorite 
                                  ? 'Удалить из избранного' 
                                  : 'Добавить в избранное',
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                        title: Text(
                          tip.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Уровень: ${tip.level} • Тема: ${tip.topic}'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tip.status == 1 
                                        ? Colors.green.shade100 
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        tip.status == 1 ? Icons.check : Icons.remove,
                                        size: 12,
                                        color: tip.status == 1 ? Colors.green : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        tip.status == 1 ? 'Прочитано' : 'Не прочитано',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: tip.status == 1 ? Colors.green : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (tip.isFavorite) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.favorite,
                                          size: 12,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Избранное',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TipDetailScreen(
                                tipKey: tip.tipKey,
                                tip: tip,
                                onStatusChanged: _updateTipStatus,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) {
                              setState(() {});
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
                
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Visibility(
                    visible: displayedTips.isNotEmpty && _searchQuery.isEmpty,
                    child: FloatingActionButton.extended(
                      onPressed: () => _openTasksByTopic(currentTopic),
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Проверить знания'),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      heroTag: 'to_tests_fab',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}