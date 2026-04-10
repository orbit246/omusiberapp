import 'package:flutter/material.dart';
import 'dart:async';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/community_repository.dart';
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
  final CommunityRepository _repo = CommunityRepository();
  List<CommunityPost> _posts = [];
  bool _isLoading = true;
  bool _refreshQueued = false;
  Timer? _backgroundRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startupController.addListener(_handleStartupChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _startupController.removeListener(_handleStartupChanged);
    _backgroundRefreshTimer?.cancel();
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
      final posts = await _repo.fetchPosts(forceRefresh: true);
      if (mounted) {
        setState(() {
          _posts = posts;
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
        padding: const EdgeInsets.only(top: 16, bottom: 80),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return CommunityPostCard(post: post, onLike: () => _toggleLike(post));
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
