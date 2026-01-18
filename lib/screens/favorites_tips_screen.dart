// screens/favorites_tips_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../managers/task_status_manager.dart';
import '../models/tip.dart';
import '../screens/tips_detail_screen.dart';
import '../widgets/common_scaffold.dart';

class FavoritesTipsScreen extends StatefulWidget {
  const FavoritesTipsScreen({super.key});

  @override
  State<FavoritesTipsScreen> createState() => _FavoritesTipsScreenState();
}

class _FavoritesTipsScreenState extends State<FavoritesTipsScreen> {
  List<Tip> favoriteTips = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      debugPrint('📥 Загрузка избранных советов...');
      
      // Загружаем все советы
      final data = await rootBundle.loadString('assets/tips.txt');
      final tipJson = json.decode(data) as Map<String, dynamic>;
      
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

      // Фильтруем только избранные
      final favorites = tipMap.values.where((tip) => tip.isFavorite).toList();
      
      // Сортируем по теме для удобства
      favorites.sort((a, b) => a.topic.compareTo(b.topic));
      
      setState(() {
        favoriteTips = favorites;
        isLoading = false;
      });
      
      debugPrint('✅ Загружено избранных советов: ${favoriteTips.length}');
    } catch (e) {
      debugPrint('❌ Ошибка загрузки избранных: $e');
      setState(() {
        error = 'Ошибка загрузки избранных советов: $e';
        isLoading = false;
      });
    }
  }

  void _toggleFavorite(Tip tip) async {
    final newFavoriteStatus = !tip.isFavorite;
    
    setState(() {
      tip.isFavorite = newFavoriteStatus;
      if (!newFavoriteStatus) {
        // Если убираем из избранного, удаляем из списка
        favoriteTips.removeWhere((t) => t.tipKey == tip.tipKey);
      }
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

  void _updateTipStatus(String tipKey, int status) {
    if (!mounted) return;
    
    setState(() {
      final index = favoriteTips.indexWhere((tip) => tip.tipKey == tipKey);
      if (index != -1) {
        favoriteTips[index].status = status;
      }
    });
    
    TaskStatusManager.instance.updateTipStatus(tipKey, status);
  }

  // Группируем советы по темам
  Map<String, List<Tip>> _groupByTopic() {
    final groups = <String, List<Tip>>{};
    
    for (final tip in favoriteTips) {
      groups.putIfAbsent(tip.topic, () => []).add(tip);
    }
    
    return groups;
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
              Text('Загрузка избранных советов...'),
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
                onPressed: _loadFavorites,
                child: const Text('Повторить загрузку'),
              ),
            ],
          ),
        ),
      );
    }

    final tipsByTopic = _groupByTopic();
    final hasFavorites = favoriteTips.isNotEmpty;

    return CommonScaffold(
      title: 'Избранные советы',
      body: hasFavorites
          ? ListView(
              children: [
                // Общая статистика
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Всего избранных советов',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '${favoriteTips.length}',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Сгруппировано по ${tipsByTopic.length} темам',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Список по темам
                ...tipsByTopic.entries.map((entry) {
                  final topic = entry.key;
                  final tips = entry.value;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Заголовок темы
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    topic,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${tips.length}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Разделитель
                          const Divider(height: 1),
                          
                          // Список советов
                          ...tips.map((tip) {
                            return ListTile(
                              title: Text(tip.name),
                              subtitle: Text('Уровень: ${tip.level}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _toggleFavorite(tip),
                                    icon: Icon(
                                      Icons.favorite,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    tooltip: 'Удалить из избранного',
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    tip.status == 1 ? Icons.check_circle : Icons.circle_outlined,
                                    color: tip.status == 1 ? Colors.green : Colors.grey,
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
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 80), // Отступ для FAB если есть
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Нет избранных советов',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Добавляйте советы в избранное, нажимая на иконку ♡ в списке советов',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Возвращаемся к списку советов
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('К списку советов'),
                  ),
                ],
              ),
            ),
    );
  }
}