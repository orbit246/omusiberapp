import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:omusiber/backend/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommunityRepository {
  static final CommunityRepository _instance = CommunityRepository._internal();
  factory CommunityRepository() => _instance;
  CommunityRepository._internal();

  static const String _storageKey = 'cached_community_posts';
  List<CommunityPost> _cachedPosts = [];

  Future<List<CommunityPost>> getCachedPosts() async {
    if (_cachedPosts.isNotEmpty) return _cachedPosts;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        _cachedPosts = decoded
            .map((item) => CommunityPost.fromJson(item))
            .toList();
        return _cachedPosts;
      }
    } catch (e) {
      debugPrint('Failed to load community posts from persistent cache: $e');
    }
    return [];
  }

  // Mock data for initial display if API fails
  List<CommunityPost> get _mockPosts => [
    CommunityPost(
      id: 'mock-1',
      authorName: 'AkademiZ Admin',
      authorImage:
          'https://ui-avatars.com/api/?name=OM&background=0D8ABC&color=fff',
      content:
          'Hoşgeldiniz! Topluluğumuzda fikirlerinizi paylaşabilir, sorular sorabilirsiniz.',
      createdAt: DateTime(2025, 2, 11, 10, 0), // Fixed older date
      likes: 12,
      imageUrl:
          'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?auto=format&fit=crop&w=800&q=80',
    ),
    CommunityPost(
      id: 'mock-2',
      authorName: 'Selim Y.',
      authorImage: null,
      content:
          'Flutter ile mobil uygulama geliştirme etkinliği çok verimliydi, teşekkürler!',
      createdAt: DateTime(2025, 2, 10, 10, 0),
      likes: 5,
    ),
    CommunityPost(
      id: 'mock-3',
      authorName: 'AkademiZ Anket',
      authorImage: null,
      content: 'Hangi programlama dilini daha çok seviyorsunuz?',
      createdAt: DateTime(2025, 2, 11, 14, 0),
      likes: 42,
      poll: PollModel(
        id: 'poll-1',
        question: 'Favori diliniz hangisi?',
        options: [
          PollOption(id: 'opt-1', text: 'Dart / Flutter', votes: 120),
          PollOption(id: 'opt-2', text: 'Python', votes: 95),
          PollOption(id: 'opt-3', text: 'JavaScript', votes: 60),
          PollOption(id: 'opt-4', text: 'C# / .NET', votes: 45),
        ],
        expiresAt: DateTime.now().add(const Duration(days: 3)),
      ),
    ),
    CommunityPost(
      id: 'mock-4',
      authorName: 'AkademiZ Etkinlik',
      authorImage: null,
      content: 'Gelecek haftaki buluşma için hangi gün size daha uygun?',
      createdAt: DateTime(2025, 2, 11, 15, 0),
      likes: 25,
      poll: PollModel(
        id: 'poll-2',
        question: 'Etkinlik Günü',
        options: [
          PollOption(id: 'opt-day-1', text: 'Çarşamba 14:00', votes: 15),
          PollOption(id: 'opt-day-2', text: 'Perşembe 15:00', votes: 20),
          PollOption(id: 'opt-day-3', text: 'Cuma 16:00', votes: 10),
        ],
        expiresAt: DateTime.now().add(const Duration(days: 2)),
      ),
    ),
  ];

  String get _baseUrl => '${Constants.baseUrl}/community';

  Future<List<CommunityPost>> fetchPosts({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedPosts();
      if (cached.isNotEmpty) return cached;
    }

    try {
      // Fetch real data
      final response = await http
          .get(Uri.parse('$_baseUrl/posts'))
          .timeout(
            const Duration(seconds: 5),
          ); // Increased timeout for real fetch

      List<CommunityPost> apiPosts = [];

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        apiPosts = data.map((e) => CommunityPost.fromJson(e)).toList();
      }

      // Merge mock posts "as well"
      _cachedPosts = [...apiPosts, ..._mockPosts];

      // Sort by newest
      _cachedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Persist to storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        json.encode(_cachedPosts.map((e) => e.toJson()).toList()),
      );

      return _cachedPosts;
    } catch (e) {
      debugPrint("Error fetching posts: $e");

      final cached = await getCachedPosts();
      if (cached.isNotEmpty) return cached;

      // Fallback to mock
      _cachedPosts = [..._mockPosts];
      return _cachedPosts;
    }
  }

  Future<void> createPost(String content, {String? imageUrl}) async {
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

  Future<PollModel> votePoll(String postId, String optionId) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 500));

    // Find the post in cache (mock)
    final postIndex = _cachedPosts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final post = _cachedPosts[postIndex];
      if (post.poll != null) {
        if (DateTime.now().isAfter(post.poll!.expiresAt)) {
          throw Exception("Bu oylama süresi dolmuştur.");
        }

        // Update counts
        final newOptions = post.poll!.options.map((opt) {
          if (opt.id == optionId) {
            return PollOption(id: opt.id, text: opt.text, votes: opt.votes + 1);
          }
          return opt;
        }).toList();

        final newPoll = PollModel(
          id: post.poll!.id,
          question: post.poll!.question,
          options: newOptions,
          userVotedOptionId: optionId, // Mark as voted
          expiresAt: post.poll!.expiresAt,
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
