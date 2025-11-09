import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:omusiber/backend/news_view.dart';

class NewsFetcher {
  NewsFetcher({this.timeout = const Duration(seconds: 10), Map<String, String>? headers})
    : headers = {
        // A basic desktop UA helps some sites return full HTML.
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119 Safari/537.36',
        ...?headers,
      };

  final Duration timeout;
  final Map<String, String> headers;

  Future<List<NewsView>> fetchLatestNews() async {
    fetchReadMoreLinks("https://carsambamyo.omu.edu.tr/tr/haberler").then((links) {
      for (var link in links) {
        print(link.toString());
      }
    });

    return [
      NewsView(
        title: "Örnek Haber Başlığı 1",
        summary: "Bu, örnek bir haber özetidir. Haber içeriği burada yer alacaktır.",
        heroImage: "assets/news.webp",
        authorName: "Yazar 1",
        authorAvatar: null,
      ),
       NewsView(
        title: "Örnek Haber Başlığı 2",
        summary: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        heroImage: "assets/news.webp",
        authorName: "Yazar 1",
        authorAvatar: null,
      ),
    ];
  }

  /// Downloads [websiteUrl], finds all elements with classes
  /// `btn btn-theme read-more`, and returns absolute hrefs.
  Future<List<Uri>> fetchReadMoreLinks(String websiteUrl) async {
    final baseUri = Uri.parse(websiteUrl);

    final res = await http.get(baseUri, headers: headers).timeout(timeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to load page: HTTP ${res.statusCode}');
    }

    final doc = html_parser.parse(res.body);

    // This targets things like: <a class="btn btn-theme read-more" href="...">
    // It will also catch <button> with the same classes, and try data-href fallback.
    final elements = <Element>[...doc.querySelectorAll('.btn.btn-theme.read-more')];

    final out = <Uri>{};

    for (final el in elements) {
      // Prefer standard anchor href; fall back to data-href for button-like elements.
      String? href = el.attributes['href'] ?? el.attributes['data-href'];
      if (href == null || href.trim().isEmpty) continue;

      // Resolve relative URLs against the base.
      Uri link = Uri.parse(href.trim());
      if (!link.hasScheme) {
        link = baseUri.resolveUri(link);
      }
      out.add(link);
    }

    return out.toList();
  }
}
