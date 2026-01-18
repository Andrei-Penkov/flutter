import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../screens/task_test_screen.dart';
import '../widgets/common_scaffold.dart';

class TasksScreen extends StatefulWidget {
  final List<Task> tasks;
  final String topicName;

  const TasksScreen({
    super.key,
    required this.tasks,
    required this.topicName,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late List<Task> tasks;
  Map<String, int> taskStatuses = {};
  static const String taskStatusKey = 'task_statuses';
  
  // Словарь фоновых изображений для задач
  final Map<String, String> taskBackgrounds = {
    'портрет': 'assets/images/topic_backgrounds/portret.png',
    'основа': 'assets/images/topic_backgrounds/photo_zero.png',
    // Добавьте другие темы и изображения
  };
  
  // Дефолтное изображение
  final String defaultImage = 'assets/images/topic_backgrounds/zero.png';

  @override
  void initState() {
    super.initState();
    tasks = widget.tasks;
    for (var task in tasks) {
      taskStatuses[task.name] = task.status;
    }
  }

  Future<void> _saveTaskStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (var e in tasks) e.name: e.status};
    await prefs.setString(taskStatusKey, json.encode(map));
  }

  void _updateStatus(Task task, int status) async {
    setState(() {
      task.status = status;
      taskStatuses[task.name] = status;
    });
    await _saveTaskStatuses();
    
    // Показываем уведомление о выполнении
    if (status == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text('Задание "${task.name}" выполнено!'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green.shade100,
        ),
      );
    }
  }

  // Получить фоновое изображение для задачи
  String _getBackgroundImage(Task task) {
    final topic = task.topic.toLowerCase();
    
    // Прямое совпадение
    if (taskBackgrounds.containsKey(topic)) {
      return taskBackgrounds[topic]!;
    }
    
    // Частичное совпадение
    for (final entry in taskBackgrounds.entries) {
      if (topic.contains(entry.key) || task.name.toLowerCase().contains(entry.key)) {
        return entry.value;
      }
    }
    
    return defaultImage;
  }

  // Получить цвет уровня сложности
  Color _getLevelColor(int level) {
    switch (level) {
      case 1:
        return const Color.fromARGB(255, 22, 148, 26);
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red;
      case 5:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'Задания: ${widget.topicName}',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final backgroundImage = _getBackgroundImage(task);
            final levelColor = _getLevelColor(task.level);
            
            return _buildTaskCard(
              context,
              task,
              backgroundImage,
              levelColor,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    Task task,
    String backgroundImage,
    Color levelColor,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskTestScreen(
              task: task,
              onStatusChanged: (status) => _updateStatus(task, status),
            ),
          ),
        );
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
                            Colors.blue.shade800,
                            Colors.purple.shade800,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Затемняющий слой
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Декоративные элементы
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              
              // Содержимое карточки
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Верхняя часть: уровень сложности и статус
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Уровень сложности
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: levelColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: levelColor.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 5,
                                color: levelColor,
                              ),
                              const SizedBox(width: 1),
                              Text(
                                'Ур. ${task.level}',
                                style: TextStyle(
                                  color: levelColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Статус выполнения
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: task.status == 1 
                                ? const Color.fromARGB(255, 65, 6, 19).withOpacity(0.5)
                                : const Color.fromARGB(255, 70, 3, 3).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: task.status == 1 
                                  ? const Color.fromARGB(255, 2, 121, 22).withOpacity(0.5)
                                  : const Color.fromARGB(255, 3, 17, 204).withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                task.status == 1 ? Icons.check : Icons.schedule,
                                size: 1,
                                color: task.status == 1 ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.status == 1 ? 'Выполнено' : 'К выполнению',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: task.status == 1 ? const Color.fromARGB(255, 209, 243, 84) : const Color.fromARGB(255, 4, 190, 247),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Название задания
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          task.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                blurRadius: 6,
                                color: Colors.black,
                              ),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    
                    // Тема задания
                    Text(
                      task.topic,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Кнопка "Пройти"
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskTestScreen(
                                task: task,
                                onStatusChanged: (status) => _updateStatus(task, status),
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          task.status == 1 ? Icons.refresh : Icons.play_arrow,
                          size: 16,
                        ),
                        label: Text(
                          task.status == 1 ? 'Повторить' : 'Начать тест',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          backgroundColor: Colors.white.withOpacity(0.9),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
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