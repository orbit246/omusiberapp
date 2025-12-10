import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/widgets/news/news_card.dart';

// --- 1. ANIMATION WRAPPER ---
class SlideInEntry extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool animate;

  const SlideInEntry({super.key, required this.child, this.delay = Duration.zero, this.animate = true});

  @override
  State<SlideInEntry> createState() => _SlideInEntryState();
}

class _SlideInEntryState extends State<SlideInEntry> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _sizeAnimation = CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn);

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

// --- 2. CUSTOM PHYSICS ---
class RefreshSafeScrollPhysics extends BouncingScrollPhysics {
  const RefreshSafeScrollPhysics({super.parent});

  @override
  RefreshSafeScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return RefreshSafeScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }
    if (value < -120.0) {
      return value - (-120.0);
    }
    return super.applyBoundaryConditions(position, value);
  }
}

// --- 3. MAIN VIEW ---
class NewsTabView extends StatefulWidget {
  const NewsTabView({super.key});

  @override
  State<NewsTabView> createState() => _NewsTabViewState();
}

class _NewsTabViewState extends State<NewsTabView> {
  final List<dynamic> _articles = [];
  final Set<dynamic> _animateAllowedSet = {};
  final Set<dynamic> _hasAnimatedSet = {};

  bool _isInitialLoading = true;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();
  bool _showBackToTopButton = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    _scrollController.addListener(() {
      if (_scrollController.offset >= 500) {
        if (!_showBackToTopButton) setState(() => _showBackToTopButton = true);
      } else {
        if (_showBackToTopButton) setState(() => _showBackToTopButton = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart);
  }

  Future<void> _loadInitialData() async {
    try {
      final newData = await NewsFetcher().fetchLatestNews();
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _animateAllowedSet.addAll(newData);
          _articles.addAll(newData);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    try {
      final fetchedData = await NewsFetcher().fetchLatestNews();
      if (!mounted) return;

      final List<dynamic> newItems = fetchedData.where((newItem) {
        return !_articles.contains(newItem);
      }).toList();

      if (newItems.isNotEmpty) {
        setState(() {
          _articles.insertAll(0, newItems);
        });

        if (mounted) {
          _showToast("Yeni ${newItems.length} haber yüklendi", Icons.check_circle_rounded, true);
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

  void _showToast(String msg, IconData icon, bool isSuccess) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const StadiumBorder(),
        backgroundColor: isSuccess ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        elevation: 6,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSuccess ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSuccess ? colorScheme.onPrimary : colorScheme.onSurface,
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
            Text("Haberler yükleniyor", style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) return Center(child: Text("Hata: $_errorMessage"));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        controller: _scrollController,
        key: const PageStorageKey('news_tab'),
        physics: const RefreshSafeScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: _handleRefresh,
            refreshTriggerPullDistance: 60.0,
            refreshIndicatorExtent: 40.0,
          ),

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
                padding: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
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
                  Text("Built by ", style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  Text(
                    "Samet Demiral",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary, // Using Primary Color for the name
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(" with ", style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  Icon(
                    Icons.favorite,
                    color: colorScheme.primary, // Red heart
                    size: 14,
                  ),
                ],
              ),
            ),
          ),

          // Bottom padding to ensure FAB doesn't cover content
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: _showBackToTopButton
          ? FloatingActionButton(onPressed: _scrollToTop, mini: true, child: const Icon(Icons.arrow_upward))
          : null,
    );
  }
}
