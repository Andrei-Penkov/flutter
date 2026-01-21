import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'screens/tasks_topics_screen.dart';
import 'screens/tips_topics_screen.dart';
import 'screens/stats_screen.dart';
import 'package:provider/provider.dart';
import 'managers/theme_manager.dart'; 
import 'screens/favorites_tips_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await ThemeManager.instance.loadTheme();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeManager.instance,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return MaterialApp(
          title: 'Тренажёр',
          theme: _lightTheme(),
          darkTheme: _darkTheme(), 
          themeMode: themeManager.themeMode,
          
          debugShowCheckedModeBanner: false,
          home: const MainScreen(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/tasks_topics':
                return MaterialPageRoute(builder: (_) => const TasksTopicsScreen());
              case '/tips_topics':
                return MaterialPageRoute(builder: (_) => const TipsTopicsScreen());
              case '/stats':
                return MaterialPageRoute(builder: (_) => const StatsScreen());
              case '/favorites_tips':
                return MaterialPageRoute(builder: (_) => const FavoritesTipsScreen());
              default:
                return MaterialPageRoute(builder: (_) => const MainScreen());
            }
          },
        );
      },
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF212121),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

}
