class Task {
  final String name; // Название задания
  final int level;   // Уровень сложности задания
  int status;        // Текущий статус задания (0 - не выполнено, 1 - выполнено)
  final Map<String, Question> questions; // Коллекция вопросов, ключ - идентификатор вопроса

  Task({
    required this.name,
    required this.level,
    required this.status,
    required this.questions,
  });

  //загрузка из json
  factory Task.fromJson(Map<String, dynamic> json) {
    final questions = <String, Question>{};
    // Заполнение вопросов
    (json['tasks'] as Map<String, dynamic>).forEach((key, value) {
      questions[key] = Question.fromJson(value);
    });
    // заполненный объект Task
    return Task(
      name: json['name'],
      level: json['level'],
      status: json['status'],
      questions: questions,
    );
  }

  // обратно в JSON
  Map<String, dynamic> toJson() => {
        'name': name,
        'level': level,
        'status': status,
        'tasks': questions.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class Question {
  final String que;             // Текст самого вопроса
  final String ans;             // Правильный ответ на вопрос
  final List<String>? imagePaths; // Опциональный список путей к изображениями

  Question({
    required this.que,
    required this.ans,
    this.imagePaths,
  });

  //загрузка из json
  factory Question.fromJson(Map<String, dynamic> json) {
    List<String>? images;
    if (json['imagePaths'] != null) {
      images = (json['imagePaths'] as List).map((e) => e.toString()).toList();
    }
    return Question(
      que: json['que'],
      ans: json['ans'],
      imagePaths: images,
    );
  }

  // обратно в JSON
  Map<String, dynamic> toJson() => {
        'que': que,
        'ans': ans,
        if (imagePaths != null) 'imagePaths': imagePaths,
      };
}