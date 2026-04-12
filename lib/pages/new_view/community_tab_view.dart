import 'package:flutter/material.dart';
import 'dart:async';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/cache_compare.dart';
import 'package:omusiber/backend/community_repository.dart';
import 'package:omusiber/backend/share_service.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/widgets/community_post_card.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';

class CommunityTabView extends StatefulWidget {
  const CommunityTabView({super.key});

  @override
  State<CommunityTabView> createState() => _CommunityTabViewState();
}

class _CommunityTabViewState extends State<CommunityTabView> {
  final AppStartupController _startupController = AppStartupController.instance;
  static const Duration _backgroundRefreshDelay = Duration(seconds: 4);
  static const int _pageSize = 20;
  final CommunityRepository _repo = CommunityRepository();
  final ScrollController _scrollController = ScrollController();
  List<CommunityPost> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _refreshQueued = false;
  String? _nextCursor;
  Timer? _backgroundRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startupController.addListener(_handleStartupChanged);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _startupController.removeListener(_handleStartupChanged);
    _backgroundRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleStartupChanged() {
    if (!_startupController.canUseAuthenticatedApis || _refreshQueued) {
      return;
    }

    _scheduleBackgroundRefresh();
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. Load from cache first
      final cached = await _repo.getCachedPosts();
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _posts = cached;
          _isLoading = false;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleStartupChanged();
      });
    } catch (e) {
      debugPrint("Failed to load initial community cache: $e");
      if (_posts.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleStartupChanged();
        });
      }
    }
  }

  void _scheduleBackgroundRefresh() {
    final delay = _startupController.startupDeferral(_backgroundRefreshDelay);
    _backgroundRefreshTimer?.cancel();
    if (delay == Duration.zero) {
      _refreshQueued = true;
      unawaited(
        _refreshInBackground().whenComplete(() {
          _refreshQueued = false;
        }),
      );
      return;
    }
    _backgroundRefreshTimer = Timer(delay, () {
      if (!mounted || _refreshQueued) {
        return;
      }
      _refreshQueued = true;
      unawaited(
        _refreshInBackground().whenComplete(() {
          _refreshQueued = false;
        }),
      );
    });
  }

  Future<void> _refreshInBackground() async {
    try {
      final page = await _repo.fetchPostsPage(
        forceRefresh: true,
        limit: _pageSize,
      );
      final posts = page.posts;
      if (mounted) {
        final shouldReplacePosts = !jsonListEquals<CommunityPost>(
          _posts,
          posts,
          (item) => item.toJson(),
        );
        final shouldClearLoading = _isLoading && _posts.isEmpty;
        final shouldUpdateCursor = _nextCursor != page.nextCursor;

        if (!shouldReplacePosts && !shouldClearLoading && !shouldUpdateCursor) {
          return;
        }

        setState(() {
          if (shouldReplacePosts) {
            _posts = posts;
          }
          _nextCursor = page.nextCursor;
          _isLoadingMore = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e is StateError) {
        return;
      }
      debugPrint("Background refresh failed: $e");
      if (mounted && _posts.isEmpty) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _refreshInBackground();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore) {
      return;
    }
    if (_nextCursor == null || _nextCursor!.isEmpty) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 320) {
      return;
    }

    unawaited(_loadMorePosts());
  }

  Future<void> _loadMorePosts() async {
    final cursor = _nextCursor;
    if (cursor == null || cursor.isEmpty || _isLoadingMore) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final page = await _repo.fetchPostsPage(limit: _pageSize, cursor: cursor);
      if (!mounted) return;

      final existingIds = _posts.map((post) => post.id).toSet();
      final mergedPosts = [
        ..._posts,
        ...page.posts.where((post) => !existingIds.contains(post.id)),
      ];

      setState(() {
        _posts = mergedPosts;
        _nextCursor = page.nextCursor;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Load more community posts failed: $e');
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _toggleLike(CommunityPost post) {
    final int index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    final current = _posts[index];
    final nextLiked = !current.isLiked;
    final nextLikes = nextLiked
        ? current.likes + (current.isLiked ? 0 : 1)
        : (current.likes - (current.isLiked ? 1 : 0)).clamp(0, 1 << 30);

    setState(() {
      _posts[index] = current.copyWith(isLiked: nextLiked, likes: nextLikes);
    });

    unawaited(
      _repo.setPostLike(postId: post.id, isLiked: nextLiked).catchError((
        error,
      ) {
        if (!mounted) return;
        setState(() {
          _posts[index] = current;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Begeni guncellenemedi.')));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _CommunityLoadingState();
    }

    if (_posts.isEmpty) {
      return const Center(child: Text('Henüz gönderi yok.'));
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 16, bottom: 80),
        itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final post = _posts[index];
          return CommunityPostCard(
            post: post,
            onLike: () => _toggleLike(post),
            onShare: () =>
                unawaited(ShareService.shareCommunityPost(context, post)),
          );
        },
      ),
    );
  }
}

class _CommunityLoadingState extends StatelessWidget {
  const _CommunityLoadingState();

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
