import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/widgets/news/news_card.dart';

// --- 1. ANIMATION WRAPPER ---
class SlideInEntry extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool animate; // NEW: Control flag

  const SlideInEntry({
    super.key, 
    required this.child, 
    this.delay = Duration.zero,
    this.animate = true, // Defaults to true
  });

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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0.0), 
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );

    // LOGIC: If animation is disabled, jump to the end immediately.
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
    // Even if animate is false, we keep the tree structure same 
    // (SizeTransition > Fade > Slide) but controller is already at 1.0
    // so it renders fully visible instantly.
    return SizeTransition(
      sizeFactor: _sizeAnimation,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _offsetAnimation,
          child: widget.child,
        ),
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
  
  // NEW: Tracks which items are allowed to animate (App Start items)
  final Set<dynamic> _animateAllowedSet = {};

  bool _isInitialLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final newData = await NewsFetcher().fetchLatestNews();
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          // APP START: Mark these items as allowed to animate
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

      // Filter only TRULY new items
      final List<dynamic> newItems = fetchedData.where((newItem) {
        return !_articles.contains(newItem);
      }).toList();

      if (newItems.isNotEmpty) {
        // REFRESH: We do NOT add these to '_animateAllowedSet'.
        // This ensures they will render instantly (snappy).
        
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
    if (_isInitialLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text("Hata: $_errorMessage"));

    return CustomScrollView(
      key: const PageStorageKey('news_tab'),
      physics: const RefreshSafeScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _handleRefresh,
          refreshTriggerPullDistance: 60.0,
          refreshIndicatorExtent: 40.0,
        ),
        
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final newsItem = _articles[index];
              
              // Check if this item is in our "Allowed" set (from App Start)
              final bool shouldAnimate = _animateAllowedSet.contains(newsItem);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
                child: SlideInEntry(
                  key: ValueKey(newsItem), 
                  animate: shouldAnimate, // Pass the flag here
                  child: NewsCard(view: newsItem),
                ),
              );
            },
            childCount: _articles.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}