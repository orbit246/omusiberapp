import 'package:flutter/material.dart';

/// Lightweight view model for NewsCard & NewsItemPage.
/// Put *all* text/data here so the widgets stay presentational.
class NewsView {
  /// Unique ID from the API
  final int id;

  /// Main title of the news.
  final String title;

  /// Short lead used in the card (1–3 lines).
  final String summary;

  /// Displayed under title.
  final String authorName;

  /// Big cover image for the card.
  final String? heroImage;

  /// URL of the news detail page.
  final String? detailUrl;

  /// Machine-friendly publish date.
  final DateTime? publishedAt;

  /// Human-friendly publish date string (e.g. "12 Kasım 2025").
  final String? publishedAtText;

  /// Tags / categories (e.g. ["Siber Güvenlik", "Etkinlik"]).
  final List<String> tags;

  /// All images for the detail page carousel.
  final List<String> imageUrls;

  /// Full body text for the detail page.
  final String? fullText;

  /// Excel attachments containing parsed data
  final List<Map<String, dynamic>> excelAttachments;

  /// Small circle avatar (optional).
  final ImageProvider? authorAvatar;

  /// Counters
  final int viewCount;
  final int likeCount;

  /// Favorite state for the heart icon.
  final bool isFavorited;

  /// Labels (override if needed for localization/custom text)
  final String readMoreLabel;

  /// Actions (wire these to your app logic)
  final VoidCallback? onOpen;
  final ValueChanged<bool>? onToggleFavorite;
  final VoidCallback? onShare;

  const NewsView({
    this.id = 0, // Default to 0 if not provided (e.g. fallback)
    required this.title,
    required this.summary,
    required this.authorName,
    required this.heroImage,
    this.detailUrl,
    this.publishedAt,
    this.publishedAtText,
    this.tags = const <String>[],
    this.imageUrls = const <String>[],
    this.fullText,
    this.excelAttachments = const [],
    this.authorAvatar,
    this.viewCount = 0,
    this.likeCount = 0,
    this.isFavorited = false,
    this.readMoreLabel = 'Devamını Oku',
    this.onOpen,
    this.onToggleFavorite,
    this.onShare,
  });

  NewsView copyWith({
    int? id,
    String? title,
    String? summary,
    String? authorName,
    String? heroImage,
    String? detailUrl,
    DateTime? publishedAt,
    String? publishedAtText,
    List<String>? tags,
    List<String>? imageUrls,
    String? fullText,
    List<Map<String, dynamic>>? excelAttachments,
    ImageProvider? authorAvatar,
    int? viewCount,
    int? likeCount,
    bool? isFavorited,
    String? readMoreLabel,
    VoidCallback? onOpen,
    ValueChanged<bool>? onToggleFavorite,
    VoidCallback? onShare,
  }) {
    return NewsView(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      authorName: authorName ?? this.authorName,
      heroImage: heroImage ?? this.heroImage,
      detailUrl: detailUrl ?? this.detailUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      publishedAtText: publishedAtText ?? this.publishedAtText,
      tags: tags ?? this.tags,
      imageUrls: imageUrls ?? this.imageUrls,
      fullText: fullText ?? this.fullText,
      excelAttachments: excelAttachments ?? this.excelAttachments,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      isFavorited: isFavorited ?? this.isFavorited,
      readMoreLabel: readMoreLabel ?? this.readMoreLabel,
      onOpen: onOpen ?? this.onOpen,
      onToggleFavorite: onToggleFavorite ?? this.onToggleFavorite,
      onShare: onShare ?? this.onShare,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NewsView && other.id == id && other.title == title;
  }

  @override
  int get hashCode => Object.hash(id, title);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'authorName': authorName,
      'heroImage': heroImage,
      'detailUrl': detailUrl,
      'publishedAt': publishedAt?.toIso8601String(),
      'publishedAtText': publishedAtText,
      'tags': tags,
      'imageUrls': imageUrls,
      'fullText': fullText,
      'excelAttachments': excelAttachments,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'isFavorited': isFavorited,
      'readMoreLabel': readMoreLabel,
    };
  }

  factory NewsView.fromJson(Map<String, dynamic> json) {
    return NewsView(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      heroImage: json['heroImage'] as String?,
      detailUrl: json['detailUrl'] as String?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      publishedAtText: json['publishedAtText'] as String?,
      tags: List<String>.from(json['tags'] ?? []),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      fullText: json['fullText'] as String?,
      excelAttachments: List<Map<String, dynamic>>.from(
        json['excelAttachments'] ?? [],
      ),
      viewCount: json['views'] as int? ?? json['viewCount'] as int? ?? 0,
      likeCount: json['likes'] as int? ?? json['likeCount'] as int? ?? 0,
      isFavorited:
          json['isLiked'] as bool? ?? json['isFavorited'] as bool? ?? false,
      readMoreLabel: json['readMoreLabel'] as String? ?? 'Devamını Oku',
    );
  }
}
