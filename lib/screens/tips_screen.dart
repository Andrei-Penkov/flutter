import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tip.dart';
import '../screens/tips_detail_screen.dart';
import '../widgets/common_scaffold.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  Map<String, Tip> tips = {};        // Словарь советов
  bool isLoading = true;             // Флаг загрузки данных
  String? error;                    // Сообщение об ошибке загрузки
  static const String tipStatusKey = 'tip_statuses'; // Ключ для кеша статусов

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  // Загрузка советов из JSON и применение сохранённых статусов
  Future<void> _loadTips() async {
    try {
      final data = await rootBundle.loadString('assets/tips.txt');
      final tipJson = json.decode(data) as Map<String, dynamic>;
      final loadedTips = tipJson.map((k, v) => MapEntry(k, Tip.fromJson(v)));

      // Получение экземпляра SharedPreferences для чтения статусов
      final prefs = await SharedPreferences.getInstance();
      final savedTipStatuses = prefs.getString(tipStatusKey) ?? '{}';
      final tipStatusesMap = json.decode(savedTipStatuses) as Map<String, dynamic>;

      // Применение статусов из кеша к загруженным советам
      for (final key in loadedTips.keys) {
        if (tipStatusesMap.containsKey(key)) {
          loadedTips[key]!.status = tipStatusesMap[key];
        }
      }

      // Обновление состояния
      setState(() {
        tips = loadedTips;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Ошибка загрузки советов: $e';
        isLoading = false;
      });
    }
  }

  // Сохранение текущих статусов советов в SharedPreferences
  Future<void> _saveTipStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (var e in tips.entries) e.key: e.value.status};
    await prefs.setString(tipStatusKey, json.encode(map));
  }

  // Обновление статуса конкретного совета с последующим сохранением
  void _updateTipStatus(String key, int status) async {
    setState(() {
      tips[key]?.status = status;
    });
    await _saveTipStatuses();
  }

  @override
  Widget build(BuildContext context) {
    // Если происходит загрузка
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Если есть ошибка
    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }
    // Основной Scaffold с заголовком и списком советов
    return CommonScaffold(
      title: 'Советы',
      body: ListView.builder(
        itemCount: tips.length,
        itemBuilder: (context, idx) {
          final key = tips.keys.elementAt(idx);
          final tip = tips[key]!;
          return ListTile(
            title: Text(tip.name),
            subtitle: Text(
                'Уровень: ${tip.level} | Статус: ${tip.status == 1 ? "Прочитано" : "Не прочитано"}'),
            trailing: ElevatedButton(
              child: const Text('Прочитать'),
              onPressed: () {
                // Навигация к экрану просмотра совета с коллбэком для отметки как прочитано
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TipDetailScreen(
                              tipKey: key,
                              tip: tip,
                              onStatusChanged: (status) =>
                                  _updateTipStatus(key, status),
                            )));
              },
            ),
          );
        },
      ),
    );
  }
}
