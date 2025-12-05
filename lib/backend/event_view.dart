class EventView {
  String title;
  String description;
  double eventLength;
  String location;
  DateTime date;
  String thumbnailUrl;
  List<String> corouselImages;

  List<String> tags;
  int maxJoiners;

  EventView({
    required this.title,
    required this.description,
    required this.eventLength,
    required this.location,
    required this.date,
    required this.thumbnailUrl,
    required this.corouselImages,
    required this.tags,
    required this.maxJoiners,
  });

  factory EventView.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int _toInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    DateTime _toDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.parse(v);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    List<String> _toStringList(dynamic v) {
      if (v is List<dynamic>) return v.map((e) => e.toString()).toList();
      return <String>[];
    }

    return EventView(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      eventLength: _toDouble(json['eventLength']),
      location: json['location'] as String? ?? '',
      date: _toDate(json['date']),
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      corouselImages: _toStringList(json['corouselImages']),
      tags: _toStringList(json['tags']),
      maxJoiners: _toInt(json['maxJoiners']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'eventLength': eventLength,
      'location': location,
      'date': date.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
      'corouselImages': corouselImages,
      'tags': tags,
      'maxJoiners': maxJoiners,
    };
  }
}
