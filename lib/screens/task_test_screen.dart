import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../screens/tips_screen.dart';
import '../widgets/common_scaffold.dart';
import '../managers/task_status_manager.dart';

class TaskTestScreen extends StatefulWidget {
  final Task task;
  final ValueChanged<int>? onStatusChanged;
  const TaskTestScreen({super.key, required this.task, this.onStatusChanged});

  @override
  State<TaskTestScreen> createState() => _TaskTestScreenState();
}

class _TaskTestScreenState extends State<TaskTestScreen> {
  int currentQuestionIndex = 0;
  late Map<String, TextEditingController> controllers;
  late Map<String, String?> selectedOptions;
  Map<String, bool> answerResults = {};
  Map<String, bool> showCorrectAnswers = {};
  Map<String, bool> showHintForQuestion = {};
  Map<String, bool> answerChecked = {}; // Новое: проверен ли ответ
  String resultMessage = '';
  bool showResult = false;
  
  static const int baseTimeSeconds = 60;
  late int remainingSeconds;
  Timer? timer;
  
  // ✅ КЭШ истории + состояния
  Map<String, List<PhotoHistory>> photoHistoryCache = {};
  Map<String, PhotoTaskState> photoTaskStates = {};
  Map<String, int> photoQuestionTimes = {};
  int totalPhotoTime = 0;

  // ✅ Функция для получения цвета карточек с учетом темы
  Color getCardColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? const Color(0xFF2D2D2D) // Темно-серый для темной темы
        : Colors.white; // Белый для светлой
  }

  // ✅ Функция для получения цвета текста с учетом темы
  Color getTextColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? Colors.white 
        : Colors.black87;
  }

  // ✅ Функция для получения цвета фона с учетом темы
  Color getBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? const Color(0xFF1A1A1A) // Темный фон
        : const Color(0xFFF5F5F5); // Светлый фон
  }

  // ✅ Функция для получения цвета подсветки правильного ответа
  Color getCorrectAnswerColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? const Color(0xFF1B5E20) // Темно-зеленый
        : const Color(0xFFC8E6C9); // Светло-зеленый
  }

  // ✅ Функция для получения цвета подсветки неправильного ответа
  Color getWrongAnswerColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? const Color(0xFF7F0000) // Темно-красный
        : const Color(0xFFFFCDD2); // Светло-красный
  }

  @override
  void initState() {
    super.initState();
    controllers = {for (var k in widget.task.questions.keys) k: TextEditingController()};
    selectedOptions = {for (var k in widget.task.questions.keys) k: null};
    photoTaskStates = {for (var k in widget.task.questions.keys) k: PhotoTaskState()};
    photoQuestionTimes = {for (var k in widget.task.questions.keys) k: 0};
    
    _loadPhotoHistoryCache();
    
    bool hasPhotoTasks = widget.task.questions.values.any((q) => q.isPhotoTask);
    int timeMultiplier = hasPhotoTasks ? 20 : 1;
    remainingSeconds = baseTimeSeconds * timeMultiplier * (widget.task.level > 0 ? widget.task.level : 1);
    startTimer();
  }

  Future<void> _loadPhotoHistoryCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString('photo_history_cache') ?? '{}';
      final cacheMap = json.decode(cacheString) as Map<String, dynamic>;
      
      photoHistoryCache.clear();
      cacheMap.forEach((taskKey, historyList) {
        if (historyList != null) {
          photoHistoryCache[taskKey] = (historyList as List)
              .map((h) => PhotoHistory.fromJson(h as Map<String, dynamic>))
              .toList();
        }
      });
    } catch (e) {
      photoHistoryCache.clear();
    }
    if (mounted) setState(() {});
  }

  Future<void> _savePhotoHistory(String questionKey, PhotoHistory newHistory) async {
    List<PhotoHistory> taskHistory = photoHistoryCache[widget.task.name] ?? [];
    
    taskHistory.add(newHistory);
    taskHistory = taskHistory.take(10).toList();
    
    photoHistoryCache[widget.task.name] = taskHistory;
    
    final prefs = await SharedPreferences.getInstance();
    final saveMap = <String, List<Map<String, dynamic>>>{};
    photoHistoryCache.forEach((key, history) {
      saveMap[key] = history.map((h) => h.toJson()).toList();
    });
    
    await prefs.setString('photo_history_cache', json.encode(saveMap));
  }

  List<PhotoHistory>? getPhotoHistory(String questionKey) {
    return photoHistoryCache[widget.task.name];
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds <= 0) {
        timer?.cancel();
        timeExpired();
      } else {
        if (mounted) setState(() => remainingSeconds--);
      }
    });
  }

  void timeExpired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Время вышло'),
        content: const Text('Задание не выполнено.'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onStatusChanged?.call(0);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ✅ Измененная функция nextQuestion - теперь проверяет ответ сразу
  void nextQuestion() {
    final currentQuestionKey = widget.task.questions.keys.elementAt(currentQuestionIndex);
    final currentQuestion = widget.task.questions.values.toList()[currentQuestionIndex];
    
    if (!currentQuestion.isPhotoTask) {
      // Если ответ еще не проверен
      if (!answerChecked.containsKey(currentQuestionKey) || !answerChecked[currentQuestionKey]!) {
        // Проверяем ответ для обычного вопроса
        String? selectedAnswer = selectedOptions[currentQuestionKey];
        
        if (selectedAnswer == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пожалуйста, выберите ответ'),
              duration: Duration(seconds: 1),
            ),
          );
          return;
        }
        
        bool isCorrect = selectedAnswer == currentQuestion.ans;
        
        setState(() {
          answerResults[currentQuestionKey] = isCorrect;
          showCorrectAnswers[currentQuestionKey] = true;
          answerChecked[currentQuestionKey] = true; // Помечаем как проверенный
          
          // Показываем подсказку если ответ неправильный и есть подсказка
          if (!isCorrect && currentQuestion.tip != null) {
            showHintForQuestion[currentQuestionKey] = true;
          }
        });
        
        // Меняем текст кнопки на "Далее"
      } else {
        // Если ответ уже проверен, переходим к следующему вопросу
        if (currentQuestionIndex < widget.task.questions.length - 1) {
          setState(() => currentQuestionIndex++);
        } else {
          checkAnswers();
        }
      }
    } else {
      // Для фото-вопросов просто переходим дальше
      if (currentQuestionIndex < widget.task.questions.length - 1) {
        setState(() => currentQuestionIndex++);
      } else {
        checkAnswers();
      }
    }
  }

  void previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() => currentQuestionIndex--);
    }
  }

  Future<void> _saveTaskStatuses(int status) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTaskStatuses = prefs.getString('task_statuses') ?? '{}';
    final taskStatusesMap = json.decode(savedTaskStatuses) as Map<String, dynamic>;
    taskStatusesMap[widget.task.name] = status;
    await prefs.setString('task_statuses', json.encode(taskStatusesMap));
  }

  void checkAnswers() async {
    timer?.cancel();
    int correct = 0;
    int wrong = 0;
    Map<String, bool> results = {};
    
    final currentQuestions = widget.task.questions.entries.toList();
    for (var entry in currentQuestions) {
      final key = entry.key;
      final question = entry.value;
      
      if (question.isPhotoTask) {
        // Для фото-заданий считаем, что они выполнены, если есть время
        results[key] = photoQuestionTimes[key]! > 0;
        if (photoQuestionTimes[key]! > 0) {
          correct++;
          totalPhotoTime += photoQuestionTimes[key]!;
        }
      } else {
        String answer = selectedOptions[key] ?? controllers[key]?.text.trim() ?? '';
        bool isCorrect = answer == question.ans;
        results[key] = isCorrect;
        if (isCorrect) {
          correct++;
        } else {
          wrong++;
        }
      }
    }

    final isAllCorrect = correct == widget.task.questions.length;
    
    if (mounted) {
      setState(() {
        answerResults = results;
        resultMessage = 'Правильных: $correct из ${widget.task.questions.length}';
        if (wrong > 0) {
          resultMessage += '\nНеправильных: $wrong';
        }
        if (totalPhotoTime > 0) {
          resultMessage += '\nВремя на фото-задания: ${_formatTime(totalPhotoTime)}';
        }
        showResult = true;
        
        if (isAllCorrect) {
          resultMessage += '\n✅ Задание выполнено!';
          widget.task.status = 1;
        } else {
          resultMessage += '\n❌ Задание не выполнено';
          widget.task.status = 0;
        }
      });
    }

    final status = isAllCorrect ? 1 : 0;
    widget.onStatusChanged?.call(status);
    await _saveTaskStatuses(status);
    await TaskStatusManager.instance.updateTaskStatus(widget.task.name, status);
  }

  void restartTest() {
    setState(() {
      currentQuestionIndex = 0;
      answerResults.clear();
      showCorrectAnswers.clear();
      showHintForQuestion.clear();
      answerChecked.clear(); // Очищаем проверенные ответы
      selectedOptions.updateAll((key, value) => null);
      controllers.forEach((key, controller) => controller.clear());
      photoTaskStates.updateAll((key, state) => PhotoTaskState());
      photoQuestionTimes.updateAll((key, value) => 0);
      totalPhotoTime = 0;
      resultMessage = '';
      
      bool hasPhotoTasks = widget.task.questions.values.any((q) => q.isPhotoTask);
      int timeMultiplier = hasPhotoTasks ? 20 : 1;
      remainingSeconds = baseTimeSeconds * timeMultiplier * (widget.task.level > 0 ? widget.task.level : 1);
      
      showResult = false;
      startTimer();
    });
  }

  String formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return '$seconds сек';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes мин ${remainingSeconds} сек';
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _openTipsByTopic(String topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TipsScreen(filterTopic: topic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.task.questions.values.toList();
    final currentQuestionKey = widget.task.questions.keys.elementAt(currentQuestionIndex);
    final currentQuestion = questions[currentQuestionIndex];
    final selectedAnswer = selectedOptions[currentQuestionKey];
    final isPhotoTask = currentQuestion.isPhotoTask;
    final showCorrect = showCorrectAnswers[currentQuestionKey] ?? false;
    final showHint = showHintForQuestion[currentQuestionKey] ?? false;
    final isAnswerChecked = answerChecked[currentQuestionKey] ?? false;

    if (showResult) {
      return _buildResultsScreen(context);
    }

    return CommonScaffold(
      title: '${widget.task.name} (${currentQuestionIndex + 1}/${questions.length})',
      body: Container(
        color: getBackgroundColor(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Таймер + прогресс
              _buildTimerProgress(context, questions.length),
              const SizedBox(height: 20),

              if (!isPhotoTask) ...[
                // Quiz вопрос
                _buildQuestionCard(context, currentQuestion),
                const SizedBox(height: 20),

                // Подсказка если был неправильный ответ
                if (showHint && currentQuestion.tip != null)
                  _buildHintCard(context, currentQuestion.tip!),

                // Quiz варианты
                _buildOptionsList(context, currentQuestionKey, currentQuestion, selectedAnswer, showCorrect),
              ] else ...[
                _buildPhotoTask(currentQuestionKey, currentQuestion),
              ],

              const SizedBox(height: 30),

              if (!isPhotoTask)
                _buildNavigationButtons(context, questions.length, isAnswerChecked),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen(BuildContext context) {
    final questions = widget.task.questions.values.toList();
    final isAllCorrect = answerResults.values.every((v) => v);
    final wrongQuestions = widget.task.questions.entries
        .where((entry) => !answerResults[entry.key]! && !entry.value.isPhotoTask)
        .toList();
    final photoHistory = getPhotoHistory('') ?? [];

    return CommonScaffold(
      title: 'Результаты: ${widget.task.name}',
      body: Container(
        color: getBackgroundColor(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Главный результат
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isAllCorrect
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : [Colors.amber.shade400, Colors.amber.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      isAllCorrect ? '🎉 Отлично!' : '📚 Повтори материал!',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${answerResults.values.where((v) => v).length}/${questions.length}',
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      resultMessage,
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Статистика по фото-заданиям
              if (totalPhotoTime > 0) ...[
                _buildPhotoStatisticsCard(context, photoHistory),
                const SizedBox(height: 20),
              ],

              // Неправильные вопросы
              if (wrongQuestions.isNotEmpty) ...[
                _buildWrongQuestionsCard(context, wrongQuestions),
                const SizedBox(height: 20),
              ],

              // Рекомендация повторить материал
              if (!isAllCorrect) ...[
                _buildRecommendationCard(context),
                const SizedBox(height: 20),
              ],

              // Кнопки
              _buildResultButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerProgress(BuildContext context, int totalQuestions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: (currentQuestionIndex + 1) / totalQuestions,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              formatTime(remainingSeconds),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, Question question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            question.que!,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: getTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          if (question.imagePaths != null && question.imagePaths!.isNotEmpty) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: question.imagePaths!.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      question.imagePaths![index],
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 110,
                        width: 100,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHintCard(BuildContext context, String hint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getWrongAnswerColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: getTextColor(context)),
              const SizedBox(width: 8),
              Text(
                'Подсказка:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: getTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(
              fontSize: 14,
              color: getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList(BuildContext context, String questionKey, Question question, 
                          String? selectedAnswer, bool showCorrect) {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        itemCount: question.options!.length,
        itemBuilder: (context, index) {
          final option = question.options![index];
          final isSelected = selectedAnswer == option;
          final isCorrectOption = option == question.ans;
          
          Color backgroundColor = getCardColor(context);
          Color borderColor = Colors.transparent;
          Color textColor = getTextColor(context);
          FontWeight fontWeight = FontWeight.normal;

          if (showCorrect) {
            if (isSelected) {
              if (isCorrectOption) {
                backgroundColor = getCorrectAnswerColor(context);
                borderColor = Colors.green;
                textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
                fontWeight = FontWeight.bold;
              } else {
                backgroundColor = getWrongAnswerColor(context);
                borderColor = Colors.red;
                textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
              }
            } else if (isCorrectOption) {
              backgroundColor = getCorrectAnswerColor(context);
              borderColor = Colors.green;
              textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
              fontWeight = FontWeight.bold;
            }
          }

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: borderColor != Colors.transparent 
                  ? [BoxShadow(color: borderColor.withOpacity(0.2), blurRadius: 4)]
                  : null,
            ),
            child: RadioListTile<String>(
              title: Text(
                option,
                style: TextStyle(
                  color: textColor,
                  fontWeight: fontWeight,
                ),
              ),
              value: option,
              groupValue: selectedAnswer,
              onChanged: showCorrect
                  ? null
                  : (value) {
                      setState(() => selectedOptions[questionKey] = value);
                    },
              activeColor: Colors.blue,
              tileColor: Colors.transparent,
            ),
          );
        },
      ),
    );
  }

  // ✅ Измененный метод _buildNavigationButtons с учетом проверки ответа
  Widget _buildNavigationButtons(BuildContext context, int totalQuestions, bool isAnswerChecked) {
    final currentQuestionKey = widget.task.questions.keys.elementAt(currentQuestionIndex);
    final hasAnswer = selectedOptions[currentQuestionKey] != null;
    final isLastQuestion = currentQuestionIndex == totalQuestions - 1;
    
    String buttonText;
    if (!isAnswerChecked) {
      buttonText = isLastQuestion ? 'Завершить' : 'Проверить';
    } else {
      buttonText = isLastQuestion ? 'Завершить тест' : 'Далее';
    }

    return Row(
      children: [
        if (currentQuestionIndex > 0)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: previousQuestion,
              icon: const Icon(Icons.arrow_back_ios),
              label: const Text('Назад'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (currentQuestionIndex > 0) const SizedBox(width: 12),
        Expanded(
          flex: currentQuestionIndex > 0 ? 1 : 2,
          child: ElevatedButton.icon(
            onPressed: hasAnswer ? nextQuestion : null,
            icon: Icon(isAnswerChecked ? Icons.arrow_forward_ios : Icons.check),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: isAnswerChecked ? Colors.blue.shade500 : Colors.green.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoStatisticsCard(BuildContext context, List<PhotoHistory> history) {
  // Сортируем историю по времени (от лучшего к худшему)
  final sortedHistory = [...history]..sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
  final bestResults = sortedHistory.where((h) => h.timeSeconds > 0).take(3).toList();
  
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: getCardColor(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.blue.shade100),
      boxShadow: [
        BoxShadow(
          color: Colors.blue.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              'Статистика фото-заданий',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: getTextColor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Общее время: ${_formatTime(totalPhotoTime)}',
          style: TextStyle(
            fontSize: 16,
            color: getTextColor(context),
          ),
        ),
        const SizedBox(height: 12),
        if (bestResults.isNotEmpty) ...[
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Лучшие результаты:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: getTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          // Здесь создаем список Widget из истории
          ...bestResults.map((record) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      record.date,
                      style: TextStyle(color: getTextColor(context).withOpacity(0.7)),
                    ),
                    Text(
                      record.formattedTime,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )).toList(), // Преобразуем в List<Widget>
        ],
      ],
    ),
  );
}

  Widget _buildWrongQuestionsCard(BuildContext context, List<MapEntry<String, Question>> wrongQuestions) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: getWrongAnswerColor(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.red.shade300),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: getTextColor(context)),
            const SizedBox(width: 8),
            Text(
              'Ошибки:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: getTextColor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Используем ... и map с преобразованием в List<Widget>
        ...wrongQuestions.take(3).map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${entry.value.que}',
                    style: TextStyle(
                      fontSize: 14,
                      color: getTextColor(context),
                    ),
                  ),
                  if (entry.value.tip != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Подсказка: ${entry.value.tip!}',
                      style: TextStyle(
                        fontSize: 12,
                        color: getTextColor(context).withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            )).toList(), // Преобразуем в List<Widget>
      ],
    ),
  );
}

  Widget _buildRecommendationCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        children: [
          Text(
            '📚 Рекомендуем повторить материал:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openTipsByTopic(widget.task.topic),
              icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
              label: Text(
                'Повторить советы: ${widget.task.topic}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: restartTest,
            icon: const Icon(Icons.refresh),
            label: const Text('Пройти заново'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home),
            label: const Text('На главную'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoTask(String questionKey, Question question) {
  final photoState = photoTaskStates[questionKey]!;
  
  // Создаем список виджетов истории отдельно
  List<Widget> historyWidgets = _buildHistoryWidgets(questionKey);
  
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: getCardColor(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade300.withOpacity(0.5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        // Photo таймер
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              photoState.isRunning ? Colors.red.shade400 : Colors.blue.shade400,
              photoState.isRunning ? Colors.red.shade600 : Colors.blue.shade600,
            ]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                '${photoState.elapsedSeconds ~/ 60}:${(photoState.elapsedSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                photoState.isRunning ? '⏳ Снимайте!' : '⌛ Готов к старту',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Инструкция
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 168, 130, 2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color.fromARGB(255, 63, 47, 1)),
          ),
          child: Text(
            question.que_f!,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: getTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // История из КЭША
        if (historyWidgets.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: getCorrectAnswerColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🏆 Ваши лучшие результаты:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: getTextColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                ...historyWidgets,
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 40),
        
        // Кнопки Photo
        if (!photoState.isRunning) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('💡 Подсказка'),
                  content: Text(question.tip ?? 'Подсказка недоступна'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Понятно'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Подсказка'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.blue.shade500),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  photoState.isRunning = true;
                  photoState.elapsedSeconds = 0;
                });
                Timer.periodic(const Duration(seconds: 1), (photoTimer) {
                  if (mounted && photoState.isRunning) {
                    setState(() => photoState.elapsedSeconds++);
                  } else {
                    photoTimer.cancel();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.camera_alt, size: 24),
              label: const Text('🚀 НАЧАТЬ СЪЁМКУ'),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final newHistory = PhotoHistory(
                  date: DateTime.now().toString().split(' ')[0],
                  timeSeconds: photoState.elapsedSeconds,
                );
                
                await _savePhotoHistory(questionKey, newHistory);
                photoQuestionTimes[questionKey] = photoState.elapsedSeconds;
                
                setState(() {
                  photoState.isRunning = false;
                });
                nextQuestion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.stop, size: 24),
              label: Text('⏹️ ЗАВЕРШИТЬ (${photoState.elapsedSeconds}s)'),
            ),
          ),
        ],
      ],
    ),
  );
}

// Вспомогательный метод для создания виджетов истории
List<Widget> _buildHistoryWidgets(String questionKey) {
  final history = getPhotoHistory(questionKey);
  if (history == null || history.isEmpty) return [];
  
  // Фильтруем, сортируем и берем лучшие результаты
  final filteredHistory = history
      .where((h) => h.timeSeconds > 0)
      .toList()
    ..sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
  
  final bestResults = filteredHistory.take(3).toList();
  
  // Создаем список виджетов
  return bestResults.map((h) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${h.date}: ',
          style: TextStyle(color: getTextColor(context).withOpacity(0.7)),
        ),
        Text(
          h.formattedTime,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ],
    ),
  )).toList();
}
}

class PhotoTaskState {
  bool isRunning = false;
  int elapsedSeconds = 0;
}

class PhotoHistory {
  final String date;
  final int timeSeconds;

  PhotoHistory({
    required this.date,
    required this.timeSeconds,
  });

  factory PhotoHistory.fromJson(Map<String, dynamic> json) {
    return PhotoHistory(
      date: json['date'] ?? '',
      timeSeconds: json['timeSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'timeSeconds': timeSeconds,
    };
  }

  String get formattedTime {
    final minutes = timeSeconds ~/ 60;
    final seconds = timeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}