import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/cache_compare.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:omusiber/backend/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommunityPostsPage {
  final List<CommunityPost> posts;
  final String? nextCursor;

  const CommunityPostsPage({required this.posts, this.nextCursor});
}

class CommunityRepository {
  static final CommunityRepository _instance = CommunityRepository._internal();
  factory CommunityRepository() => _instance;
  CommunityRepository._internal();

  static const String _storageKey = 'cached_community_posts';
  List<CommunityPost> _cachedPosts = [];
  String? _nextCursor;

  String? get nextCursor => _nextCursor;

  Future<List<CommunityPost>> getCachedPosts() async {
    if (_cachedPosts.isNotEmpty) {
      _cachedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _cachedPosts;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        _cachedPosts = decoded
            .map((item) => CommunityPost.fromJson(item))
            .toList();
        _cachedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return _cachedPosts;
      }
    } catch (e) {
      debugPrint('Failed to load community posts from persistent cache: $e');
    }
    return [];
  }

  // Mock data removed

  String get _baseUrl => '${Constants.baseUrl}/community';

  Future<Map<String, String>> _authorizedHeaders({
    bool includeJsonContentType = false,
  }) async {
    final token = await _getOptionalAuthToken();
    return {
      if (includeJsonContentType) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _requiredAuthorizedHeaders({
    bool includeJsonContentType = false,
  }) async {
    final ready = await AppStartupController.instance
        .ensureAuthenticatedSession();
    if (!ready) {
      throw StateError('Authentication is not ready yet.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Authentication failed: no Firebase user available.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication failed: empty Firebase ID token.');
    }

    return {
      if (includeJsonContentType) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<String?> _getOptionalAuthToken() async {
    final ready = await AppStartupController.instance.ensureFirebaseReady();
    if (!ready) {
      return null;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        return null;
      }
      return token;
    } catch (e) {
      debugPrint('Community fetch proceeding without auth token: $e');
      return null;
    }
  }

  Future<List<CommunityPost>> fetchPosts({bool forceRefresh = false}) async {
    final page = await fetchPostsPage(forceRefresh: forceRefresh);
    return page.posts;
  }

  Future<CommunityPostsPage> fetchPostsPage({
    bool forceRefresh = false,
    bool fallbackToCacheOnError = true,
    int? limit,
    String? cursor,
  }) async {
    final isFirstPage = cursor == null || cursor.isEmpty;
    if (isFirstPage && !forceRefresh) {
      final cached = await getCachedPosts();
      if (cached.isNotEmpty) {
        return CommunityPostsPage(posts: cached, nextCursor: _nextCursor);
      }
    }

    try {
      final headers = await _authorizedHeaders();
      final queryParameters = <String, String>{
        if (limit != null) 'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      };
      final uri = Uri.parse('$_baseUrl/posts').replace(
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      );
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 5));

      List<CommunityPost> apiPosts = [];
      final nextCursor = response.headers['x-next-cursor'];

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded is List
            ? decoded
            : (decoded is Map<String, dynamic> && decoded['posts'] is List
                  ? decoded['posts'] as List<dynamic>
                  : <dynamic>[]);

        for (final item in data) {
          try {
            if (item is Map<String, dynamic>) {
              apiPosts.add(CommunityPost.fromJson(item));
            } else if (item is Map) {
              apiPosts.add(
                CommunityPost.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          } catch (e) {
            debugPrint('Skipping malformed community post: $e');
          }
        }
      } else {
        debugPrint(
          'Community posts request failed: HTTP ${response.statusCode}',
        );
      }

      final sortedPosts = apiPosts
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (isFirstPage) {
        if (!jsonListEquals<CommunityPost>(
          _cachedPosts,
          sortedPosts,
          (item) => item.toJson(),
        )) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _storageKey,
            json.encode(sortedPosts.map((e) => e.toJson()).toList()),
          );
        }
        _cachedPosts = sortedPosts;
        _nextCursor = nextCursor;
      } else {
        _nextCursor = nextCursor;
      }

      return CommunityPostsPage(posts: sortedPosts, nextCursor: nextCursor);
    } catch (e) {
      debugPrint("Error fetching posts: $e");

      if (isFirstPage && fallbackToCacheOnError) {
        final cached = await getCachedPosts();
        if (cached.isNotEmpty) {
          return CommunityPostsPage(posts: cached, nextCursor: _nextCursor);
        }
      }

      if (!fallbackToCacheOnError) {
        rethrow;
      }

      return const CommunityPostsPage(posts: []);
    }
  }

  Future<CommunityPost?> fetchPostById(String postId) async {
    final normalizedId = postId.trim();
    if (normalizedId.isEmpty) return null;

    for (final post in await getCachedPosts()) {
      if (post.id == normalizedId) {
        return post;
      }
    }

    try {
      final headers = await _authorizedHeaders();
      final response = await http
          .get(Uri.parse('$_baseUrl/posts/$normalizedId'), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return _findPostInFreshPage(normalizedId);
      }

      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['post'] is Map) {
        final post = CommunityPost.fromJson(
          Map<String, dynamic>.from(decoded['post'] as Map),
        );
        _upsertCachedPost(post);
        return post;
      }
      if (decoded is Map<String, dynamic>) {
        final post = CommunityPost.fromJson(decoded);
        _upsertCachedPost(post);
        return post;
      }
    } catch (e) {
      debugPrint('Fetch community post by id failed: $e');
    }

    return _findPostInFreshPage(normalizedId);
  }

  Future<CommunityPost?> _findPostInFreshPage(String postId) async {
    try {
      final page = await fetchPostsPage(
        forceRefresh: true,
        fallbackToCacheOnError: true,
        limit: 50,
      );
      for (final post in page.posts) {
        if (post.id == postId) {
          return post;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> createPost(String content, {String? imageUrl}) async {
    final ready = await AppStartupController.instance
        .ensureAuthenticatedSession();
    if (!ready) {
      throw Exception('Giriş hazır değil');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Giriş yapmalısınız");

    final newPost = CommunityPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      authorName: user.displayName ?? "Kullanıcı",
      authorImage: user.photoURL,
      content: content,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      likes: 0,
    );

    // Optimistic update
    _cachedPosts.insert(0, newPost);

    // Simulate API call
    // await http.post(...)
    await Future.delayed(const Duration(milliseconds: 1000));

    // If API call fails, remove from cache and throw error
  }

  Future<void> setPostLike({
    required String postId,
    required bool isLiked,
  }) async {
    final headers = await _requiredAuthorizedHeaders(
      includeJsonContentType: true,
    );
    final int? idAsInt = int.tryParse(postId);
    final List<_LikeRequest> requests = [
      _LikeRequest(uri: Uri.parse('$_baseUrl/posts/$postId/like'), body: null),
      _LikeRequest(
        uri: Uri.parse('$_baseUrl/posts/like'),
        body: {'id': idAsInt ?? postId, 'isLiked': isLiked},
      ),
      _LikeRequest(
        uri: Uri.parse('$_baseUrl/like'),
        body: {'id': idAsInt ?? postId, 'isLiked': isLiked},
      ),
    ];

    Object? lastError;
    for (final req in requests) {
      try {
        final response = await http
            .post(
              req.uri,
              headers: headers,
              body: req.body == null ? null : jsonEncode(req.body),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _updateLikeInCache(postId: postId, isLiked: isLiked);
          return;
        }

        lastError = Exception(
          'HTTP ${response.statusCode} on ${req.uri.path}: ${response.body}',
        );
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Failed to update like for post $postId: $lastError');
  }

  void _updateLikeInCache({required String postId, required bool isLiked}) {
    final idx = _cachedPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final current = _cachedPosts[idx];
    final int nextLikes = isLiked
        ? current.likes + (current.isLiked ? 0 : 1)
        : (current.likes - (current.isLiked ? 1 : 0)).clamp(0, 1 << 30);

    _cachedPosts[idx] = current.copyWith(isLiked: isLiked, likes: nextLikes);

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        _storageKey,
        json.encode(_cachedPosts.map((e) => e.toJson()).toList()),
      );
    });
  }

  void _upsertCachedPost(CommunityPost post) {
    final idx = _cachedPosts.indexWhere((p) => p.id == post.id);
    if (idx == -1) {
      _cachedPosts.insert(0, post);
    } else {
      _cachedPosts[idx] = post;
    }
    _cachedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        _storageKey,
        json.encode(_cachedPosts.map((e) => e.toJson()).toList()),
      );
    });
  }

  Future<PollModel> votePoll(String postId, String optionId) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 500));

    // Find the post in cache (mock)
    final postIndex = _cachedPosts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final post = _cachedPosts[postIndex];
      if (post.poll != null) {
        final poll = post.poll!;
        final isClosed = poll.isClosed || DateTime.now().isAfter(poll.closesAt);
        if (isClosed) {
          throw Exception("Bu oylama suresi dolmustur.");
        }

        // Update counts
        final newOptions = poll.options.map((opt) {
          if (opt.id == optionId) {
            return PollOption(id: opt.id, text: opt.text, votes: opt.votes + 1);
          }
          return opt;
        }).toList();

        final newPoll = PollModel(
          id: poll.id,
          question: poll.question,
          options: newOptions,
          userVotedOptionId: optionId,
          closesAt: poll.closesAt,
          isClosed: false,
        );

        // Update post in cache
        _cachedPosts[postIndex] = CommunityPost(
          id: post.id,
          authorName: post.authorName,
          authorImage: post.authorImage,
          content: post.content,
          imageUrl: post.imageUrl,
          createdAt: post.createdAt,
          likes: post.likes,
          isLiked: post.isLiked,
          poll: newPoll,
        );
        return newPoll;
      }
    }
    throw Exception("Post or Poll not found");
  }
}

class _LikeRequest {
  final Uri uri;
  final Map<String, dynamic>? body;

  const _LikeRequest({required this.uri, required this.body});
}
