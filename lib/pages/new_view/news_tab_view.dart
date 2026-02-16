import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:omusiber/widgets/news/news_card.dart';

// --- 1. ANIMATION WRAPPER ---
class SlideInEntry extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool animate;

  const SlideInEntry({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
  });

  @override
  State<SlideInEntry> createState() => _SlideInEntryState();
}

class _SlideInEntryState extends State<SlideInEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );

    if (!widget.animate) {
      _controller.value = 1.0;
    } else {
      _runAnimation();
    }
  }

  void _runAnimation() async {
    if (widget.delay > Duration.zero) {
      await Future.delayed(widget.delay);
    }
    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _sizeAnimation,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(position: _offsetAnimation, child: widget.child),
      ),
    );
  }
}

// --- 2. CUSTOM PHYSICS (Removed to fix overscroll error) ---

// --- 3. MAIN VIEW ---
class NewsTabView extends StatefulWidget {
  const NewsTabView({super.key});

  @override
  State<NewsTabView> createState() => _NewsTabViewState();
}

class _NewsTabViewState extends State<NewsTabView> {
  final List<NewsView> _articles = [];
  final Set<NewsView> _animateAllowedSet = {};
  final Set<NewsView> _hasAnimatedSet = {};

  bool _isInitialLoading = true;
  String? _errorMessage;

  bool _showBackToTopButton = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _scrollToTop() {
    final primaryController = PrimaryScrollController.of(context);
    if (primaryController.hasClients) {
      primaryController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuart,
      );
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. Load from cache first (no network)
      final cachedData = await NewsFetcher().getCachedNews();
      final hydratedCached = _bindNewsActions(cachedData);

      if (mounted) {
        setState(() {
          if (hydratedCached.isNotEmpty) {
            _isInitialLoading = false;
            _animateAllowedSet.addAll(hydratedCached);
            _articles.addAll(hydratedCached);
          }
        });
      }

      // 2. Schedule a refresh AFTER the app has fully rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshInBackground();
      });
    } catch (e) {
      debugPrint("Failed to load initial news cache: $e");
      if (_articles.isEmpty) {
        _refreshInBackground();
      }
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      final newData = await NewsFetcher().fetchLatestNews(forceRefresh: true);
      final hydratedData = _bindNewsActions(newData);
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _articles.clear();
          _articles.addAll(hydratedData);
          _animateAllowedSet.addAll(hydratedData);
        });
      }
    } catch (e) {
      if (mounted && _articles.isEmpty) {
        setState(() {
          _isInitialLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    try {
      final fetchedData = _bindNewsActions(
        await NewsFetcher().fetchLatestNews(forceRefresh: true),
      );
      if (!mounted) return;

      final List<NewsView> newItems = fetchedData.where((newItem) {
        return !_articles.contains(newItem);
      }).toList();

      if (newItems.isNotEmpty) {
        setState(() {
          _articles.insertAll(0, newItems);
        });

        if (mounted) {
          _showToast(
            "Yeni ${newItems.length} haber yüklendi",
            Icons.check_circle_rounded,
            true,
          );
        }
      } else {
        if (mounted) {
          _showToast("Yeni haber bulunamadı", Icons.info_rounded, false);
        }
      }
    } catch (e) {
      debugPrint("Refresh failed: $e");
    }
  }

  List<NewsView> _bindNewsActions(List<NewsView> items) {
    return items.map(_bindNewsActionsForItem).toList(growable: false);
  }

  NewsView _bindNewsActionsForItem(NewsView item) {
    return item.copyWith(
      onToggleFavorite: (isLiked) => _handleNewsLikeToggle(item.id, isLiked),
    );
  }

  void _handleNewsLikeToggle(int newsId, bool isLiked) {
    final index = _articles.indexWhere((item) => item.id == newsId);
    if (index == -1) return;

    final current = _articles[index];
    final nextLikeCount = isLiked
        ? current.likeCount + 1
        : (current.likeCount > 0 ? current.likeCount - 1 : 0);

    setState(() {
      _articles[index] = _bindNewsActionsForItem(
        current.copyWith(isFavorited: isLiked, likeCount: nextLikeCount),
      );
    });

    unawaited(NewsFetcher().trackNewsLike(newsId, isLiked: isLiked));
  }

  void _showToast(String msg, IconData icon, bool isSuccess) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const StadiumBorder(),
        backgroundColor: isSuccess
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        elevation: 6,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSuccess
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSuccess
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Loading State
    if (_isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Haberler yükleniyor",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null)
      return Center(child: Text("Hata: $_errorMessage"));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.axis == Axis.vertical) {
            if (scrollInfo.metrics.pixels >= 500) {
              if (!_showBackToTopButton) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_showBackToTopButton) {
                    setState(() => _showBackToTopButton = true);
                  }
                });
              }
            } else {
              if (_showBackToTopButton) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _showBackToTopButton) {
                    setState(() => _showBackToTopButton = false);
                  }
                });
              }
            }
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          displacement: 20,
          edgeOffset: 0,
          child: CustomScrollView(
            key: const PageStorageKey('news_tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              // The List of News
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final newsItem = _articles[index];
                  final bool isAllowed = _animateAllowedSet.contains(newsItem);
                  final bool hasAnimated = _hasAnimatedSet.contains(newsItem);
                  final bool shouldAnimate = isAllowed && !hasAnimated;
                  if (shouldAnimate) {
                    _hasAnimatedSet.add(newsItem);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: SlideInEntry(
                      key: ValueKey(newsItem),
                      animate: shouldAnimate,
                      child: NewsCard(view: newsItem),
                    ),
                  );
                }, childCount: _articles.length),
              ),
              // --- FOOTER SECTION ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Built by ",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        "NortixLabs",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        " with ",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Icon(
                        Icons.favorite,
                        color: colorScheme.primary,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
      floatingActionButton: _showBackToTopButton
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              mini: true,
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }
}
