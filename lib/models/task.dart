class Task {
  final String name;
  final int level;
  int status;
  final String topic;
  final Map<String, Question> questions;

  Task({
    required this.name,
    required this.level,
    required this.status,
    required this.topic,
    required this.questions,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    final questions = <String, Question>{};
    (json['tasks'] as Map<String, dynamic>).forEach((key, value) {
      questions[key] = Question.fromJson(value);
    });
    return Task(
      name: json['name'],
      level: json['level'],
      status: json['status'] ?? 0,
      topic: json['topic'] ?? '',
      questions: questions,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'level': level,
    'status': status,
    'topic': topic,
    'tasks': questions.map((k, v) => MapEntry(k, v.toJson())),
  };
}

class Question {
  final String? que;
  final String? que_f;
  final String? que_c; // НОВОЕ: задание с обратным таймером
  final String ans;
  final List<String>? options;
  final List<String>? imagePaths;
  final String? tip;

  Question({
    this.que,
    this.que_f,
    this.que_c, // НОВОЕ
    required this.ans,
    this.options,
    this.imagePaths,
    this.tip,
  });

  bool get isPhotoTask => que_f != null;
  bool get isCountdownTask => que_c != null; // НОВОЕ

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      que: json['que'],
      que_f: json['que_f'],
      que_c: json['que_c'], // НОВОЕ
      ans: json['ans'] ?? '',
      options: json['options']?.map<String>((e) => e.toString()).toList(),
      imagePaths: json['imagePaths']?.map<String>((e) => e.toString()).toList(),
      tip: json['tip'],
    );
  }

  Map<String, dynamic> toJson() => {
    if (que != null) 'que': que,
    if (que_f != null) 'que_f': que_f,
    if (que_c != null) 'que_c': que_c, // НОВОЕ
    'ans': ans,
    if (options != null) 'options': options,
    if (imagePaths != null) 'imagePaths': imagePaths,
    if (tip != null) 'tip': tip,
  };
}