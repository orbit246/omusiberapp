import 'package:flutter/material.dart';
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
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final posts = await _repo.fetchPosts();
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    final posts = await _repo.fetchPosts(forceRefresh: true);
    if (mounted) {
      setState(() {
        _posts = posts;
      });
    }
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
          return CommunityPostCard(post: post);
        },
      ),
    );
  }
}
