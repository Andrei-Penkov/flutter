import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'package:flutter/foundation.dart';
import '../models/tip.dart';

class TaskStatusManager {
  static const String _taskStatusKey = 'task_statuses';
  static const String _tipStatusKey = 'tip_statuses';
  static TaskStatusManager? _instance;
  static TaskStatusManager get instance => _instance ??= TaskStatusManager._();
  static const String _favoritesKey = 'favorite_tips';
  TaskStatusManager._();

  Future<Map<String, int>> getAllTaskStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_taskStatusKey) ?? '{}';
    debugPrint('📖 SharedPreferences ЧИТАЕМ (tasks): $saved');
    final result = Map<String, int>.from(
      (json.decode(saved) as Map).map((k, v) => MapEntry(k, v as int))
    );
    debugPrint('📖 SharedPreferences ПАРСИМ (tasks): $result');
    return result;
  }

  Future<Map<String, int>> getAllTipStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_tipStatusKey) ?? '{}';
    debugPrint('📖 SharedPreferences ЧИТАЕМ (tips): $saved');
    final result = Map<String, int>.from(
      (json.decode(saved) as Map).map((k, v) => MapEntry(k, v as int))
    );
    debugPrint('📖 SharedPreferences ПАРСИМ (tips): $result');
    return result;
  }

  Future<void> updateTaskStatus(String taskId, int status) async {
    debugPrint('💾 СОХРАНЯЕМ task "$taskId" = $status');
    final prefs = await SharedPreferences.getInstance();
    final statuses = await getAllTaskStatuses();
    statuses[taskId] = status;
    final jsonString = json.encode(statuses);
    debugPrint('💾 JSON tasks: $jsonString');
    final success = await prefs.setString(_taskStatusKey, jsonString);
    debugPrint('💾 ✅ Task СОХРАНЕНИЕ: $success');
  }

  Future<void> updateTipStatus(String tipId, int status) async {
    debugPrint('💾 СОХРАНЯЕМ tip "$tipId" = $status');
    final prefs = await SharedPreferences.getInstance();
    final statuses = await getAllTipStatuses();
    statuses[tipId] = status;
    final jsonString = json.encode(statuses);
    debugPrint('💾 JSON tips: $jsonString');
    final success = await prefs.setString(_tipStatusKey, jsonString);
    debugPrint('💾 ✅ Tip СОХРАНЕНИЕ: $success');
  }

  Future<void> applyTaskStatuses(Map<String, Task> tasks) async {
    debugPrint('🔄 Применяем статусы к ${tasks.length} задачам');
    final statuses = await getAllTaskStatuses();
    debugPrint('🔄 Найдено task статусов: ${statuses.length}');
    
    int updated = 0;
    for (final taskId in tasks.keys) {
      if (statuses.containsKey(taskId)) {
        debugPrint('🔄 ✅ Task "$taskId": ${statuses[taskId]}');
        tasks[taskId]!.status = statuses[taskId]!;
        updated++;
      } else {
        debugPrint('🔄 ❌ Task статус НЕ найден: "$taskId"');
      }
    }
    debugPrint('🔄 Итого tasks обновлено: $updated/${tasks.length}');
  }

  Future<void> applyTipStatuses(Map<String, Tip> tips) async {
    final statuses = await getAllTipStatuses();
    
    int updated = 0;
    for (final tipId in tips.keys) {
      debugPrint('🔍 Ищем tip статус по KEY: "$tipId"');
      if (statuses.containsKey(tipId)) {
        tips[tipId]!.status = statuses[tipId]!;
        debugPrint('🔍 ✅ ✅ ПРИМЕНЁН tip "$tipId" → ${tips[tipId]!.status}');
        updated++;
      } else {
        debugPrint('🔍 ❌ Tip статус НЕ найден для "$tipId"');
      }
    }
    debugPrint('🔄 Итого tips обновлено: $updated/${tips.length}');
  }
  
  Future<void> applyTaskStatusesByName(Map<String, Task> tasks) async {
    final statuses = await getAllTaskStatuses();
    if (kDebugMode) debugPrint('🔍 Ищем task статусы по NAME: ${statuses.keys}');
    
    int updated = 0;
    for (final taskEntry in tasks.entries) {
      final taskId = taskEntry.key;
      final task = taskEntry.value;
      
      final statusKey = statuses.keys.firstWhere(
        (key) => key == task.name,
        orElse: () => '',
      );
      
      if (statusKey.isNotEmpty && statuses.containsKey(statusKey)) {
        if (kDebugMode) {
          debugPrint('🔍 ✅ Task по имени "${task.name}" → ${statuses[statusKey]}');
        }
        task.status = statuses[statusKey]!;
        updated++;
      }
    }
    if (kDebugMode) debugPrint('🔄 Tasks по имени обновлено: $updated');
  }
  // Получить все избранные советы
  Future<Set<String>> getFavoriteTips() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesString = prefs.getString(_favoritesKey) ?? '';
    
    if (favoritesString.isEmpty) {
      return <String>{};
    }
    
    final favoritesList = favoritesString.split(',').where((key) => key.isNotEmpty).toSet();
    debugPrint('📖 Избранные советы: $favoritesList');
    return favoritesList;
  }

  // Добавить совет в избранное
  Future<void> addToFavorites(String tipKey) async {
    debugPrint('💾 Добавляем в избранное: "$tipKey"');
    final favorites = await getFavoriteTips();
    favorites.add(tipKey);
    await _saveFavorites(favorites);
  }

  // Удалить совет из избранного
  Future<void> removeFromFavorites(String tipKey) async {
    debugPrint('💾 Удаляем из избранного: "$tipKey"');
    final favorites = await getFavoriteTips();
    favorites.remove(tipKey);
    await _saveFavorites(favorites);
  }

  // Переключить статус избранного
  Future<void> toggleFavorite(String tipKey, bool isCurrentlyFavorite) async {
    if (isCurrentlyFavorite) {
      await removeFromFavorites(tipKey);
    } else {
      await addToFavorites(tipKey);
    }
  }

  // Проверить, является ли совет избранным
  Future<bool> isFavorite(String tipKey) async {
    final favorites = await getFavoriteTips();
    return favorites.contains(tipKey);
  }

  // Сохранить избранное
  Future<void> _saveFavorites(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesString = favorites.join(',');
    await prefs.setString(_favoritesKey, favoritesString);
    debugPrint('💾 Сохранены избранные: $favoritesString');
  }

  // Применить статусы избранного к советам
  Future<void> applyFavoriteStatuses(Map<String, Tip> tips) async {
    debugPrint('🔄 Применяем статусы избранного к ${tips.length} советам');
    final favorites = await getFavoriteTips();
    
    int updated = 0;
    for (final tip in tips.values) {
      final wasFavorite = tip.isFavorite;
      tip.isFavorite = favorites.contains(tip.tipKey);
      
      if (wasFavorite != tip.isFavorite) {
        updated++;
        debugPrint('🔄 Избранное для "${tip.tipKey}": ${tip.isFavorite}');
      }
    }
    debugPrint('🔄 Итого избранных обновлено: $updated');
  }
}
