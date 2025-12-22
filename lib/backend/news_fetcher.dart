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

  final int maxNewsCount = 7;
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
        _logError(
          'No links found!',
          'Selector .btn.btn-theme.read-more might be wrong.',
        );
      } else {
        _log(
          'Found ${readMoreLinks.length} links. Fetching top $maxNewsCount...',
        );

        final limitedLinks = readMoreLinks.take(maxNewsCount).toList();

        // We use a loop here instead of Future.wait to debug easier and not crash everything on one fail
        for (final uri in limitedLinks) {
          final newsItem = await _safeFetchNewsDetail(uri);
          if (newsItem != null) {
            result.add(newsItem);
          }
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

  Future<NewsView?> _safeFetchNewsDetail(Uri url) async {
    try {
      return await fetchNewsDetail(url);
    } catch (e) {
      // If a specific news item fails or is invalid, we return null to skip it
      _logError('Failed to parse details for $url', e);
      return null;
    }
  }

  Future<NewsView?> fetchNewsDetail(Uri url) async {
    _log('Requesting detail: $url');

    // Check for redirects and fetch using a Client to control behaviour
    final client = http.Client();
    try {
      // Create request ensuring we don't follow redirects
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..followRedirects = false;

      final streamedResponse = await client.send(request).timeout(timeout);

      // 1. Check for Redirects (3xx)
      // The user requested: "fetch only if the given link does not redirect to a different URL"
      if (streamedResponse.statusCode >= 300 &&
          streamedResponse.statusCode < 400) {
        _log(
          'Skipping $url because it redirects (Status: ${streamedResponse.statusCode})',
        );
        return null;
      }

      // 2. Check for Success
      if (streamedResponse.statusCode != 200) {
        throw HttpException('HTTP ${streamedResponse.statusCode}', uri: url);
      }

      // Get body
      final responseBody = await streamedResponse.stream.bytesToString();
      final doc = html_parser.parse(responseBody);

      // --- PARSING ---

      // Title
      var title = doc.querySelector('h1.heading-title')?.text.trim();
      if (title == null || title.isEmpty) {
        _log('⚠️ [PARSER WARNING] Title missing for $url');
        // User requested: "do not return the result if the content is [not] fully available"
        return null;
      }

      // Author
      String authorName = 'Bilinmeyen Yazar';
      final meta = doc.querySelector('.news-item .meta.text-muted');
      if (meta != null) {
        final authorEl = meta.querySelector('a');
        if (authorEl != null) authorName = authorEl.text.trim();
      }

      // Image
      String? heroImage;
      final heroSrc = doc
          .querySelector('.news-item .featured-image img')
          ?.attributes['src'];
      if (heroSrc != null && heroSrc.trim().isNotEmpty) {
        final raw = heroSrc.trim();
        heroImage = raw.startsWith('http') ? raw : url.resolve(raw).toString();
      }

      // Summary (Content)
      String summary = '';
      final article = doc.querySelector('article.news-item');
      if (article != null) {
        final paragraphs = article
            .querySelectorAll('p')
            .map((p) => p.text.trim())
            .where(
              (t) =>
                  t.isNotEmpty &&
                  !t.startsWith('Yazar:') &&
                  !t.contains('Tarih:'),
            )
            .toList();
        summary = paragraphs.join('\n\n');
      }

      if (summary.isEmpty) {
        _log('⚠️ [PARSER WARNING] Content (summary) empty for $url');
        // User requested: "do not return the result if the content is [not] fully available"
        return null;
      }

      return NewsView(
        title: title,
        summary: summary,
        heroImage: heroImage ?? _fallbackImage,
        authorName: authorName,
        authorAvatar: null,
        detailUrl: url.toString(),
      );
    } finally {
      client.close();
    }
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
