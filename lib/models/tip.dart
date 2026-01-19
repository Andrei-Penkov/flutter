class Tip {
  final String name;
  final int level;
  int status;
  final String topic;
  final String tip;
  final List<String> images; // Изменено на список фотографий
  final String tipKey;
  bool isFavorite;

  Tip({
    required this.name,
    required this.level,
    required this.status,
    required this.topic,
    required this.tip,
    this.images = const [], // По умолчанию пустой список
    this.tipKey = '',
    this.isFavorite = false,
  });

  factory Tip.fromJson(Map<String, dynamic> json, {String? key}) {
    return Tip(
      name: json['name'],
      level: json['level'],
      status: json['status'] ?? 0,
      topic: json['topic'],
      tip: json['tip'],
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      tipKey: key ?? json['key'] ?? '',
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'level': level,
      'status': status,
      'topic': topic,
      'tip': tip,
      'images': images,
      'isFavorite': isFavorite,
    };
  }
}