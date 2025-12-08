import 'package:flutter/material.dart';

/// Lightweight view model for NewsCard & NewsItemPage.
/// Put *all* text/data here so the widgets stay presentational.
class NewsView {
  const NewsView({
    // Core
    required this.title,
    required this.summary,
    required this.authorName,
    required this.heroImage,

    // Metadata / extra info
    this.detailUrl,
    this.publishedAt,
    this.publishedAtText,
    this.tags = const <String>[],
    this.imageUrls = const <String>[],
    this.fullText,

    // Visual / UX
    this.authorAvatar,
    this.commentCount = 0,
    this.viewCount = 0,
    this.isFavorited = false,
    this.readMoreLabel = 'Devamını Oku',
    this.commentLabelSuffix = ' Yorum',

    // Actions (callbacks)
    this.onOpen,
    this.onToggleFavorite,
    this.onComment,
    this.onShare,
  });

  /// Main title of the news.
  final String title;

  /// Short lead used in the card (1–3 lines).
  final String summary;

  /// Displayed under title.
  final String authorName;

  /// Big cover image for the card.
  /// NOTE: In your widgets you can decide whether this is [AssetImage] or [NetworkImage].
  final String? heroImage;

  /// URL of the news detail page (if you want to open in browser, share, etc.).
  final String? detailUrl;

  /// Machine-friendly publish date.
  final DateTime? publishedAt;

  /// Human-friendly publish date string (e.g. "12 Kasım 2025").
  final String? publishedAtText;

  /// Tags / categories (e.g. ["Siber Güvenlik", "Etkinlik"]).
  final List<String> tags;

  /// All images for the detail page carousel.
  /// You can store absolute URLs or asset paths; the widget decides how to render.
  final List<String> imageUrls;

  /// Full body text for the detail page.
  /// If null, you can fall back to [summary].
  final String? fullText;

  /// Small circle avatar (optional).
  final ImageProvider? authorAvatar;

  /// Counters
  final int commentCount;
  final int viewCount;

  /// Favorite state for the heart icon.
  final bool isFavorited;

  /// Labels (override if needed for localization/custom text)
  final String readMoreLabel;
  final String commentLabelSuffix;

  /// Actions (wire these to your app logic)
  final VoidCallback? onOpen;
  final ValueChanged<bool>? onToggleFavorite;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  NewsView copyWith({
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
    ImageProvider? authorAvatar,
    int? commentCount,
    int? viewCount,
    bool? isFavorited,
    String? readMoreLabel,
    String? commentLabelSuffix,
    VoidCallback? onOpen,
    ValueChanged<bool>? onToggleFavorite,
    VoidCallback? onComment,
    VoidCallback? onShare,
  }) {
    return NewsView(
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
      authorAvatar: authorAvatar ?? this.authorAvatar,
      commentCount: commentCount ?? this.commentCount,
      viewCount: viewCount ?? this.viewCount,
      isFavorited: isFavorited ?? this.isFavorited,
      readMoreLabel: readMoreLabel ?? this.readMoreLabel,
      commentLabelSuffix: commentLabelSuffix ?? this.commentLabelSuffix,
      onOpen: onOpen ?? this.onOpen,
      onToggleFavorite: onToggleFavorite ?? this.onToggleFavorite,
      onComment: onComment ?? this.onComment,
      onShare: onShare ?? this.onShare,
    );
  }

  // This tells Dart: "Two news items are equal if they have the same URL"
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NewsView &&
        other.detailUrl == detailUrl; // Assuming URL is unique for every news
  }

  @override
  int get hashCode => detailUrl.hashCode;
}
