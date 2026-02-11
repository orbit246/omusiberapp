class Note {
  final String id;
  final String content;
  final String category; // "Genel" or "Ders: [Name]"
  final DateTime createdAt;
  final DateTime updatedAt;
  final int color; // Color value

  Note({
    required this.id,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.color = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'color': color,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    content: json['content'],
    category: json['category'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    color: json['color'] ?? 0,
  );
}
