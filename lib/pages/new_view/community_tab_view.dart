import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omusiber/backend/share_service.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/pages/new_view/controllers/community_tab_controller.dart';
import 'package:omusiber/widgets/community_post_card.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';

class CommunityTabView extends StatefulWidget {
  const CommunityTabView({super.key});

  @override
  State<CommunityTabView> createState() => _CommunityTabViewState();
}

class _CommunityTabViewState extends State<CommunityTabView> {
  late final CommunityTabController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = CommunityTabController();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.loadInitialData());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _controller.isLoadingMore ||
        !_controller.canLoadMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 320) {
      return;
    }

    unawaited(_controller.loadMorePosts());
  }

  void _toggleLike(CommunityPost post) {
    unawaited(
      _controller.toggleLike(post).catchError((error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Beğeni güncellenemedi.')));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CommunityTabContent(
          posts: _controller.posts,
          isLoading: _controller.isLoading,
          isLoadingMore: _controller.isLoadingMore,
          scrollController: _scrollController,
          onRefresh: _controller.refresh,
          onLike: _toggleLike,
          onShare: (post) =>
              unawaited(ShareService.shareCommunityPost(context, post)),
        );
      },
    );
  }
}

class CommunityTabContent extends StatelessWidget {
  const CommunityTabContent({
    super.key,
    required this.posts,
    required this.isLoading,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onRefresh,
    required this.onLike,
    required this.onShare,
  });

  final List<CommunityPost> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final ValueChanged<CommunityPost> onLike;
  final ValueChanged<CommunityPost> onShare;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const CommunityLoadingState();
    }

    if (posts.isEmpty) {
      return const Center(child: Text('Henüz gönderi yok.'));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(top: 16, bottom: 80),
        itemCount: posts.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final post = posts[index];
          return CommunityPostCard(
            post: post,
            onLike: () => onLike(post),
            onShare: () => onShare(post),
          );
        },
      ),
    );
  }
}

class CommunityLoadingState extends StatelessWidget {
  const CommunityLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppSkeleton(
                      height: 34,
                      width: 34,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton(
                          height: 10,
                          width: 96,
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        SizedBox(height: 7),
                        AppSkeleton(
                          height: 9,
                          width: 64,
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 14),
                AppSkeleton(
                  height: 10,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                SizedBox(height: 7),
                AppSkeleton(
                  height: 10,
                  width: 190,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                SizedBox(height: 14),
                AppSkeleton(
                  height: 148,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
