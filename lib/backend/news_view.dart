import 'package:flutter/material.dart';
import 'package:omusiber/pages/news_item_page.dart';
import 'package:omusiber/widgets/news/news_card_item.dart';

/// Lightweight view model for NewsCard.
/// Put *all* text/data here so the widget stays presentational.
class NewsView {
  const NewsView({
    required this.title,
    required this.summary,
    required this.authorName,
    required this.heroImage,
    this.authorAvatar,
    this.commentCount = 0,
    this.viewCount = 0,
    this.isFavorited = false,
    this.readMoreLabel = 'Devamını Oku',
    this.commentLabelSuffix = ' Yorum',
    this.onOpen,
    this.onToggleFavorite,
    this.onComment,
    this.onShare,
  });

  /// Main title of the news.
  final String title;

  /// 1–3 line summary/lead.
  final String summary;

  /// Displayed under title.
  final String authorName;

  /// Big cover image (required).
  final String heroImage;

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
}