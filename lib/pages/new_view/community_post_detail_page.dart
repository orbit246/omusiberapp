import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omusiber/backend/community_repository.dart';
import 'package:omusiber/backend/share_service.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/widgets/community_post_card.dart';

class CommunityPostDetailPage extends StatefulWidget {
  const CommunityPostDetailPage({super.key, required this.post});

  final CommunityPost post;

  @override
  State<CommunityPostDetailPage> createState() => _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage> {
  final CommunityRepository _repository = CommunityRepository();
  late CommunityPost _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  void _toggleReaction(String emoji) {
    final current = _post;
    final selectedReactions = {...current.selectedReactions};
    final reactionCounts = {...current.reactionCounts};
    final wasSelected = selectedReactions.contains(emoji);

    if (wasSelected) {
      selectedReactions.remove(emoji);
      reactionCounts[emoji] = ((reactionCounts[emoji] ?? 0) - 1).clamp(
        0,
        1 << 30,
      );
    } else {
      selectedReactions.add(emoji);
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    reactionCounts.removeWhere((_, count) => count <= 0);

    setState(() {
      _post = current.copyWith(
        reactionCounts: reactionCounts,
        selectedReactions: selectedReactions,
      );
    });

    unawaited(() async {
      try {
        final serverState = await _repository.setPostReaction(
          postId: current.id,
          emoji: emoji,
          isSelected: !wasSelected,
        );
        if (!mounted) return;
        setState(() {
          _post = _post.copyWith(
            reactionCounts: serverState.reactionCounts,
            selectedReactions: serverState.selectedReactions,
          );
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _post = current);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tepki güncellenemedi.')),
        );
      }
    }());
  }

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
            tooltip: 'Paylaş',
            onPressed: () =>
                unawaited(ShareService.shareCommunityPost(context, _post)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 40),
          children: [
            CommunityPostCard(
              post: _post,
              onReact: _toggleReaction,
              onShare: () =>
                  unawaited(ShareService.shareCommunityPost(context, _post)),
            ),
          ],
        ),
      ),
    );
  }
}
