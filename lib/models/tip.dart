class Tip {
  final String name;
  final int level;
  int status;
  final String topic;
  final String tip;
  final String? imagePath;
  final String tipKey;
  bool isFavorite; // НОВОЕ ПОЛЕ для избранного

  Tip({
    required this.name,
    required this.level,
    required this.status,
    required this.topic,
    required this.tip,
    this.imagePath,
    this.tipKey = '',
    this.isFavorite = false, // По умолчанию не в избранном
  });

  factory Tip.fromJson(Map<String, dynamic> json, {String? key}) {
    return Tip(
      name: json['name'],
      level: json['level'],
      status: json['status'] ?? 0,
      topic: json['topic'],
      tip: json['tip'],
      imagePath: json['imagePath'],
      tipKey: key ?? json['key'] ?? '',
      isFavorite: json['isFavorite'] ?? false, // Чтение из JSON
    );
  }

  // Для сохранения в JSON можно добавить метод toJson, если нужно
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'level': level,
      'status': status,
      'topic': topic,
      'tip': tip,
      'imagePath': imagePath,
      'isFavorite': isFavorite,
    };
  }
}