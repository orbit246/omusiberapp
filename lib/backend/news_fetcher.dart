import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsFetcher {
  static final NewsFetcher _instance = NewsFetcher._internal();
  factory NewsFetcher() => _instance;
  NewsFetcher._internal();

  String get _baseUrl => Constants.baseUrl;
  final Duration timeout = const Duration(seconds: 30);

  // Headers to mimic a real browser or API client
  final Map<String, String> _headers = {
    'User-Agent': 'OmusiberApp/1.0',
    'Accept': 'application/json',
  };

  static const String _fallbackImage =
      'https://carsambamyo.omu.edu.tr/user/themes/fakulte/assets/images/omu-default-img_tr.jpeg';

  static const String _storageKey = 'cached_news_list';
  List<NewsView>? _cachedNews;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<List<NewsView>> getCachedNews() async {
    if (_cachedNews != null && _cachedNews!.isNotEmpty) return _cachedNews!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        _cachedNews = decoded.map((item) => NewsView.fromJson(item)).toList();
        _log('Loaded ${_cachedNews!.length} items from persistent cache.');
        return _cachedNews!;
      }
    } catch (e) {
      _logError('Failed to load news from persistent cache', e);
    }
    return [];
  }

  Future<String> _getAuthToken() async {
    var user = FirebaseAuth.instance.currentUser;
    user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
    if (user == null) {
      throw Exception('Authentication failed: no Firebase user available.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication failed: empty Firebase ID token.');
    }
    return token;
  }

  Future<Map<String, String>> _authorizedHeaders({
    bool includeJsonContentType = false,
  }) async {
    final token = await _getAuthToken();
    return {
      ..._headers,
      if (includeJsonContentType) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _log(String msg) {
    debugPrint('📝 [NewsFetcher] $msg');
  }

  void _logError(String msg, Object error) {
    debugPrint('🔴 [NewsFetcher ERROR] $msg\n   Example: $error');
  }

  Future<List<NewsView>> fetchLatestNews({bool forceRefresh = false}) async {
    // 1. Cache Check (Memory)
    if (!forceRefresh && _cachedNews != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
        _log('Returning memory cached data.');
        return _cachedNews!;
      }
    }

    // if memory cache is empty, try to load from persistent storage
    if (_cachedNews == null || _cachedNews!.isEmpty) {
      await getCachedNews();
      if (!forceRefresh && _cachedNews != null && _cachedNews!.isNotEmpty) {
        return _cachedNews!;
      }
    }

    _log('Fetching news from: $_baseUrl/news');

    List<NewsView> result = [];

    try {
      final headers = await _authorizedHeaders();
      final response = await http
          .get(Uri.parse('$_baseUrl/news'), headers: headers)
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: Uri.parse('$_baseUrl/news'),
        );
      }

      final List<dynamic> data = json.decode(response.body);
      result = data
          .map((jsonItem) => _parseNewsItem(jsonItem))
          .whereType<NewsView>()
          .toList();

      _log('Fetched ${result.length} items from API.');

      // Persist to storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        json.encode(result.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      _logError('CRITICAL FAILURE in fetchLatestNews', e);
      if (_cachedNews != null && _cachedNews!.isNotEmpty) {
        return _cachedNews!;
      }
      return [_getExampleNews()];
    }

    // 3. Save to Memory Cache
    if (result.isNotEmpty) {
      _cachedNews = result;
      _lastFetchTime = DateTime.now();
      return result;
    }

    if (_cachedNews != null && _cachedNews!.isNotEmpty) {
      return _cachedNews!;
    }

    _log('returning fallback data because result list is empty.');
    return [_getExampleNews()];
  }

  NewsView? _parseNewsItem(Map<String, dynamic> json) {
    try {
      final id = json['id'] as int? ?? 0;
      final title = json['title'] as String? ?? 'Başlıksız';
      final summary = json['summary'] as String? ?? '';
      final authorName = json['authorName'] as String? ?? 'Bilinmeyen Yazar';
      String? heroImage = json['heroImage'] as String?;

      if (heroImage == null || heroImage.isEmpty) {
        heroImage = _fallbackImage;
      } else if (!heroImage.startsWith('http')) {
        // Handle relative URLs if any (though API says they are mostly full URLs or need base)
        // API docs say "Full URL in production", but for uploads it says relative.
        // Assuming heroImage from News is absolute based on example "https://example.com/image.jpg"
        // If it starts with /, prepend base url.
        if (heroImage.startsWith('/')) {
          heroImage = '$_baseUrl$heroImage';
        }
      }

      final detailUrl = json['detailUrl'] as String?;
      final publishedAtStr = json['publishedAt'] as String?;
      final publishedAt = publishedAtStr != null
          ? DateTime.tryParse(publishedAtStr)
          : null;

      final viewCount = json['views'] as int? ?? 0;
      final likeCount = json['likes'] as int? ?? 0;

      // JSON Strings Parsing
      List<String> tags = [];
      if (json['tags'] is String) {
        try {
          tags = List<String>.from(jsonDecode(json['tags']));
        } catch (_) {}
      }

      List<String> imageUrls = [];
      if (json['imageUrls'] is String) {
        try {
          imageUrls = List<String>.from(jsonDecode(json['imageUrls']));
        } catch (_) {}
      }

      // Handle Excel Attachments (Array of objects)
      // New API says: "excelAttachments": [ { "url": "...", "content": [...] } ]
      List<Map<String, dynamic>> excelAttachments = [];
      if (json['excelAttachments'] is List) {
        excelAttachments = List<Map<String, dynamic>>.from(
          (json['excelAttachments'] as List).map(
            (e) => e as Map<String, dynamic>,
          ),
        );
      }

      return NewsView(
        id: id,
        title: title,
        summary: summary,
        heroImage: heroImage,
        authorName: authorName,
        detailUrl: detailUrl,
        publishedAt: publishedAt,
        publishedAtText:
            json['publishedAtText'] as String? ?? _formatDate(publishedAt),
        tags: tags,
        imageUrls: imageUrls,
        fullText: json['fullText'] as String?,
        excelAttachments: excelAttachments,
        viewCount: viewCount,
        likeCount: likeCount,
      );
    } catch (e) {
      _logError('Failed to parse news item', e);
      return null;
    }
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.day}.${date.month}.${date.year}';
  }

  NewsView _getExampleNews() {
    return NewsView(
      id: -1,
      title: "Bağlantı Sorunu",
      summary: "Haberler yüklenemedi. İnternet bağlantınızı kontrol edin.",
      heroImage: _fallbackImage,
      authorName: "Sistem",
      authorAvatar: null,
      detailUrl: null,
      publishedAt: DateTime(2025, 2, 10), // Fixed older date
      publishedAtText: _formatDate(DateTime(2025, 2, 10)),
    );
  }

  Future<void> trackNewsView(int newsId) async {
    if (newsId <= 0) return;
    await _postNewsInteraction(endpoint: 'view', newsId: newsId);
  }

  Future<void> trackNewsLike(int newsId, {required bool isLiked}) async {
    if (newsId <= 0 || !isLiked) return;
    await _postNewsInteraction(endpoint: 'like', newsId: newsId);
  }

  Future<void> _postNewsInteraction({
    required String endpoint,
    required int newsId,
  }) async {
    try {
      final headers = await _authorizedHeaders(includeJsonContentType: true);
      final response = await http
          .post(
            Uri.parse('$_baseUrl/news/$endpoint'),
            headers: headers,
            body: jsonEncode({'id': newsId}),
          )
          .timeout(timeout);

      if (response.statusCode != 200 && response.statusCode != 201) {
        _log(
          'news/$endpoint failed for id=$newsId '
          '(HTTP ${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      _logError('Failed to send news/$endpoint for id=$newsId', e);
    }
  }
}
