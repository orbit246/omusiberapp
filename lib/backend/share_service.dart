import 'package:flutter/material.dart';
import 'package:omusiber/backend/deep_link_service.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  const ShareService._();

  static Future<void> shareNews(BuildContext context, NewsView news) {
    return _shareLink(
      context,
      title: news.title,
      subject: news.title,
      link: AkademizDeepLink.newsUri(news.id).toString(),
    );
  }

  static Future<void> shareEvent(BuildContext context, PostView event) {
    return _shareLink(
      context,
      title: event.title,
      subject: event.title,
      link: AkademizDeepLink.eventUri(event.id).toString(),
    );
  }

  static Future<void> shareCommunityPost(
    BuildContext context,
    CommunityPost post,
  ) {
    return _shareLink(
      context,
      title: post.authorName,
      subject: 'AkademiZ topluluk gönderisi',
      link: AkademizDeepLink.communityPostUri(post.id).toString(),
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

  static Future<void> _shareLink(
    BuildContext context, {
    required String title,
    required String subject,
    required String link,
  }) {
    return _shareText(context, title: title, subject: subject, text: link);
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
      ..showSnackBar(const SnackBar(content: Text('Paylaşım başlatılamadı.')));
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
}
