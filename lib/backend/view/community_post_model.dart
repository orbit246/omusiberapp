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
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id']?.toString() ?? '',
      authorName: json['authorName'] ?? 'Anonim',
      authorImage: json['authorImage'],
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      likes: json['likes'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      poll: json['poll'] != null ? PollModel.fromJson(json['poll']) : null,
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
    );
  }
}

class PollModel {
  final String id;
  final String question;
  final List<PollOption> options;
  final String? userVotedOptionId;
  final DateTime closesAt;
  final bool isClosed;

  PollModel({
    required this.id,
    required this.question,
    required this.options,
    this.userVotedOptionId,
    required this.closesAt,
    this.isClosed = false,
  });

  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.votes);

  factory PollModel.fromJson(Map<String, dynamic> json) {
    final DateTime parsedClosesAt =
        DateTime.tryParse(
          (json['closesAt'] ?? json['expiresAt'])?.toString() ?? '',
        ) ??
        DateTime.now().add(const Duration(days: 7));

    final bool parsedIsClosed =
        (json['isClosed'] as bool?) ?? DateTime.now().isAfter(parsedClosesAt);

    return PollModel(
      id: json['id']?.toString() ?? '',
      question: json['question'] ?? '',
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => PollOption.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      userVotedOptionId: json['userVotedOptionId'],
      closesAt: parsedClosesAt,
      isClosed: parsedIsClosed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'options': options.map((e) => e.toJson()).toList(),
    'userVotedOptionId': userVotedOptionId,
    'closesAt': closesAt.toIso8601String(),
    'isClosed': isClosed,
    // Backward compatibility for old cached shape
    'expiresAt': closesAt.toIso8601String(),
  };
}

class PollOption {
  final String id;
  final String text;
  final int votes;

  PollOption({required this.id, required this.text, this.votes = 0});

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id']?.toString() ?? '',
      text: json['text'] ?? '',
      votes: (json['votes'] is num)
          ? (json['votes'] as num).toInt()
          : int.tryParse(json['votes']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'votes': votes};
}
