import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tip.dart';
import 'package:flutter/foundation.dart';
class TipStatusManager {
  static final TipStatusManager _instance = TipStatusManager._internal();
  factory TipStatusManager() => _instance;
  TipStatusManager._internal();

  static const String _tipStatusesKey = 'tip_statuses';

  Future<void> applyTipStatuses(Map<String, Tip> tips) async {
    final prefs = await SharedPreferences.getInstance();
    final savedStatusesStr = prefs.getString(_tipStatusesKey) ?? '{}';
    
    debugPrint("📖 SharedPreferences ЧИТАЕМ (tips): $savedStatusesStr");
    
    final savedStatuses = json.decode(savedStatusesStr) as Map<String, dynamic>;
    debugPrint("📖 SharedPreferences ПАРСИМ (tips): $savedStatuses");
    
    for (final entry in tips.entries) {
      final tipKey = entry.key;
      if (savedStatuses.containsKey(tipKey)) {
        debugPrint("🔍 Ищем статус tip по KEY: $tipKey");
        entry.value.status = savedStatuses[tipKey];
        debugPrint("🔍 ✅ НАЙДЕН tip по ключу '$tipKey' → статус ${entry.value.status}");
      }
    }
  }

  Future<void> updateTipStatus(String tipKey, int status) async {
    final prefs = await SharedPreferences.getInstance();
    final savedStatusesStr = prefs.getString(_tipStatusesKey) ?? '{}';
    final savedStatuses = json.decode(savedStatusesStr) as Map<String, dynamic>;
    
    savedStatuses[tipKey] = status;
    await prefs.setString(_tipStatusesKey, json.encode(savedStatuses));
    
    debugPrint("💾 СОХРАНЕН tip статус: $tipKey → $status");
  }

  static TipStatusManager get instance => _instance;
}
