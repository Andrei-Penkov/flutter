class Tip {
  final String name;
  final int level;
  int status;
  final String tip;
  final String? imagePath;

  Tip({
    required this.name,
    required this.level,
    required this.status,
    required this.tip,
    this.imagePath,
  });

  factory Tip.fromJson(Map<String, dynamic> json) {
    return Tip(
      name: json['name'],
      level: json['level'],
      status: json['status'],
      tip: json['tip'],
      imagePath: json['imagePath'],
    );
  }
}
