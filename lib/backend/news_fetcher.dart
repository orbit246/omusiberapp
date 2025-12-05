import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:omusiber/backend/news_view.dart';

class NewsFetcher {
  // Singleton pattern
  static final NewsFetcher _instance = NewsFetcher._internal();
  factory NewsFetcher() => _instance;
  NewsFetcher._internal();

  // Settings
  final Duration timeout = const Duration(seconds: 10);
  final Map<String, String> headers = {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119 Safari/537.36',
  };

  static const String _fallbackImage =
      'https://carsambamyo.omu.edu.tr/user/themes/fakulte/assets/images/omu-default-img_tr.jpeg';

  // --- CACHING VARIABLES ---
  List<NewsView>? _cachedNews;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  void _log(String msg) {
    debugPrint('[NewsFetcher] $msg');
  }

  /// Fetches news. 
  /// 1. Checks Cache (30 min).
  /// 2. Fetches Network.
  /// 3. If BOTH fail (empty list), returns a dummy Example News.
  Future<List<NewsView>> fetchLatestNews({bool forceRefresh = false}) async {
    // 1. Check Cache
    if (!forceRefresh && _cachedNews != null && _lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      if (difference < _cacheDuration) {
        _log('CACHE HIT: Returning data fetched ${difference.inMinutes} mins ago.');
        return _cachedNews!;
      }
    }

    // 2. Network Fetch Logic
    const listUrl = 'https://carsambamyo.omu.edu.tr/tr/haberler';
    _log('fetchLatestNews() START (Network Call), listUrl=$listUrl');

    List<NewsView> result = [];

    try {
      final readMoreLinks = await fetchReadMoreLinks(listUrl);
      
      if (readMoreLinks.isNotEmpty) {
        final limitedLinks = readMoreLinks.take(5).toList();
        final futures = limitedLinks.map((uri) => _safeFetchNewsDetail(uri)).toList();
        result = await Future.wait(futures);
      }
    } catch (e) {
      _log('ERROR fetching news: $e');
      // Do not throw here, we want to fall through to the example check
    }

    // 3. Update Cache (Only if we found real news)
    if (result.isNotEmpty) {
      _cachedNews = result;
      _lastFetchTime = DateTime.now();
      _log('CACHE UPDATED: Stored ${result.length} items.');
      return result;
    }

    // 4. LAST RESORT: Return Example News if list is still empty
    _log('NO DATA: Returning static example news.');
    return [_getExampleNews()];
  }

  /// Generates a dummy news item for testing or offline states
  NewsView _getExampleNews() {
    return NewsView(
      title: "OMÜ Siber Kulübü'ne Hoşgeldiniz",
      summary: "Haberler şu anda yüklenemedi veya internet bağlantısı yok. "
          "Bu, uygulamanın boş görünmemesi için oluşturulmuş örnek bir haberdir. "
          "Lütfen internet bağlantınızı kontrol edip sayfayı yenileyiniz.",
      heroImage: _fallbackImage,
      authorName: "Sistem Yöneticisi",
      authorAvatar: null,
      detailUrl: "https://carsambamyo.omu.edu.tr/tr/haberler",
    );
  }

  // --- PRIVATE HELPERS ---

  Future<NewsView> _safeFetchNewsDetail(Uri url) async {
    try {
      return await fetchNewsDetail(url);
    } catch (e) {
      _log('SAFE WRAPPER: Error for $url: $e');
      return NewsView(
        title: _fallbackTitleFromUrl(url),
        summary: 'Bu haberin detayları yüklenirken bir sorun oluştu.',
        heroImage: _fallbackImage,
        authorName: 'Bilinmeyen Yazar',
        authorAvatar: null,
        detailUrl: url.toString(),
      );
    }
  }

  Future<NewsView> fetchNewsDetail(Uri url) async {
    final res = await http.get(url, headers: headers).timeout(timeout);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

    final doc = html_parser.parse(res.body);

    final title = doc.querySelector('h1.heading-title')?.text.trim() ?? 'Başlık Yok';
    
    String authorName = 'Bilinmeyen Yazar';
    final meta = doc.querySelector('.news-item .meta.text-muted');
    if (meta != null) {
      final authorEl = meta.querySelector('a');
      if (authorEl != null) authorName = authorEl.text.trim();
    }

    String? heroImage;
    final heroSrc = doc.querySelector('.news-item .featured-image img')?.attributes['src'];
    if (heroSrc != null && heroSrc.trim().isNotEmpty) {
      final raw = heroSrc.trim();
      heroImage = raw.startsWith('http') ? raw : url.resolve(raw).toString();
    }

    String summary = '';
    final article = doc.querySelector('article.news-item');
    if (article != null) {
      final paragraphs = article.querySelectorAll('p')
          .map((p) => p.text.trim())
          .where((t) => t.isNotEmpty && !t.startsWith('Yazar:') && !t.contains('Tarih:'))
          .toList();
      summary = paragraphs.join('\n\n');
    }

    return NewsView(
      title: title,
      summary: summary,
      heroImage: heroImage ?? _fallbackImage,
      authorName: authorName,
      authorAvatar: null,
      detailUrl: url.toString()
    );
  }

  Future<List<Uri>> fetchReadMoreLinks(String websiteUrl) async {
    final baseUri = Uri.parse(websiteUrl);
    final res = await http.get(baseUri, headers: headers).timeout(timeout);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

    final doc = html_parser.parse(res.body);
    final elements = doc.querySelectorAll('.btn.btn-theme.read-more');
    final out = <Uri>{};

    for (final el in elements) {
      String? href = el.attributes['href'] ?? el.attributes['data-href'];
      if (href != null && href.trim().isNotEmpty) {
        Uri link = Uri.parse(href.trim());
        if (!link.hasScheme) link = baseUri.resolveUri(link);
        out.add(link);
      }
    }
    return out.toList();
  }

  String _fallbackTitleFromUrl(Uri url) {
    final lastSegment = url.pathSegments.isNotEmpty ? url.pathSegments.last : url.toString();
    return lastSegment.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}