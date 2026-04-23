import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omusiber/backend/share_service.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/widgets/community_post_card.dart';

class CommunityPostDetailPage extends StatelessWidget {
  const CommunityPostDetailPage({super.key, required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Topluluk'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Paylas',
            onPressed: () =>
                unawaited(ShareService.shareCommunityPost(context, post)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 40),
          children: [
            CommunityPostCard(
              post: post,
              onShare: () =>
                  unawaited(ShareService.shareCommunityPost(context, post)),
            ),
          ],
        ),
      ),
    );
  }
}
