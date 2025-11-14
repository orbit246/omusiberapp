import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:omusiber/backend/news_view.dart';

class NewsFetcher {
  NewsFetcher({
    this.timeout = const Duration(seconds: 10),
    Map<String, String>? headers,
  }) : headers = {
          'User-Agent':
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119 Safari/537.36',
          ...?headers,
        };

  final Duration timeout;
  final Map<String, String> headers;

  static const String _fallbackImage = 'https://carsambamyo.omu.edu.tr/user/themes/fakulte/assets/images/omu-default-img_tr.jpeg';

  void _log(String msg) {
    debugPrint('[NewsFetcher] $msg');
    // dev.log(msg, name: 'NewsFetcher'); // if you prefer
  }

  /// Ana liste sayfasından linkleri alıp her bir haber detayını NewsView'e çevirir.
  /// ÇOK ÖNEMLİ: Her haber için hata olursa o haberde fallback kullanılır,
  /// ama diğer haberler yüklenmeye devam eder.
  Future<List<NewsView>> fetchLatestNews() async {
    const listUrl = 'https://carsambamyo.omu.edu.tr/tr/haberler';
    _log('fetchLatestNews() START, listUrl=$listUrl');

    List<Uri> readMoreLinks = [];
    try {
      readMoreLinks = await fetchReadMoreLinks(listUrl);
      _log('Fetched ${readMoreLinks.length} read-more links.');
    } catch (e, st) {
      _log('ERROR while fetching read-more links: $e');
      _log('STACK: $st');
      return [];
    }

    if (readMoreLinks.isEmpty) {
      _log('No read-more links found. Returning empty news list.');
      return [];
    }

    final limitedLinks = readMoreLinks.take(5).toList();
    _log('Limited to ${limitedLinks.length} links: $limitedLinks');

    // Her link için güvenli fetch: hata olursa fallback NewsView dön.
    final futures = limitedLinks.map((uri) => _safeFetchNewsDetail(uri)).toList();

    final result = await Future.wait(futures);
    _log(
      'fetchLatestNews() DONE. '
      'Successfully created ${result.length} NewsView items (including fallbacks).',
    );

    return result;
  }

  /// Hata olsa bile asla throw etmeyen, her zaman bir [NewsView] dönen wrapper.
  Future<NewsView> _safeFetchNewsDetail(Uri url) async {
    try {
      return await fetchNewsDetail(url);
    } catch (e, st) {
      _log('SAFE WRAPPER: Error fetching detail for $url: $e');
      _log('STACK: $st');

      // HATA DURUMUNDA: bu haber için fallback NewsView dön.
      final fallbackTitle = _fallbackTitleFromUrl(url);
      return NewsView(
        title: fallbackTitle,
        summary: 'Bu haber şu anda yüklenemedi.',
        heroImage: _fallbackImage,
        authorName: 'Bilinmeyen Yazar',
        authorAvatar: null,
        detailUrl: url.toString(),
      );
    }
  }

  /// Verilen haber detay linkinden sayfayı indirip, başlık, yazar, görsel ve içeriği parse eder.
  ///
  /// Bu fonksiyon HATA atabilir. Dışarıdan _safeFetchNewsDetail ile kullanıyoruz.
  Future<NewsView> fetchNewsDetail(Uri url) async {
    _log('fetchNewsDetail() START for $url');

    http.Response res;
    try {
      res = await http.get(url, headers: headers).timeout(timeout);
      _log('[$url] HTTP status: ${res.statusCode} (len=${res.body.length})');
    } on TimeoutException catch (e, st) {
      _log('TIMEOUT fetching $url: $e');
      _log('STACK: $st');
      rethrow;
    } catch (e, st) {
      _log('NETWORK ERROR fetching $url: $e');
      _log('STACK: $st');
      rethrow;
    }

    if (res.statusCode != 200) {
      _log('WARNING: $url responded with HTTP ${res.statusCode}.');
      // İstersen burada da rethrow edebilirsin.
      // Biz wrapper’da fallback döndüğümüz için rethrow normal.
      throw Exception('Failed to load news page: HTTP ${res.statusCode}');
    }

    late Document doc;
    try {
      doc = html_parser.parse(res.body);
    } catch (e, st) {
      _log('HTML PARSE ERROR for $url: $e');
      _log('STACK: $st');
      rethrow;
    }

    // Başlık
    String title;
    try {
      title = doc.querySelector('h1.heading-title')?.text.trim() ??
          'Başlık bulunamadı';
      _log('[$url] Parsed title: "$title"');
    } catch (e, st) {
      _log('ERROR parsing title for $url: $e');
      _log('STACK: $st');
      title = 'Başlık bulunamadı';
    }

    // Yazar
    String authorName = 'Bilinmeyen Yazar';
    try {
      final meta = doc.querySelector('.news-item .meta.text-muted');
      if (meta != null) {
        final authorEl = meta.querySelector('a');
        if (authorEl != null && authorEl.text.trim().isNotEmpty) {
          authorName = authorEl.text.trim();
        }
      }
      _log('[$url] Parsed author: "$authorName"');
    } catch (e, st) {
      _log('ERROR parsing author for $url: $e');
      _log('STACK: $st');
    }

    // 🚨 ÖNEMLİ: Resmi hiç network üzerinden yüklemiyoruz.
    // Sadece src string'ini okuruz; hata olursa fallback asset kullanırız.
    String? heroImage;
    try {
      final heroSrc = doc
          .querySelector('.news-item .featured-image img')
          ?.attributes['src'];

      if (heroSrc != null && heroSrc.trim().isNotEmpty) {
        final baseUri = url;
        final raw = heroSrc.trim();
        // Göreli path ise URL olarak normalize et, ama asla burada download etme.
        if (!raw.startsWith('http')) {
          heroImage = baseUri.resolve(raw).toString();
        } else {
          heroImage = raw;
        }
        _log('[$url] Parsed heroImage URL (NOT downloaded here): $heroImage');
      } else {
        _log('[$url] No heroImage src found, will use fallback asset.');
      }
    } catch (e, st) {
      _log('ERROR parsing hero image src for $url: $e');
      _log('STACK: $st');
      heroImage = null;
    }

    // İçerik / özet
    String summary = '';
    try {
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
      _log('[$url] Parsed summary length: ${summary.length}');
    } catch (e, st) {
      _log('ERROR parsing summary for $url: $e');
      _log('STACK: $st');
      summary = '';
    }

    // 🖼 Burada KRİTİK: heroImage null ise, her durumda fallback asset kullan.
    final view = NewsView(
      title: title,
      summary: summary,
      // Hero image network’te patlasa bile, bu class asla çökmez;
      // en kötü durumda asset gösterilir.
      heroImage: heroImage ?? _fallbackImage,
      authorName: authorName,
      authorAvatar: null,
      detailUrl: url.toString()
    );

    _log('fetchNewsDetail() DONE for $url');
    return view;
  }
  /// Haber liste sayfasındaki tüm "devamını oku" linklerini döndürür.
  Future<List<Uri>> fetchReadMoreLinks(String websiteUrl) async {
    _log('fetchReadMoreLinks() START for $websiteUrl');
    final baseUri = Uri.parse(websiteUrl);

    http.Response res;
    try {
      res = await http.get(baseUri, headers: headers).timeout(timeout);
      _log('[$websiteUrl] HTTP status: ${res.statusCode} (len=${res.body.length})');
    } on TimeoutException catch (e, st) {
      _log('TIMEOUT fetching list page $websiteUrl: $e');
      _log('STACK: $st');
      rethrow;
    } catch (e, st) {
      _log('NETWORK ERROR fetching list page $websiteUrl: $e');
      _log('STACK: $st');
      rethrow;
    }

    if (res.statusCode != 200) {
      _log('ERROR: list page $websiteUrl HTTP ${res.statusCode}');
      throw Exception('Failed to load page: HTTP ${res.statusCode}');
    }

    late Document doc;
    try {
      doc = html_parser.parse(res.body);
    } catch (e, st) {
      _log('HTML PARSE ERROR in list page $websiteUrl: $e');
      _log('STACK: $st');
      rethrow;
    }

    final elements = <Element>[
      ...doc.querySelectorAll('.btn.btn-theme.read-more'),
    ];
    _log('[$websiteUrl] Found ${elements.length} read-more elements.');

    final out = <Uri>{};

    for (final el in elements) {
      try {
        String? href = el.attributes['href'] ?? el.attributes['data-href'];
        if (href == null || href.trim().isEmpty) {
          _log('[$websiteUrl] Skipping element with empty href/data-href.');
          continue;
        }

        Uri link = Uri.parse(href.trim());
        if (!link.hasScheme) {
          link = baseUri.resolveUri(link);
        }

        _log('[$websiteUrl] Resolved read-more link: $link');
        out.add(link);
      } catch (e, st) {
        _log('ERROR parsing a read-more link in $websiteUrl: $e');
        _log('STACK: $st');
      }
    }

    _log('fetchReadMoreLinks() DONE for $websiteUrl, total unique links: ${out.length}');
    return out.toList();
  }

  /// URL’den basit bir fallback başlık üret (son path segment’ini insanımsı hale getir).
  String _fallbackTitleFromUrl(Uri url) {
    final lastSegment = url.pathSegments.isNotEmpty
        ? url.pathSegments.last
        : url.toString();
    return lastSegment
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
