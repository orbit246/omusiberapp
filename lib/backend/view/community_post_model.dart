class CommunityPost {
  final String id;
  final String authorName;
  final String? authorImage;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final int likes;
  final bool isLiked;
  final PollModel? poll; // Added Poll
  final String category;
  final bool isPinned;
  final int? accentColor;
  final Map<String, int> reactionCounts;
  final Set<String> selectedReactions;

  CommunityPost({
    required this.id,
    required this.authorName,
    this.authorImage,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.likes = 0,
    this.isLiked = false,
    this.poll,
    this.category = 'general',
    this.isPinned = false,
    this.accentColor,
    this.reactionCounts = const {},
    this.selectedReactions = const {},
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: _asString(json['id']),
      authorName: _asString(json['authorName'], fallback: 'Anonim'),
      authorImage: _asNullableString(json['authorImage']),
      content: _asString(json['content']),
      imageUrl: _asNullableString(json['imageUrl']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      likes: _asInt(json['likes']),
      isLiked: _asBool(json['isLiked']),
      poll: json['poll'] is Map
          ? PollModel.fromJson(Map<String, dynamic>.from(json['poll'] as Map))
          : null,
      category: _asString(json['category'], fallback: 'general'),
      isPinned: json['isPinned'] == true || json['pinned'] == true,
      accentColor: _parseAccentColor(
        json['accentColor'] ?? json['borderColor'],
      ),
      reactionCounts: parseReactionCounts(json['reactionCounts']),
      selectedReactions: parseSelectedReactions(
        json['selectedReactions'] ?? json['userReactions'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorName': authorName,
    'authorImage': authorImage,
    'content': content,
    'imageUrl': imageUrl,
    'createdAt': createdAt.toIso8601String(),
    'likes': likes,
    'isLiked': isLiked,
    'poll': poll?.toJson(),
    'category': category,
    'isPinned': isPinned,
    'accentColor': accentColor,
    'reactionCounts': reactionCounts,
    'selectedReactions': selectedReactions.toList(),
  };

  CommunityPost copyWith({
    String? id,
    String? authorName,
    String? authorImage,
    String? content,
    String? imageUrl,
    DateTime? createdAt,
    int? likes,
    bool? isLiked,
    PollModel? poll,
    String? category,
    bool? isPinned,
    int? accentColor,
    Map<String, int>? reactionCounts,
    Set<String>? selectedReactions,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorImage: authorImage ?? this.authorImage,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      poll: poll ?? this.poll,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      accentColor: accentColor ?? this.accentColor,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      selectedReactions: selectedReactions ?? this.selectedReactions,
    );
  }
}

Map<String, int> parseReactionCounts(dynamic value) {
  if (value is! Map) return const {};
  return value.map((key, rawCount) {
    final count = rawCount is num
        ? rawCount.toInt()
        : int.tryParse(rawCount?.toString() ?? '') ?? 0;
    return MapEntry(key.toString(), count);
  });
}

Set<String> parseSelectedReactions(dynamic value) {
  if (value is List) return value.map((item) => item.toString()).toSet();
  if (value is Set) return value.map((item) => item.toString()).toSet();
  return const {};
}

int? _parseAccentColor(dynamic value) {
  if (value is int) return value;
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  final normalized = raw.replaceFirst('#', '').replaceFirst('0x', '');
  final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
  return int.tryParse(withAlpha, radix: 16);
}

class PollModel {
  final String id;
  final String question;
  final List<PollOption> options;
  final String? userVotedOptionId;
  final DateTime? closesAt;
  final bool isClosed;

  PollModel({
    required this.id,
    required this.question,
    required this.options,
    this.userVotedOptionId,
    this.closesAt,
    this.isClosed = false,
  });

  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.votes);
  bool get hasDeadline => closesAt != null;
  bool get isExpired =>
      isClosed || (closesAt != null && DateTime.now().isAfter(closesAt!));

  factory PollModel.fromJson(Map<String, dynamic> json) {
    final rawClosesAt = json['closesAt'] ?? json['expiresAt'];
    final DateTime? parsedClosesAt = rawClosesAt == null
        ? null
        : DateTime.tryParse(rawClosesAt.toString());

    final bool parsedIsClosed =
        (json['isClosed'] as bool?) ??
        (parsedClosesAt != null && DateTime.now().isAfter(parsedClosesAt));

    return PollModel(
      id: _asString(json['id']),
      question: _asString(json['question']),
      options:
          (json['options'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => PollOption.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      userVotedOptionId: _asNullableString(json['userVotedOptionId']),
      closesAt: parsedClosesAt,
      isClosed: parsedIsClosed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'options': options.map((e) => e.toJson()).toList(),
    'userVotedOptionId': userVotedOptionId,
    'closesAt': closesAt?.toIso8601String(),
    'isClosed': isClosed,
    // Backward compatibility for old cached shape
    'expiresAt': closesAt?.toIso8601String(),
  };
}

class PollOption {
  final String id;
  final String text;
  final int votes;

  const PollOption({required this.id, required this.text, this.votes = 0});

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: _asString(json['id']),
      text: _asString(json['text']),
      votes: _asInt(json['votes']),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'votes': votes};
}

String _asString(dynamic value, {String fallback = ''}) {
  final normalized = _asNullableString(value);
  return normalized == null || normalized.isEmpty ? fallback : normalized;
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return fallback;
}
