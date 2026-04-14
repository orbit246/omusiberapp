import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/backend/share_service.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:omusiber/widgets/news/news_card.dart';

// --- 1. CUSTOM PHYSICS ---
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

// --- 2. MAIN VIEW ---
class NewsTabView extends StatefulWidget {
  const NewsTabView({super.key});

  @override
  State<NewsTabView> createState() => _NewsTabViewState();
}

class _NewsTabViewState extends State<NewsTabView> {
  final List<dynamic> _articles = [];

  bool _isInitialLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final newData = _bindNewsActions(await NewsFetcher().fetchLatestNews());
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
      final fetchedData = _bindNewsActions(
        await NewsFetcher().fetchLatestNews(),
      );
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

  void _insertNewsBatch(List<dynamic> items, {required bool insertAtTop}) {
    if (items.isEmpty) return;

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

  List<NewsView> _bindNewsActions(List<NewsView> items) {
    return items
        .map(
          (item) => item.copyWith(
            onShare: () => unawaited(ShareService.shareNews(context, item)),
          ),
        )
        .toList(growable: false);
  }

  void _showStyledToast({
    required String message,
    required IconData icon,
    required bool isSuccess,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                message,
                style: theme.textTheme.labelLarge?.copyWith(
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
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text("Hata: $_errorMessage"));
    }

    return CustomScrollView(
      key: const PageStorageKey('news_tab'),
      physics: const RefreshSafeScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _handleRefresh,
          refreshTriggerPullDistance: 50.0,
          refreshIndicatorExtent: 40.0,
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final newsItem = _articles[index];

            return Padding(
              key: ValueKey(newsItem),
              padding: const EdgeInsets.only(
                bottom: 12.0,
                left: 16.0,
                right: 16.0,
              ),
              child: NewsCard(view: newsItem),
            );
          }, childCount: _articles.length),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}
