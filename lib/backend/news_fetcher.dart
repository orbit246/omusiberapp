import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsFaculty {
  final String name;
  final String slug;

  const NewsFaculty({required this.name, required this.slug});

  factory NewsFaculty.fromJson(Map<String, dynamic> json) {
    return NewsFaculty(
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }
}

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
  List<NewsFaculty>? _cachedFaculties;
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
    final ready = await AppStartupController.instance
        .ensureAuthenticatedSession();
    if (!ready) {
      throw StateError('Authentication is not ready yet.');
    }
    var user = FirebaseAuth.instance.currentUser;
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

  Future<List<NewsFaculty>> fetchFaculties({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedFaculties != null) {
      return _cachedFaculties!;
    }

    final uri = Uri.parse('$_baseUrl/faculties');
    _log('Fetching faculties from: $uri');

    try {
      final response = await http.get(uri, headers: _headers).timeout(timeout);

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }

      final List<dynamic> data = json.decode(response.body);
      final faculties =
          data
              .whereType<Map<String, dynamic>>()
              .map(NewsFaculty.fromJson)
              .where((faculty) {
                return faculty.name.trim().isNotEmpty &&
                    faculty.slug.trim().isNotEmpty;
              })
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      _cachedFaculties = faculties;
      _log('Fetched ${faculties.length} faculties from API.');
      return faculties;
    } catch (e) {
      _logError('Failed to fetch faculties', e);
      return _cachedFaculties ?? [];
    }
  }

  Future<List<NewsView>> fetchLatestNews({
    bool forceRefresh = false,
    String? facultySlug,
  }) async {
    final normalizedFacultySlug = facultySlug?.trim();
    final hasFacultyFilter =
        normalizedFacultySlug != null && normalizedFacultySlug.isNotEmpty;

    // 1. Cache Check (Memory)
    if (!hasFacultyFilter &&
        !forceRefresh &&
        _cachedNews != null &&
        _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
        _log('Returning memory cached data.');
        return _cachedNews!;
      }
    }

    // if memory cache is empty, try to load from persistent storage
    if (!hasFacultyFilter && (_cachedNews == null || _cachedNews!.isEmpty)) {
      await getCachedNews();
      if (!forceRefresh && _cachedNews != null && _cachedNews!.isNotEmpty) {
        return _cachedNews!;
      }
    }

    final uri = Uri.parse('$_baseUrl/news').replace(
      queryParameters: hasFacultyFilter
          ? <String, String>{'faculty': normalizedFacultySlug}
          : null,
    );

    _log('Fetching news from: $uri');

    List<NewsView> result = [];

    try {
      final headers = await _authorizedHeaders();
      final response = await http.get(uri, headers: headers).timeout(timeout);

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }

      final List<dynamic> data = json.decode(response.body);
      result = data
          .map((jsonItem) => _parseNewsItem(jsonItem))
          .whereType<NewsView>()
          .toList();

      _log('Fetched ${result.length} items from API.');

      if (!hasFacultyFilter) {
        // Persist only the default feed so faculty-filtered results do not
        // replace the normal cached news list.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _storageKey,
          json.encode(result.map((e) => e.toJson()).toList()),
        );
      }
    } catch (e) {
      if (e is StateError) {
        rethrow;
      }
      _logError('CRITICAL FAILURE in fetchLatestNews', e);
      if (!hasFacultyFilter && _cachedNews != null && _cachedNews!.isNotEmpty) {
        return _cachedNews!;
      }
      return [];
    }

    // 3. Save to Memory Cache
    if (result.isNotEmpty) {
      if (!hasFacultyFilter) {
        _cachedNews = result;
        _lastFetchTime = DateTime.now();
      }
      return result;
    }

    if (!hasFacultyFilter && _cachedNews != null && _cachedNews!.isNotEmpty) {
      return _cachedNews!;
    }

    _log('returning empty list because result list is empty.');
    return [];
  }

  NewsView? _parseNewsItem(Map<String, dynamic> json) {
    try {
      final id = json['id'] as int? ?? 0;
      final title = json['title'] as String? ?? 'Başlıksız';
      final summary = json['summary'] as String? ?? '';
      final authorName = json['authorName'] as String? ?? 'Sistem';
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

      final viewCount = json['views'] as int? ?? json['viewCount'] as int? ?? 0;
      final likeCount = json['likes'] as int? ?? json['likeCount'] as int? ?? 0;
      final isLiked =
          json['isLiked'] as bool? ?? json['isFavorited'] as bool? ?? false;

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
        isFavorited: isLiked,
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
