import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/theme_manager.dart';
import '../screens/tasks_topics_screen.dart';
import '../screens/tips_topics_screen.dart';
import '../models/task.dart';
import '../models/tip.dart';

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
    final currentRoute = ModalRoute.of(context)?.settings.name;
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
                isActive: currentRoute == '/',
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
                isActive: currentRoute == '/tasks_topics',
                activeColor: activeColor,
                iconColor: iconColor,
                onTap: () => _navigateSafely(
                  context, 
                  const TasksTopicsScreen(), 
                  '/tasks_topics'
                ),
              ),
              
              // Советы
              _buildNavItem(
                context,
                icon: Icons.auto_stories_outlined,
                label: 'Советы',
                isActive: currentRoute == '/tips_topics',
                activeColor: activeColor,
                iconColor: iconColor,
                onTap: () => _navigateSafely(
                  context, 
                  const TipsTopicsScreen(), 
                  '/tips_topics'
                ),
              ),
              
              // Статистика
              _buildNavItem(
                context,
                icon: Icons.bar_chart,
                label: 'Статистика',
                isActive: currentRoute == '/stats',
                activeColor: activeColor,
                iconColor: iconColor,
                onTap: () => Navigator.pushNamed(context, '/stats'),
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
    required bool isActive,
    required Color activeColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: isActive ? activeColor : iconColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isActive ? activeColor : iconColor,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateSafely(BuildContext context, Widget targetScreen, String routeName) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    if (currentRoute == routeName) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetScreen),
    );
  }
}