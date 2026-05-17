import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/community_repository.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/pages/new_view/community_post_detail_page.dart';
import 'package:omusiber/pages/news_item_page.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';

enum DeepLinkCategory { news, events, community }

class AkademizDeepLink {
  const AkademizDeepLink({required this.category, required this.id});

  static const String webScheme = 'https';
  static const String webHost = 'akademiz.nortixlabs.com';
  static const String appScheme = 'akademiz';

  final DeepLinkCategory category;
  final String id;

  static AkademizDeepLink? parse(Uri uri) {
    final normalizedScheme = uri.scheme.toLowerCase();
    final normalizedHost = uri.host.toLowerCase();
    final segments = uri.pathSegments
        .map(Uri.decodeComponent)
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);

    if (normalizedScheme == appScheme) {
      return _parseSegments([normalizedHost, ...segments]);
    }

    if (normalizedScheme != webScheme) {
      return null;
    }

    if (normalizedHost == webHost) {
      return _parseSegments(segments);
    }

    if ((normalizedHost == 'www.nortixlabs.com' ||
            normalizedHost == 'nortixlabs.com') &&
        segments.isNotEmpty &&
        segments.first.toLowerCase() == 'akademiz') {
      return _parseSegments(segments.skip(1).toList(growable: false));
    }

    return null;
  }

  static AkademizDeepLink? _parseSegments(List<String> segments) {
    if (segments.isEmpty) {
      return null;
    }

    final category = _parseCategory(segments);
    if (category == null) {
      return null;
    }

    final id = _extractId(category, segments);
    if (id.isEmpty) {
      return null;
    }

    return AkademizDeepLink(category: category, id: id);
  }

  static DeepLinkCategory? _parseCategory(List<String> segments) {
    final first = segments.first.toLowerCase();
    if (_isNewsAlias(first)) return DeepLinkCategory.news;
    if (_isEventAlias(first)) return DeepLinkCategory.events;
    if (_isCommunityAlias(first)) {
      if (segments.length >= 2 &&
          <String>{'post', 'posts', 'gonderi', 'gonderiler'}
              .contains(segments[1].toLowerCase())) {
        return DeepLinkCategory.community;
      }
      if (segments.length == 2) {
        return DeepLinkCategory.community;
      }
    }
    return null;
  }

  static bool _isNewsAlias(String value) =>
      value == 'news' || value == 'haber' || value == 'haberler';

  static bool _isEventAlias(String value) =>
      value == 'event' ||
      value == 'events' ||
      value == 'etkinlik' ||
      value == 'etkinlikler';

  static bool _isCommunityAlias(String value) =>
      value == 'community' ||
      value == 'post' ||
      value == 'posts' ||
      value == 'topluluk';

  static String _extractId(DeepLinkCategory category, List<String> segments) {
    switch (category) {
      case DeepLinkCategory.news:
      case DeepLinkCategory.events:
        return segments.length >= 2 ? segments[1].trim() : '';
      case DeepLinkCategory.community:
        if (segments.isEmpty) return '';
        if (_isCommunityAlias(segments.first.toLowerCase()) &&
            segments.length >= 3 &&
            <String>{'post', 'posts', 'gonderi', 'gonderiler'}
                .contains(segments[1].toLowerCase())) {
          return segments[2].trim();
        }
        return segments.length >= 2 ? segments[1].trim() : '';
    }
  }

  Uri toWebUri() {
    switch (category) {
      case DeepLinkCategory.news:
        return Uri(scheme: webScheme, host: webHost, path: '/news/$id');
      case DeepLinkCategory.events:
        return Uri(scheme: webScheme, host: webHost, path: '/event/$id');
      case DeepLinkCategory.community:
        return Uri(
          scheme: webScheme,
          host: webHost,
          path: '/community/post/$id',
        );
    }
  }

  Uri toAppUri() {
    switch (category) {
      case DeepLinkCategory.news:
        return Uri(scheme: appScheme, host: 'news', path: '/$id');
      case DeepLinkCategory.events:
        return Uri(scheme: appScheme, host: 'event', path: '/$id');
      case DeepLinkCategory.community:
        return Uri(scheme: appScheme, host: 'community', path: '/post/$id');
    }
  }

  static Uri newsUri(int id) =>
      AkademizDeepLink(category: DeepLinkCategory.news, id: id.toString())
          .toWebUri();

  static Uri eventUri(String id) =>
      AkademizDeepLink(category: DeepLinkCategory.events, id: id).toWebUri();

  static Uri communityPostUri(String id) =>
      AkademizDeepLink(category: DeepLinkCategory.community, id: id)
          .toWebUri();
}

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _lastHandledKey;

  Future<void> start({required GlobalKey<NavigatorState> navigatorKey}) async {
    _navigatorKey = navigatorKey;
    _subscription ??= _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Deep link stream failed: $error\n$stackTrace');
      },
    );

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (error, stackTrace) {
      debugPrint('Initial deep link failed: $error\n$stackTrace');
    }
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _handleUri(Uri uri) {
    final link = AkademizDeepLink.parse(uri);
    if (link == null) {
      return;
    }

    final key = '${link.category.name}:${link.id}';
    if (_lastHandledKey == key) {
      return;
    }
    _lastHandledKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey?.currentState;
      if (navigator == null) {
        return;
      }

      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => _DeepLinkResolverPage(link: link),
        ),
      );
    });
  }
}

class _DeepLinkResolverPage extends StatefulWidget {
  const _DeepLinkResolverPage({required this.link});

  final AkademizDeepLink link;

  @override
  State<_DeepLinkResolverPage> createState() => _DeepLinkResolverPageState();
}

class _DeepLinkResolverPageState extends State<_DeepLinkResolverPage> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    try {
      final page = await _buildDestinationPage();
      if (!mounted) return;

      if (page == null) {
        setState(() => _errorMessage = 'Icerik bulunamadi.');
        return;
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Baglanti acilamadi: $error');
    }
  }

  Future<Widget?> _buildDestinationPage() async {
    switch (widget.link.category) {
      case DeepLinkCategory.news:
        final newsId = int.tryParse(widget.link.id);
        if (newsId == null) return null;
        final news = await NewsFetcher().fetchNewsById(newsId);
        return news == null ? null : NewsItemPage(view: news);
      case DeepLinkCategory.events:
        final event = await EventRepository().fetchEventById(widget.link.id);
        return event == null ? null : EventDetailsPage(event: event);
      case DeepLinkCategory.community:
        final post = await CommunityRepository().fetchPostById(widget.link.id);
        return post == null ? null : CommunityPostDetailPage(post: post);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('AkademiZ')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: error == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Icerik aciliyor...',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link_off_rounded,
                      size: 40,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Geri Don'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
