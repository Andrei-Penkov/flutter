import 'dart:async';
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../widgets/common_scaffold.dart';

class TaskTestScreen extends StatefulWidget {
  final Task task;
  final ValueChanged<int>? onStatusChanged;
  
  const TaskTestScreen({super.key, required this.task, this.onStatusChanged});

  @override
  State<TaskTestScreen> createState() => _TaskTestScreenState();
}

class _TaskTestScreenState extends State<TaskTestScreen> {
  late Map<String, TextEditingController> controllers; // Контроллеры для полей ответа
  String resultMessage = ''; // Текст с результатами проверки

  static const int baseTimeSeconds = 60; // Базовое количество секунд на уровень

  late int remainingSeconds; // Оставшееся время в секундах
  Timer? timer; // Таймер обратного отсчёта

  @override
  void initState() {
    super.initState();
    controllers = {for (var k in widget.task.questions.keys) k: TextEditingController()};
    remainingSeconds = baseTimeSeconds * widget.task.level;
    startTimer();
  }

  // Запуск таймера с обновлением каждую секунду
  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds <= 0) {
        timer?.cancel();
        timeExpired();
      } else {
        setState(() {
          remainingSeconds--;
        });
      }
    });
  }

  // Время истекло
  void timeExpired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Время вышло'),
        content: const Text('Время на выполнение задания истекло. Задание считается не выполненным.'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onStatusChanged?.call(0);
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }

  // Проверка ответов
  void checkAnswers() {
    timer?.cancel();
    int correct = 0;
    widget.task.questions.forEach((key, question) {
      final answer = controllers[key]?.text.trim() ?? '';
      if (answer == question.ans) correct++;
    });
    setState(() {
      resultMessage = 'Правильных ответов: $correct из ${widget.task.questions.length}';
      if (correct == widget.task.questions.length) {
        widget.onStatusChanged?.call(1); // Отмечаем задание выполненным
        resultMessage += '\nЗадание выполнено!';
      } else {
        widget.onStatusChanged?.call(0);
      }
    });
  }

  // Форматирование времени в мм:сс
  String formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Освобождение ресурсов
  @override
  void dispose() {
    timer?.cancel();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Построение экрана теста
  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: widget.task.name,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Показываем оставшееся время
          Text('Оставшееся время: ${formatTime(remainingSeconds)}',
              style: const TextStyle(fontSize: 20, color: Colors.red)),
          const SizedBox(height: 16),

          // Список вопросов с возможными изображениями и полями для ввода ответа
          Expanded(
            child: ListView(
              children: widget.task.questions.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.value.que, style: const TextStyle(fontSize: 16)),

                        // Отображение изображений, если указаны
                        if (entry.value.imagePaths != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: entry.value.imagePaths!.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Image.asset(
                                    entry.value.imagePaths![index],
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        // Поле ввода для ответа
                        TextField(
                          controller: controllers[entry.key],
                          decoration: const InputDecoration(hintText: 'Введите ответ'),
                        ),
                      ]),
                );
              }).toList(),
            ),
          ),

          // Кнопка Завершить для проверки ответов
          Row(
            children: [
              const SizedBox(width: 16),
              ElevatedButton(onPressed: checkAnswers, child: const Text('Завершить')),
            ],
          ),

          const SizedBox(height: 16),

          // Отображение сообщения с результатом проверки
          Text(resultMessage,
              style: const TextStyle(fontSize: 16, color: Colors.green)),
        ]),
      ),
    );
  }
}
