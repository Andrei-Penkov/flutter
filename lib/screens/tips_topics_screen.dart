import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../managers/task_status_manager.dart';
import '../models/task.dart';
import '../models/tip.dart';
import '../screens/tasks_screen.dart';
import '../screens/tips_screen.dart';
import '../widgets/common_scaffold.dart';

class TipsTopicsScreen extends StatefulWidget {
  const TipsTopicsScreen({super.key});

  @override
  State<TipsTopicsScreen> createState() => _TipsTopicsScreenState();
}

class _TipsTopicsScreenState extends State<TipsTopicsScreen> {
  Map<String, Tip> allTips = {};
  Map<String, Task> tasks = {};
  Map<String, List<Tip>> tipsByTopic = {};
  bool isLoading = true;
  String? error;
  final String test = 'assets/images/topic_backgrounds/zero.png';
  
  // Для поиска
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<MapEntry<String, List<Tip>>> _filteredTopics = [];

  // Список фоновых изображений для карточек
  final Map<String, String> topicBackgrounds = {
    'портрет': 'assets/images/topic_backgrounds/portret.png',
    'основа': 'assets/images/topic_backgrounds/photo_zero.png',
  };

  @override
  void initState() {
    super.initState();
    loadTips();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _refreshTipsData() async {
    try {
      // Перезагружаем статусы советов
      await TaskStatusManager.instance.applyTipStatuses(allTips);
      
      // Пересчитываем статистику
      final Map<String, List<Tip>> updatedMapByTopic = {};
      for (var tip in allTips.values) {
        final normalizedTopic = tip.topic.trim().toLowerCase();
        updatedMapByTopic.putIfAbsent(normalizedTopic, () => []).add(tip);
      }
      
      setState(() {
        tipsByTopic = updatedMapByTopic;
        _updateFilteredTopics();
      });
    } catch (e) {
      debugPrint('❌ Ошибка обновления данных: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _updateFilteredTopics();
    });
  }

  void _updateFilteredTopics() {
    if (_searchQuery.isEmpty) {
      _filteredTopics = tipsByTopic.entries.toList();
    } else {
      _filteredTopics = tipsByTopic.entries.where((entry) {
        final topic = capitalize(entry.key).toLowerCase();
        return topic.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> loadTips() async {
    try {
      final data = await rootBundle.loadString('assets/tips.txt');
      final tipJson = json.decode(data) as Map<String, dynamic>;
      final taskJsonStr = await rootBundle.loadString('assets/tasks.txt');
      final taskJson = json.decode(taskJsonStr) as Map<String, dynamic>;
      final loadedTasks = taskJson.map((k, v) => MapEntry(k, Task.fromJson(v)));
      await TaskStatusManager.instance.applyTaskStatusesByName(loadedTasks);

      final loadedTips = <String, Tip>{};
      for (final entry in tipJson.entries) {
        final tipKey = entry.key.trim();
        if (tipKey.isNotEmpty) {
          loadedTips[tipKey] = Tip.fromJson(entry.value, key: tipKey);
        }
      }

      await TaskStatusManager.instance.applyTipStatuses(loadedTips);
      debugPrint('✅ TipsTopicsScreen: статусы применены для ${loadedTips.length} tips');

      Map<String, List<Tip>> mapByTopic = {};
      for (var tip in loadedTips.values) {
        final normalizedTopic = tip.topic.trim().toLowerCase();
        mapByTopic.putIfAbsent(normalizedTopic, () => []).add(tip);
      }

      setState(() {
        allTips = loadedTips;
        tasks = loadedTasks;
        tipsByTopic = mapByTopic;
        _filteredTopics = mapByTopic.entries.toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ TipsTopicsScreen ошибка: $e');
      setState(() {
        error = 'Ошибка загрузки советов: $e';
        isLoading = false;
      });
    }
  }

  String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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

  String _photo(String topic) {
    final lowerTopic = topic.toLowerCase();
    if (topicBackgrounds.containsKey(lowerTopic)) {
      return topicBackgrounds[lowerTopic]!;
    } else {
      return test;
    }
  }

  void _clearSearch() {
    _searchController.clear();
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
      title: 'Темы советов',
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
                          hintText: 'Поиск тем...',
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
                    'Найдено тем: ${_filteredTopics.length}',
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

          // 📱 СПИСОК КАРТОЧЕК
          Expanded(
            child: _filteredTopics.isEmpty && _searchQuery.isNotEmpty
                ? Center(
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
                          'Темы не найдены',
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
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _filteredTopics.length,
                      itemBuilder: (context, index) {
                        final entry = _filteredTopics[index];
                        final displayTopic = capitalize(entry.key);
                        final tipsCount = entry.value.length;
                        final completedCount =
                            entry.value.where((tip) => tip.status == 1).length;
                        final progress = tipsCount > 0 ? completedCount / tipsCount : 0.0;
                        final backgroundImage = _photo(displayTopic);

                        return _buildTopicCardWithImage(
                          context,
                          displayTopic,
                          tipsCount,
                          completedCount,
                          progress,
                          entry.value,
                          backgroundImage,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Карточка с фоновым изображением
  Widget _buildTopicCardWithImage(
    BuildContext context,
    String topic,
    int totalTips,
    int completedTips,
    double progress,
    List<Tip> tips,
    String backgroundImage,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TipsScreen(
              tips: tips,
              topicName: topic,
            ),
          ),
        ).then((_) {
          _refreshTipsData();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Фоновое изображение
              Positioned.fill(
                child: Image.asset(
                  backgroundImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueAccent.shade400,
                            Colors.purpleAccent.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Затемняющий слой для лучшей читаемости текста
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Декоративные элементы
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              
              // Содержимое карточки
              Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Верхняя часть: иконка и счетчик
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_stories,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$totalTips',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Название темы
                    Text(
                      topic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Прогресс бар
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          color: Colors.lightGreenAccent,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 8),
                        
                        // Статистика
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$completedTips/$totalTips завершено',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}