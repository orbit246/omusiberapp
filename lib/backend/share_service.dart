import 'package:flutter/material.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  const ShareService._();

  static Future<void> shareNews(BuildContext context, NewsView news) {
    return _shareText(
      context,
      title: news.title,
      subject: news.title,
      text: _lines([
        news.title,
        news.summary,
        news.publishedAtText,
        _akademizUrl('news', news.id.toString()),
      ]),
    );
  }

  static Future<void> shareEvent(BuildContext context, PostView event) {
    return _shareText(
      context,
      title: event.title,
      subject: event.title,
      text: _lines([
        event.title,
        if (event.eventDate != null) _formatDateTime(event.eventDate!),
        event.location,
        event.description,
        _akademizUrl('events', event.id),
      ]),
    );
  }

  static Future<void> shareCommunityPost(
    BuildContext context,
    CommunityPost post,
  ) {
    return _shareText(
      context,
      title: post.authorName,
      subject: 'AkademiZ topluluk gonderisi',
      text: _lines([
        post.authorName,
        _formatDateTime(post.createdAt),
        post.content,
        _akademizUrl('community', post.id),
      ]),
    );
  }

  static Future<void> sharePlainText(
    BuildContext context, {
    required String title,
    required String text,
  }) {
    return _shareText(context, title: title, subject: title, text: text);
  }

  static Future<void> _shareText(
    BuildContext context, {
    required String title,
    required String subject,
    required String text,
  }) async {
    final cleanedText = _stripMarkdown(text).trim();
    if (cleanedText.isEmpty) {
      _showShareError(context);
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: cleanedText,
          title: title,
          subject: subject,
          sharePositionOrigin: _shareOrigin(context),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Share failed: $error\n$stackTrace');
      if (context.mounted) {
        _showShareError(context);
      }
    }
  }

  static Rect? _shareOrigin(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & renderObject.size;
  }

  static void _showShareError(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Paylasim baslatilamadi.')));
  }

  static String _lines(Iterable<String?> lines) {
    return lines
        .whereType<String>()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n\n');
  }

  static String _akademizUrl(String category, String id) {
    return 'https://www.nortixlabs.com/akademiz/$category/${Uri.encodeComponent(id)}';
  }

  static String _stripMarkdown(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll(RegExp(r'[*`~]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  static String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }
}
