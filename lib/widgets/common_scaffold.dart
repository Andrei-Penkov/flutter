import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/theme_manager.dart';
import '../screens/tasks_topics_screen.dart';
import '../screens/tips_topics_screen.dart';
import '../models/task.dart';
import '../models/tip.dart';
import '../screens/stats_screen.dart';

class CommonScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback? onHome;
  final List<Task>? allTasksList;
  final List<Tip>? allTipsList;

  const CommonScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onHome,
    this.allTasksList,
    this.allTipsList,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        final themeMode = themeManager.themeMode;
        final isDarkMode = themeMode == ThemeMode.dark;
        
        // Цвета для темной/светлой темы
        final backgroundColor = isDarkMode 
            ? Colors.grey[900] 
            : Colors.white;
        final containerColor = isDarkMode 
            ? Colors.grey[800] 
            : Colors.grey[100];
        final borderColor = isDarkMode 
            ? Colors.grey[700] 
            : Colors.grey[300];
        final iconColor = isDarkMode 
            ? Colors.white70 
            : Colors.black87;
        final activeColor = Colors.blue;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              // Кнопка смены темы в AppBar
              IconButton(
                icon: Icon(
                  isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: isDarkMode ? Colors.amber : Colors.grey[700],
                ),
                tooltip: isDarkMode ? 'Светлая тема' : 'Тёмная тема',
                onPressed: () => themeManager.toggleTheme(),
              ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: body,
          ),
          bottomNavigationBar: _buildBottomNavigationBar(
            context, 
            themeManager,
            backgroundColor: backgroundColor!,
            containerColor: containerColor!,
            borderColor: borderColor!,
            iconColor: iconColor,
            activeColor: activeColor,
          ),
        );
      },
    );
  }

  Container _buildBottomNavigationBar(
    BuildContext context, 
    ThemeManager themeManager, {
    required Color backgroundColor,
    required Color containerColor,
    required Color borderColor,
    required Color iconColor,
    required Color activeColor,
  }) {
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    return Container(
      height: 80 + safeAreaBottom,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: safeAreaBottom + 8,
        ),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Домой
              _buildNavItem(
                context,
                icon: Icons.home,
                label: 'Домой',
                screenType: 'home', // Используем строковые идентификаторы
                activeColor: activeColor,
                iconColor: iconColor,
                onTap: () {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                },
              ),
              
              // Задания
              _buildNavItem(
                context,
                icon: Icons.assignment_late_outlined,
                label: 'Задания',
                screenType: 'tasks',
                activeColor: activeColor,
                iconColor: iconColor,
                onTap: () => _navigateSafely(
                  context, 
                  const TasksTopicsScreen(), 
                  'tasks'
                ),
              ),
              
              // Советы
              _buildNavItem(
                context,
                icon: Icons.auto_stories_outlined,
                label: 'Советы',
                screenType: 'tips',
                activeColor: activeColor,
                iconColor: iconColor,
                onTap: () => _navigateSafely(
                  context, 
                  const TipsTopicsScreen(), 
                  'tips'
                ),
              ),
              
              // Статистика
              _buildNavItem(
                context,
                icon: Icons.bar_chart,
                label: 'Статистика',
                screenType: 'stats',
                activeColor: activeColor,
                iconColor: iconColor,
                onTap: () => _navigateSafely(
                  context, 
                  const StatsScreen(), // Нужно импортировать StatsScreen
                  'stats'
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String screenType,
    required Color activeColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    // Определяем активный экран по типу текущего виджета body
    bool isActive = _isScreenActive(context, screenType);
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          splashColor: activeColor.withOpacity(0.2),
          highlightColor: activeColor.withOpacity(0.1),
          child: Container(
            decoration: isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: activeColor.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.15),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: isActive
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeColor.withOpacity(0.1),
                        )
                      : null,
                  child: Icon(
                    icon,
                    size: isActive ? 26 : 24,
                    color: isActive ? activeColor : iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isActive ? activeColor : iconColor,
                    fontSize: isActive ? 11 : 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isScreenActive(BuildContext context, String screenType) {
    // Проверяем тип текущего экрана
    switch (screenType) {
      case 'home':
        // Для главного экрана - проверяем, не находимся ли мы на каком-то из других экранов
        final currentRoute = ModalRoute.of(context);
        if (currentRoute != null) {
          final routeSettings = currentRoute.settings;
          // Если route имеет имя, отличное от '/', значит это не главный экран
          if (routeSettings.name != null && routeSettings.name != '/') {
            return false;
          }
        }
        // Проверяем, какой виджет сейчас отображается
        return _getCurrentScreenType(context) == 'home';
      
      case 'tasks':
        return _getCurrentScreenType(context) == 'tasks';
      
      case 'tips':
        return _getCurrentScreenType(context) == 'tips';
      
      case 'stats':
        return _getCurrentScreenType(context) == 'stats';
      
      default:
        return false;
    }
  }

  String _getCurrentScreenType(BuildContext context) {
    // Проходим по дереву виджетов и определяем тип текущего экрана
    final widgetType = body.runtimeType.toString();
    
    // Определяем тип по названию класса виджета
    if (widgetType.contains('TasksTopicsScreen') || 
        widgetType.contains('Task') && !widgetType.contains('Home')) {
      return 'tasks';
    } else if (widgetType.contains('TipsTopicsScreen') || 
               widgetType.contains('Tip') && !widgetType.contains('Home')) {
      return 'tips';
    } else if (widgetType.contains('StatsScreen') || 
               widgetType.contains('Stat')) {
      return 'stats';
    } else {
      // По умолчанию считаем, что это главный экран
      return 'home';
    }
  }

  void _navigateSafely(BuildContext context, Widget targetScreen, String screenType) {
    // Проверяем, не находимся ли мы уже на этом экране
    if (_isScreenActive(context, screenType)) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetScreen),
    );
  }
}

// Если у вас есть StatsScreen, нужно его импортировать и использовать
// Если нет, создайте заглушку или используйте другой подход для статистики