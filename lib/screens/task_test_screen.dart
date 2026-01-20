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
  Map<String, bool> answerChecked = {};
  String resultMessage = '';
  bool showResult = false;
  
  static const int baseTimeSeconds = 120;
  late int remainingSeconds;
  Timer? timer;
  
  // КЭШ истории + состояния
  Map<String, List<PhotoHistory>> photoHistoryCache = {};
  Map<String, List<CountdownHistory>> countdownHistoryCache = {};
  Map<String, PhotoTaskState> photoTaskStates = {};
  Map<String, CountdownTaskState> countdownTaskStates = {};
  Map<String, int> photoQuestionTimes = {};
  Map<String, int?> countdownPhotosCount = {};
  Map<String, Timer?> countdownTimers = {};
  int totalPhotoTime = 0;

  Color getCardColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? const Color(0xFF2D2D2D)
        : Colors.white;
  }

  Color getTextColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? Colors.white 
        : Colors.black87;
  }

  Color getBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF5F5F5);
  }

  Color getCorrectAnswerColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? const Color(0xFF1B5E20)
        : const Color(0xFFC8E6C9);
  }

  Color getWrongAnswerColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark 
        ? const Color(0xFF7F0000)
        : const Color(0xFFFFCDD2);
  }

  @override
  void initState() {
    super.initState();
    controllers = {for (var k in widget.task.questions.keys) k: TextEditingController()};
    selectedOptions = {for (var k in widget.task.questions.keys) k: null};
    photoTaskStates = {for (var k in widget.task.questions.keys) k: PhotoTaskState()};
    photoQuestionTimes = {for (var k in widget.task.questions.keys) k: 0};
    countdownTaskStates = {for (var k in widget.task.questions.keys) k: CountdownTaskState()};
    countdownPhotosCount = {for (var k in widget.task.questions.keys) k: null};
    
    _loadPhotoHistoryCache();
    _loadCountdownHistoryCache();
    
    // НОВАЯ ЛОГИКА: таймер теста только если нет заданий с таймером
    bool hasPhotoTasks = widget.task.questions.values.any((q) => q.isPhotoTask);
    bool hasCountdownTasks = widget.task.questions.values.any((q) => q.isCountdownTask);
    
    if (!hasPhotoTasks && !hasCountdownTasks) {
      remainingSeconds = baseTimeSeconds * (widget.task.level > 0 ? widget.task.level : 1);
      startTimer();
    } else {
      remainingSeconds = 0; // Без общего таймера
    }
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

  Future<void> _loadCountdownHistoryCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString('countdown_history_cache') ?? '{}';
      final cacheMap = json.decode(cacheString) as Map<String, dynamic>;
      
      countdownHistoryCache.clear();
      cacheMap.forEach((taskKey, historyList) {
        if (historyList != null) {
          countdownHistoryCache[taskKey] = (historyList as List)
              .map((h) => CountdownHistory.fromJson(h as Map<String, dynamic>))
              .toList();
        }
      });
    } catch (e) {
      countdownHistoryCache.clear();
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

  Future<void> _saveCountdownHistory(String questionKey, CountdownHistory newHistory) async {
    List<CountdownHistory> taskHistory = countdownHistoryCache[widget.task.name] ?? [];
    
    taskHistory.add(newHistory);
    taskHistory = taskHistory.take(10).toList();
    
    countdownHistoryCache[widget.task.name] = taskHistory;
    
    final prefs = await SharedPreferences.getInstance();
    final saveMap = <String, List<Map<String, dynamic>>>{};
    countdownHistoryCache.forEach((key, history) {
      saveMap[key] = history.map((h) => h.toJson()).toList();
    });
    
    await prefs.setString('countdown_history_cache', json.encode(saveMap));
  }

  List<PhotoHistory>? getPhotoHistory(String questionKey) {
    return photoHistoryCache[widget.task.name];
  }

  List<CountdownHistory>? getCountdownHistory(String questionKey) {
    return countdownHistoryCache[widget.task.name];
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

  void startCountdownTimer(String questionKey) {
    final state = countdownTaskStates[questionKey]!;
    
    setState(() {
      state.isRunning = true;
      state.remainingSeconds = 60;
    });

    countdownTimers[questionKey]?.cancel();
    countdownTimers[questionKey] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        state.remainingSeconds--;
        
        if (state.remainingSeconds <= 0) {
          timer.cancel();
          state.isRunning = false;
          _onCountdownFinished(questionKey);
        }
      });
    });
  }

  void _onCountdownFinished(String questionKey) async {
  final photosCount = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      int? tempCount;
      return AlertDialog(
        title: const Text('Таймер завершен!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Сколько фотографий вы успели сделать?'),
            const SizedBox(height: 20),
            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Количество фотографий',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onChanged: (value) {
                tempCount = int.tryParse(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (tempCount != null) {
                Navigator.pop(context, tempCount);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите число')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      );
    },
  );

  if (photosCount != null) {
    final newHistory = CountdownHistory(
      date: DateTime.now().toString().split(' ')[0],
      photosCount: photosCount,
    );
    
    await _saveCountdownHistory(questionKey, newHistory);
    
    // ОБНОВЛЕНИЕ С НОВЫМ setState
    setState(() {
      countdownPhotosCount[questionKey] = photosCount;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Вы сделали $photosCount фотографий!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
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

  void nextQuestion() {
    final currentQuestionKey = widget.task.questions.keys.elementAt(currentQuestionIndex);
    final currentQuestion = widget.task.questions.values.toList()[currentQuestionIndex];
    
    if (currentQuestion.isPhotoTask) {
      if (currentQuestionIndex < widget.task.questions.length - 1) {
        setState(() => currentQuestionIndex++);
      } else {
        checkAnswers();
      }
    } else if (currentQuestion.isCountdownTask) {
      if (currentQuestionIndex < widget.task.questions.length - 1) {
        setState(() => currentQuestionIndex++);
      } else {
        checkAnswers();
      }
    } else {
      if (!answerChecked.containsKey(currentQuestionKey) || !answerChecked[currentQuestionKey]!) {
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
          answerChecked[currentQuestionKey] = true;
          
          if (!isCorrect && currentQuestion.tip != null) {
            showHintForQuestion[currentQuestionKey] = true;
          }
        });
      } else {
        if (currentQuestionIndex < widget.task.questions.length - 1) {
          setState(() => currentQuestionIndex++);
        } else {
          checkAnswers();
        }
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
        results[key] = photoQuestionTimes[key]! > 0;
        if (photoQuestionTimes[key]! > 0) {
          correct++;
          totalPhotoTime += photoQuestionTimes[key]!;
        }
      } else if (question.isCountdownTask) {
        results[key] = countdownPhotosCount[key] != null && countdownPhotosCount[key]! > 0;
        if (countdownPhotosCount[key] != null && countdownPhotosCount[key]! > 0) {
          correct++;
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
        
        final countdownEntries = widget.task.questions.entries
            .where((entry) => entry.value.isCountdownTask)
            .where((entry) => countdownPhotosCount[entry.key] != null)
            .toList();
        
        if (countdownEntries.isNotEmpty) {
          resultMessage += '\n\nСделано фотографий за 1 минуту:';
          for (var entry in countdownEntries) {
            resultMessage += '\n• ${countdownPhotosCount[entry.key]} фото';
          }
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
      answerChecked.clear();
      selectedOptions.updateAll((key, value) => null);
      controllers.forEach((key, controller) => controller.clear());
      photoTaskStates.updateAll((key, state) => PhotoTaskState());
      countdownTaskStates.updateAll((key, state) => CountdownTaskState());
      countdownPhotosCount.updateAll((key, value) => null);
      photoQuestionTimes.updateAll((key, value) => 0);
      totalPhotoTime = 0;
      resultMessage = '';
      
      bool hasPhotoTasks = widget.task.questions.values.any((q) => q.isPhotoTask);
      bool hasCountdownTasks = widget.task.questions.values.any((q) => q.isCountdownTask);
      
      if (!hasPhotoTasks && !hasCountdownTasks) {
        remainingSeconds = baseTimeSeconds * (widget.task.level > 0 ? widget.task.level : 1);
        startTimer();
      } else {
        remainingSeconds = 0;
      }
      
      showResult = false;
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
    for (var timer in countdownTimers.values) {
      timer?.cancel();
    }
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
  final isCountdownTask = currentQuestion.isCountdownTask;
  final showCorrect = showCorrectAnswers[currentQuestionKey] ?? false;
  final showHint = showHintForQuestion[currentQuestionKey] ?? false;
  final isAnswerChecked = answerChecked[currentQuestionKey] ?? false;

  if (showResult) {
    return _buildResultsScreen(context);
  }

  return CommonScaffold(
    title: '${widget.task.name} (${currentQuestionIndex + 1}/${questions.length})',
    body: Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (remainingSeconds > 0) ...[
                _buildTimerProgress(context, questions.length),
                const SizedBox(height: 20),
              ],

              if (isPhotoTask) ...[
                _buildPhotoTask(currentQuestionKey, currentQuestion),
                const SizedBox(height: 100),
              ] else if (isCountdownTask) ...[
                _buildCountdownTask(currentQuestionKey, currentQuestion),
                const SizedBox(height: 100),
              ] else ...[
                _buildQuestionCard(context, currentQuestion),
                const SizedBox(height: 20),

                if (showHint && currentQuestion.tip != null)
                  _buildHintCard(context, currentQuestion.tip!),

                _buildOptionsList(context, currentQuestionKey, currentQuestion, selectedAnswer, showCorrect),
                
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),

        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]!.withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: isPhotoTask 
                ? _buildPhotoNavigationButtons(context)
                : isCountdownTask
                    ? _buildCountdownNavigationButtons(context)
                    : _buildNavigationButtons(context, questions.length, isAnswerChecked),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildResultsScreen(BuildContext context) {
  final questions = widget.task.questions.values.toList();
  final isAllCorrect = answerResults.values.every((v) => v);
  final wrongQuestions = widget.task.questions.entries
      .where((entry) => !answerResults[entry.key]! && !entry.value.isPhotoTask && !entry.value.isCountdownTask)
      .toList();
  final photoHistory = getPhotoHistory('') ?? [];
  // Убрал final из этой строки - была ошибка
  final countdownHistory = getCountdownHistory('') ?? [];

  return CommonScaffold(
    title: 'Результаты: ${widget.task.name}',
    body: Container(
      color: getBackgroundColor(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
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

            if (totalPhotoTime > 0) ...[
              _buildPhotoStatisticsCard(context, photoHistory),
              const SizedBox(height: 20),
            ],

            // ВОТ ИСПРАВЛЕНИЕ - убрал final из этой строки
            // Получаем countdownEntries для проверки
            ...() {
              final countdownEntries = widget.task.questions.entries
                  .where((entry) => entry.value.isCountdownTask)
                  .where((entry) => countdownPhotosCount[entry.key] != null)
                  .toList();
              
              // Возвращаем список виджетов
              if (countdownEntries.isNotEmpty) {
                return [
                  _buildCountdownStatisticsCard(context, countdownHistory),
                  const SizedBox(height: 20),
                ];
              } else {
                return <Widget>[];
              }
            }(),

            if (wrongQuestions.isNotEmpty) ...[
              _buildWrongQuestionsCard(context, wrongQuestions),
              const SizedBox(height: 20),
            ],

            if (!isAllCorrect) ...[
              _buildRecommendationCard(context),
              const SizedBox(height: 20),
            ],

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
        color: const Color.fromARGB(255, 117, 114, 114),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromARGB(255, 77, 6, 6)),
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

  Widget _buildNavigationButtons(BuildContext context, int totalQuestions, bool isAnswerChecked) {
  final currentQuestionKey = widget.task.questions.keys.elementAt(currentQuestionIndex);
  final hasAnswer = selectedOptions[currentQuestionKey] != null;
  final isLastQuestion = currentQuestionIndex == totalQuestions - 1;
  
  String buttonText;
  bool showRightIcon = false; // Флаг для иконки справа
  IconData iconData;
  
  if (!isAnswerChecked) {
    buttonText = isLastQuestion ? 'Завершить' : 'Проверить';
    showRightIcon = false;
    iconData = Icons.check;
  } else {
    buttonText = isLastQuestion ? 'Завершить тест' : 'Далее';
    showRightIcon = buttonText == 'Далее';
    iconData = isLastQuestion ? Icons.check : Icons.arrow_forward_ios;
  }

  return Row(
    children: [
      if (currentQuestionIndex > 0)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: previousQuestion,
            icon: const Icon(Icons.arrow_back_ios, size: 16),
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
        child: showRightIcon
            ? ElevatedButton(
                onPressed: hasAnswer ? nextQuestion : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(buttonText),
                    const SizedBox(width: 8),
                    Icon(iconData, size: 16),
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAnswerChecked ? Colors.blue.shade500 : Colors.green.shade500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            : ElevatedButton.icon(
                onPressed: hasAnswer ? nextQuestion : null,
                icon: Icon(iconData, size: 16),
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

  Widget _buildPhotoNavigationButtons(BuildContext context) {
  final questions = widget.task.questions.values.toList();
  final isLastQuestion = currentQuestionIndex == questions.length - 1;
  final showRightIcon = !isLastQuestion;
  
  return Row(
    children: [
      if (currentQuestionIndex > 0)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: previousQuestion,
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            label: const Text('Назад'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      if (currentQuestionIndex > 0) const SizedBox(width: 12),
      Expanded(
        flex: currentQuestionIndex > 0 ? 1 : 2,
        child: showRightIcon
            ? ElevatedButton(
                onPressed: nextQuestion,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(isLastQuestion ? 'Завершить' : 'Далее'),
                    const SizedBox(width: 8),
                    Icon(isLastQuestion ? Icons.done_all : Icons.arrow_forward_ios, size: 18),
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )
            : ElevatedButton.icon(
                onPressed: nextQuestion,
                label: Text(isLastQuestion ? 'Завершить' : 'Далее'),
                icon: Icon(isLastQuestion ? Icons.done_all : Icons.arrow_forward_ios, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
      ),
    ],
  );
}

  Widget _buildCountdownNavigationButtons(BuildContext context) {
  final questions = widget.task.questions.values.toList();
  final isLastQuestion = currentQuestionIndex == questions.length - 1;
  final currentQuestionKey = widget.task.questions.keys.elementAt(currentQuestionIndex);
  final state = countdownTaskStates[currentQuestionKey]!;
  final showRightIcon = !isLastQuestion;
  
  return Row(
    children: [
      if (currentQuestionIndex > 0)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: state.isRunning ? null : previousQuestion,
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            label: const Text('Назад'),
            style: ElevatedButton.styleFrom(
              backgroundColor: state.isRunning ? Colors.grey.shade400 : Colors.grey.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      if (currentQuestionIndex > 0) const SizedBox(width: 12),
      Expanded(
        flex: currentQuestionIndex > 0 ? 1 : 2,
        child: showRightIcon
            ? ElevatedButton(
                onPressed: state.isRunning || countdownPhotosCount[currentQuestionKey] == null
                    ? null
                    : nextQuestion,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(isLastQuestion ? 'Завершить' : 'Далее'),
                    const SizedBox(width: 8),
                    Icon(isLastQuestion ? Icons.done_all : Icons.arrow_forward_ios, size: 18),
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: countdownPhotosCount[currentQuestionKey] != null
                      ? Colors.blue.shade500
                      : Colors.grey.shade500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )
            : ElevatedButton.icon(
                onPressed: state.isRunning || countdownPhotosCount[currentQuestionKey] == null
                    ? null
                    : nextQuestion,
                label: Text(isLastQuestion ? 'Завершить' : 'Далее'),
                icon: Icon(isLastQuestion ? Icons.done_all : Icons.arrow_forward_ios, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: countdownPhotosCount[currentQuestionKey] != null
                      ? Colors.blue.shade500
                      : Colors.grey.shade500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
      ),
    ],
  );
}

  Widget _buildPhotoStatisticsCard(BuildContext context, List<PhotoHistory> history) {
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
                )).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdownStatisticsCard(BuildContext context, List<CountdownHistory> history) {
    final sortedHistory = [...history]
      .where((h) => h.photosCount > 0)
      .toList()
      ..sort((a, b) => b.photosCount.compareTo(a.photosCount));
    
    final bestResults = sortedHistory.take(3).toList();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 169, 187, 4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color.fromARGB(255, 3, 47, 97)),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
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
              Icon(Icons.speed, color: const Color.fromARGB(255, 69, 5, 97)),
              const SizedBox(width: 2),
              Text(
                'Скоростная съемка',
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
            'Лучшие результаты:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: getTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          if (bestResults.isNotEmpty) ...[
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
                        '${record.photosCount} фото',
                        style: TextStyle(
                          color: const Color.fromARGB(255, 6, 12, 102),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
          ] else ...[
            Text(
              'Нет сохраненных результатов',
              style: TextStyle(
                color: getTextColor(context).withOpacity(0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
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
              )).toList(),
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
    final history = getPhotoHistory(questionKey);
    
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
      
          
          if (!photoState.isRunning) ...[
            if (question.tip != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('💡 Подсказка'),
                      content: Text(question.tip!),
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
            ],
            if (history != null && history.isNotEmpty)
            _buildPhotoHistoryWidget(history),
          
            const SizedBox(height: 40),
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

  Widget _buildCountdownTask(String questionKey, Question question) {
    final state = countdownTaskStates[questionKey]!;
    final history = getCountdownHistory(questionKey);
    
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                state.isRunning ? Colors.purple.shade400 : Colors.blue.shade400,
                state.isRunning ? Colors.purple.shade600 : Colors.blue.shade600,
              ]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  '${state.remainingSeconds ~/ 60}:${(state.remainingSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  state.isRunning ? '⏳ Фотографируйте!' : '⌛ Готов к старту',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Text(
              question.que_c!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: getTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (!state.isRunning) ...[
            if (question.tip != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('💡 Подсказка'),
                      content: Text(question.tip!),
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
                    side: BorderSide(color: Colors.purple.shade500),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (history != null && history.isNotEmpty)
            _buildCountdownHistoryWidget(history),
          
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => startCountdownTimer(questionKey),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.timer, size: 24),
                label: const Text('🚀 НАЧАТЬ ТАЙМЕР'),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  countdownTimers[questionKey]?.cancel();
                  setState(() {
                    state.isRunning = false;
                    state.remainingSeconds = 60;
                  });
                  _onCountdownFinished(questionKey);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.stop, size: 24),
                label: Text('⏹️ ОСТАНОВИТЬ (${state.remainingSeconds}s)'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildHistoryWidgets(String questionKey) {
    final history = getPhotoHistory(questionKey);
    if (history == null || history.isEmpty) return [];
    
    final filteredHistory = history
        .where((h) => h.timeSeconds > 0)
        .toList()
      ..sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
    
    final bestResults = filteredHistory.take(3).toList();
    
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

  Widget _buildPhotoHistoryWidget(List<PhotoHistory> history) {
    final filteredHistory = history
        .where((h) => h.timeSeconds > 0)
        .toList()
      ..sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
    
    final bestResults = filteredHistory.take(3).toList();
    
    if (bestResults.isEmpty) return Container();
    
    return Container(
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
          ...bestResults.map((h) => Padding(
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
              )).toList(),
        ],
      ),
    );
  }

  Widget _buildCountdownHistoryWidget(List<CountdownHistory> history) {
    final sortedHistory = [...history]
      .where((h) => h.photosCount > 0)
      .toList()
      ..sort((a, b) => b.photosCount.compareTo(a.photosCount));
    
    final bestResults = sortedHistory.take(3).toList();
    
    if (bestResults.isEmpty) return Container();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 67, 179, 2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromARGB(255, 190, 231, 192)),
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
          ...bestResults.map((h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      h.date,
                      style: TextStyle(color: getTextColor(context).withOpacity(0.7)),
                    ),
                    Text(
                      '${h.photosCount} фото',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )).toList(),
        ],
      ),
    );
  }
}

class PhotoTaskState {
  bool isRunning = false;
  int elapsedSeconds = 0;
}

class CountdownTaskState {
  bool isRunning = false;
  int remainingSeconds = 60;
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

class CountdownHistory {
  final String date;
  final int photosCount;

  CountdownHistory({
    required this.date,
    required this.photosCount,
  });

  factory CountdownHistory.fromJson(Map<String, dynamic> json) {
    return CountdownHistory(
      date: json['date'] ?? '',
      photosCount: json['photosCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'photosCount': photosCount,
    };
  }
}