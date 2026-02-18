import 'package:flutter/material.dart';
import 'dart:async';
import 'package:omusiber/backend/community_repository.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/widgets/community_post_card.dart';

class CommunityTabView extends StatefulWidget {
  const CommunityTabView({super.key});

  @override
  State<CommunityTabView> createState() => _CommunityTabViewState();
}

class _CommunityTabViewState extends State<CommunityTabView> {
  final CommunityRepository _repo = CommunityRepository();
  List<CommunityPost> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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

      // 2. Schedule refresh
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshInBackground();
      });
    } catch (e) {
      debugPrint("Failed to load initial community cache: $e");
      if (_posts.isEmpty) {
        _refreshInBackground();
      }
    }
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
      return const Center(child: CircularProgressIndicator());
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
