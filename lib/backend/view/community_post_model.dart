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
}

class PollModel {
  final String id;
  final String question;
  final List<PollOption> options;
  final String? userVotedOptionId;
  final DateTime expiresAt;

  PollModel({
    required this.id,
    required this.question,
    required this.options,
    this.userVotedOptionId,
    required this.expiresAt,
  });

  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.votes);

  factory PollModel.fromJson(Map<String, dynamic> json) {
    return PollModel(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => PollOption.fromJson(e))
              .toList() ??
          [],
      userVotedOptionId: json['userVotedOptionId'],
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : DateTime.now().add(const Duration(days: 7)),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'options': options.map((e) => e.toJson()).toList(),
    'userVotedOptionId': userVotedOptionId,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

class PollOption {
  final String id;
  final String text;
  final int votes;

  PollOption({required this.id, required this.text, this.votes = 0});

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      votes: json['votes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'votes': votes};
}
