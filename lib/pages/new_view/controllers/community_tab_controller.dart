import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/background_refresh_coordinator.dart';
import 'package:omusiber/backend/cache_compare.dart';
import 'package:omusiber/backend/community_repository.dart';
import 'package:omusiber/backend/view/community_post_model.dart';

class CommunityTabController extends ChangeNotifier {
  CommunityTabController({
    CommunityRepository? repository,
    AppStartupController? startupController,
  }) : _repository = repository ?? CommunityRepository(),
       _startupController = startupController ?? AppStartupController.instance {
    _backgroundRefresh = BackgroundRefreshCoordinator(
      startupController: _startupController,
      delay: _backgroundRefreshDelay,
      refresh: refreshInBackground,
      canRefresh: () => _startupController.canUseAuthenticatedApis,
    );
    _startupController.addListener(_handleStartupChanged);
  }

  static const Duration _backgroundRefreshDelay = Duration(seconds: 4);
  static const int _pageSize = 20;

  final CommunityRepository _repository;
  final AppStartupController _startupController;
  late final BackgroundRefreshCoordinator _backgroundRefresh;

  List<CommunityPost> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _nextCursor;

  List<CommunityPost> get posts => List.unmodifiable(_posts);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _nextCursor != null && _nextCursor!.isNotEmpty;

  Future<void> loadInitialData() async {
    try {
      final cached = await _repository.getCachedPosts();
      if (cached.isNotEmpty) {
        _posts = cached;
        _isLoading = false;
        notifyListeners();
      }
    } catch (error) {
      debugPrint("Failed to load initial community cache: $error");
    } finally {
      _handleStartupChanged();
    }
  }

  Future<void> refresh() => refreshInBackground();

  Future<void> refreshInBackground() async {
    try {
      final page = await _repository.fetchPostsPage(
        forceRefresh: true,
        fallbackToCacheOnError: false,
        limit: _pageSize,
      );
      final shouldReplacePosts = !jsonListEquals<CommunityPost>(
        _posts,
        page.posts,
        (item) => item.toJson(),
      );
      final shouldClearLoading = _isLoading && _posts.isEmpty;
      final shouldUpdateCursor = _nextCursor != page.nextCursor;

      if (!shouldReplacePosts && !shouldClearLoading && !shouldUpdateCursor) {
        return;
      }

      if (shouldReplacePosts) {
        _posts = page.posts;
      }
      _nextCursor = page.nextCursor;
      _isLoadingMore = false;
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      if (error is StateError) {
        return;
      }
      debugPrint("Background refresh failed: $error");
      if (_posts.isEmpty) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMorePosts() async {
    final cursor = _nextCursor;
    if (cursor == null || cursor.isEmpty || _isLoadingMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _repository.fetchPostsPage(
        fallbackToCacheOnError: false,
        limit: _pageSize,
        cursor: cursor,
      );
      final existingIds = _posts.map((post) => post.id).toSet();
      _posts = [
        ..._posts,
        ...page.posts.where((post) => !existingIds.contains(post.id)),
      ];
      _nextCursor = page.nextCursor;
    } catch (error) {
      debugPrint('Load more community posts failed: $error');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(CommunityPost post) async {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    final current = _posts[index];
    final nextLiked = !current.isLiked;
    final nextLikes = nextLiked
        ? current.likes + (current.isLiked ? 0 : 1)
        : (current.likes - (current.isLiked ? 1 : 0)).clamp(0, 1 << 30);

    _posts = [..._posts]
      ..[index] = current.copyWith(isLiked: nextLiked, likes: nextLikes);
    notifyListeners();

    try {
      await _repository.setPostLike(postId: post.id, isLiked: nextLiked);
    } catch (_) {
      final rollbackIndex = _posts.indexWhere((p) => p.id == post.id);
      if (rollbackIndex != -1) {
        _posts = [..._posts]..[rollbackIndex] = current;
        notifyListeners();
      }
      rethrow;
    }
  }

  void _handleStartupChanged() {
    if (!_startupController.canUseAuthenticatedApis) {
      return;
    }
    _backgroundRefresh.schedule(ignoreStartupDeferral: _posts.isEmpty);
  }

  @override
  void dispose() {
    _startupController.removeListener(_handleStartupChanged);
    _backgroundRefresh.dispose();
    super.dispose();
  }
}
