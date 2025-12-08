import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/widgets/news/news_card.dart';

// --- 1. ANIMATION WRAPPER ---
class SlideInEntry extends StatefulWidget {
  final Widget child;
  final Duration delay; 

  const SlideInEntry({
    super.key, 
    required this.child, 
    this.delay = Duration.zero,
  });

  @override
  State<SlideInEntry> createState() => _SlideInEntryState();
}

class _SlideInEntryState extends State<SlideInEntry> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

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

    // Opacity starts at 0, so it's invisible while waiting for delay
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _runAnimation();
  }

  void _runAnimation() async {
    // If there is a stagger delay, wait first
    if (widget.delay > Duration.zero) {
      await Future.delayed(widget.delay);
    }
    // Check mounted again in case user scrolled away during delay
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _offsetAnimation,
        child: widget.child,
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
    if (value < -150.0) {
      return value - (-150.0);
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
  
  // Stores temporary delays for the "current" batch of new items.
  // We use this to tell Item A to wait 0ms, Item B to wait 150ms, etc.
  final Map<dynamic, Duration> _staggerDelays = {};
  
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
        });
        // Insert all at once
        _insertNewsBatch(newData, insertAtTop: false);
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
        // 1. Insert ONLY new items at the top
        _insertNewsBatch(newItems, insertAtTop: true);

        // 2. Success Toast
        if (mounted) {
          _showStyledToast(
            message: "Yeni ${newItems.length} haber yüklendi",
            icon: Icons.check_circle_rounded,
            isSuccess: true,
          );
        }
      } else {
        // 3. Info Toast
        if (mounted) {
          _showStyledToast(
            message: "Yeni haber bulunamadı",
            icon: Icons.info_rounded,
            isSuccess: false,
          );
        }
      }
    } catch (e) {
      debugPrint("Refresh failed: $e");
    }
  }

  // --- NEW: Insert All + Calculate Delays ---
  void _insertNewsBatch(List<dynamic> items, {required bool insertAtTop}) {
    if (items.isEmpty) return;

    // Clear old delays so we don't hold onto memory references
    _staggerDelays.clear();

    // If inserting at top (Refresh), we want the NEWEST item at index 0.
    // Usually APIs return [Newest, 2nd Newest...].
    // So we just iterate through them and assign increasing delays.
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      // Item 0 waits 0ms. Item 1 waits 150ms. Item 2 waits 300ms.
      // This creates the visual cascade without the physical list jitter.
      _staggerDelays[item] = Duration(milliseconds: i * 150);
    }

    setState(() {
      if (insertAtTop) {
        // Add all at the top in one go.
        // Since 'items' is usually [Newest, Older...], insertAll(0, items)
        // puts Newest at 0, Older at 1. Correct order.
        _articles.insertAll(0, items);
      } else {
        _articles.addAll(items);
      }
    });
  }

  void _showStyledToast({required String message, required IconData icon, required bool isSuccess}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
            Icon(
              icon, 
              color: isSuccess ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.labelLarge?.copyWith(
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
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text("Hata: $_errorMessage"));
    }

    return CustomScrollView(
      key: const PageStorageKey('news_tab'),
      physics: const RefreshSafeScrollPhysics(
        parent: AlwaysScrollableScrollPhysics()
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _handleRefresh,
          refreshTriggerPullDistance: 50.0, 
          refreshIndicatorExtent: 40.0, 
        ),
        
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final newsItem = _articles[index];
              
              // Check if we have a specific delay assigned for this item (from the recent fetch)
              // If not found, delay is 0 (it's an old item or just scrolled into view).
              final animationDelay = _staggerDelays[newsItem] ?? Duration.zero;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
                child: SlideInEntry(
                  // KEY IS CRITICAL: Ensures the animation state is tied to the DATA,
                  // not the index. Prevents re-animating old items when they shift down.
                  key: ValueKey(newsItem), 
                  delay: animationDelay,
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