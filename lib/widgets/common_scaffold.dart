import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/theme_manager.dart';
import '../screens/tasks_topics_screen.dart';
import '../screens/tips_topics_screen.dart';
import '../models/task.dart';
import '../models/tip.dart';
import '../screens/stats_screen.dart';
import '../screens/main_screen.dart';

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
                targetType: MainScreen,
                routeName: '/',
                activeColor: activeColor,
                iconColor: iconColor,
              ),
              
              // Задания
              _buildNavItem(
                context,
                icon: Icons.assignment_late_outlined,
                label: 'Задания',
                targetType: TasksTopicsScreen,
                routeName: '/tasks_topics',
                activeColor: activeColor,
                iconColor: iconColor,
              ),
              
              // Советы
              _buildNavItem(
                context,
                icon: Icons.auto_stories_outlined,
                label: 'Советы',
                targetType: TipsTopicsScreen,
                routeName: '/tips_topics',
                activeColor: activeColor,
                iconColor: iconColor,
              ),
              
              // Статистика
              _buildNavItem(
                context,
                icon: Icons.bar_chart,
                label: 'Статистика',
                targetType: StatsScreen,
                routeName: '/stats',
                activeColor: activeColor,
                iconColor: iconColor,
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
    required Type targetType,
    required String routeName,
    required Color activeColor,
    required Color iconColor,
  }) {
    // Определяем, активен ли текущий экран
    bool isActive = _isCurrentScreen(context, targetType);
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _navigateToScreen(context, targetType, routeName),
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

  // Проверяем, является ли переданный тип текущим экраном
  bool _isCurrentScreen(BuildContext context, Type targetType) {
    final currentRoute = ModalRoute.of(context);
    
    if (currentRoute == null) return false;
    
    // Если это MaterialPageRoute, проверяем builder
    if (currentRoute is MaterialPageRoute) {
      try {
        // Получаем тип виджета из route
        final builder = currentRoute.builder;
        // Чтобы получить тип, нужно вызвать builder с контекстом
        final Widget widget = builder(context);
        
        // Проверяем, соответствует ли тип виджета целевому типу
        return widget.runtimeType == targetType;
      } catch (e) {
        // Если возникла ошибка, используем альтернативный метод
        return _checkRouteNameFallback(currentRoute, targetType);
      }
    }
    
    // Для других типов routes используем альтернативную проверку
    return _checkRouteNameFallback(currentRoute, targetType);
  }

  // Альтернативная проверка по имени route
  bool _checkRouteNameFallback(ModalRoute currentRoute, Type targetType) {
    final routeSettings = currentRoute.settings;
    if (routeSettings.name == null) return false;
    
    // Сопоставляем имя route с типом экрана
    switch (targetType) {
      case MainScreen:
        return routeSettings.name == '/';
      case TasksTopicsScreen:
        return routeSettings.name == '/tasks_topics';
      case TipsTopicsScreen:
        return routeSettings.name == '/tips_topics';
      case StatsScreen:
        return routeSettings.name == '/stats';
      default:
        return false;
    }
  }

  void _navigateToScreen(BuildContext context, Type targetType, String routeName) {
    // Проверяем, не находимся ли мы уже на этом экране
    if (_isCurrentScreen(context, targetType)) {
      return; // Уже на этом экране, ничего не делаем
    }
    
    // Создаем целевой экран в зависимости от типа
    Widget targetScreen;
    switch (targetType) {
      case MainScreen:
        targetScreen = const MainScreen();
        break;
      case TasksTopicsScreen:
        targetScreen = const TasksTopicsScreen();
        break;
      case TipsTopicsScreen:
        targetScreen = const TipsTopicsScreen();
        break;
      case StatsScreen:
        targetScreen = const StatsScreen();
        break;
      default:
        targetScreen = const MainScreen();
    }
    
    // Если это главный экран, очищаем всю навигацию
    if (routeName == '/') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => targetScreen),
        (route) => false,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => targetScreen),
      );
    }
  }
}