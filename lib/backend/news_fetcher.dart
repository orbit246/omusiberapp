import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:omusiber/backend/view/news_view.dart';

class NewsFetcher {
  static final NewsFetcher _instance = NewsFetcher._internal();
  factory NewsFetcher() => _instance;
  NewsFetcher._internal();

  final Duration timeout = const Duration(seconds: 30);

  // Headers to mimic a real browser
  final Map<String, String> headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Connection': 'keep-alive',
  };

  static const String _fallbackImage =
      'https://carsambamyo.omu.edu.tr/user/themes/fakulte/assets/images/omu-default-img_tr.jpeg';

  List<NewsView>? _cachedNews;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  void _log(String msg) {
    debugPrint('📝 [NewsFetcher] $msg');
  }

  void _logError(String msg, Object error) {
    debugPrint('🔴 [NewsFetcher ERROR] $msg\n   Example: $error');
  }

  Future<List<NewsView>> fetchLatestNews({bool forceRefresh = false}) async {
    // 1. Cache Check
    if (!forceRefresh && _cachedNews != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
        _log('Returning cached data.');
        return _cachedNews!;
      }
    }

    const listUrl = 'https://carsambamyo.omu.edu.tr/tr/haberler';
    _log('Fetching list from: $listUrl');

    List<NewsView> result = [];

    try {
      // Step 1: Get the list of links
      final readMoreLinks = await fetchReadMoreLinks(listUrl);

      if (readMoreLinks.isEmpty) {
        _logError('No links found!', 'Selector .btn.btn-theme.read-more might be wrong.');
      } else {
        _log('Found ${readMoreLinks.length} links. Fetching top 5...');
        
        // Step 2: Fetch details for top 5 (Wait for all to finish)
        final limitedLinks = readMoreLinks.take(5).toList();
        
        // We use a loop here instead of Future.wait to debug easier and not crash everything on one fail
        for (final uri in limitedLinks) {
           final newsItem = await _safeFetchNewsDetail(uri);
           result.add(newsItem);
        }
      }
    } catch (e, stack) {
      _logError('CRITICAL FAILURE in fetchLatestNews', e);
      debugPrintStack(stackTrace: stack);
    }

    // 3. Save to Cache (even if some items are partial)
    if (result.isNotEmpty) {
      _cachedNews = result;
      _lastFetchTime = DateTime.now();
      _log('Fetch Complete. Loaded ${result.length} items.');
      return result;
    }

    _log('returning fallback data because result list is empty.');
    return [_getExampleNews()];
  }

  Future<NewsView> _safeFetchNewsDetail(Uri url) async {
    try {
      return await fetchNewsDetail(url);
    } catch (e) {
      // If a specific news item fails, we return a "Broken" item so you can see it in the UI
      _logError('Failed to parse details for $url', e);
      return NewsView(
        title: "Hata: Haber Yüklenemedi",
        summary: "Bu haberin detayları çekilirken bir hata oluştu: $e",
        heroImage: _fallbackImage,
        authorName: "Hata",
        authorAvatar: null,
        detailUrl: url.toString(),
      );
    }
  }

  Future<NewsView> fetchNewsDetail(Uri url) async {
    _log('Requesting detail: $url');
    
    final response = await http.get(url, headers: headers).timeout(timeout);
    
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }

    final doc = html_parser.parse(response.body);

    // --- PARSING ---
    
    // Title
    var title = doc.querySelector('h1.heading-title')?.text.trim();
    if (title == null || title.isEmpty) {
      _log('⚠️ [PARSER WARNING] Title missing for $url');
      title = 'Başlıksız Haber';
    }

    // Author
    String authorName = 'Bilinmeyen Yazar';
    final meta = doc.querySelector('.news-item .meta.text-muted');
    if (meta != null) {
      final authorEl = meta.querySelector('a');
      if (authorEl != null) authorName = authorEl.text.trim();
    } else {
      _log('⚠️ [PARSER WARNING] Author meta tag missing for $url');
    }

    // Image
    String? heroImage;
    final heroSrc = doc.querySelector('.news-item .featured-image img')?.attributes['src'];
    if (heroSrc != null && heroSrc.trim().isNotEmpty) {
      final raw = heroSrc.trim();
      heroImage = raw.startsWith('http') ? raw : url.resolve(raw).toString();
    }

    // Summary (Content)
    String summary = '';
    final article = doc.querySelector('article.news-item');
    if (article != null) {
      final paragraphs = article.querySelectorAll('p')
          .map((p) => p.text.trim())
          .where((t) => t.isNotEmpty && !t.startsWith('Yazar:') && !t.contains('Tarih:'))
          .toList();
      summary = paragraphs.join('\n\n');
    }

    if (summary.isEmpty) {
       _log('⚠️ [PARSER WARNING] Content (summary) empty for $url');
       summary = "İçerik bulunamadı.";
    }

    return NewsView(
      title: title,
      summary: summary,
      heroImage: heroImage ?? _fallbackImage,
      authorName: authorName,
      authorAvatar: null,
      detailUrl: url.toString(),
    );
  }



  Future<List<Uri>> fetchReadMoreLinks(String websiteUrl) async {
    final uri = Uri.parse(websiteUrl);
    final response = await http.get(uri, headers: headers).timeout(timeout);

    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }

    final doc = html_parser.parse(response.body);
    // Selector for OMU news buttons
    final elements = doc.querySelectorAll('.btn.btn-theme.read-more');
    
    final out = <Uri>{};
    for (final el in elements) {
      String? href = el.attributes['href'] ?? el.attributes['data-href'];
      if (href != null && href.trim().isNotEmpty) {
        Uri link = Uri.parse(href.trim());
        if (!link.hasScheme) link = uri.resolveUri(link);
        out.add(link);
      }
    }
    return out.toList();
  }

  NewsView _getExampleNews() {
    return NewsView(
      title: "Bağlantı Sorunu",
      summary: "İnternet bağlantınızı kontrol edin.",
      heroImage: _fallbackImage,
      authorName: "Sistem",
      authorAvatar: null,
      detailUrl: "https://carsambamyo.omu.edu.tr/tr/haberler",
    );
  }
}