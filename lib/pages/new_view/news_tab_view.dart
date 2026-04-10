import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:omusiber/pages/new_view/master_view.dart';
import 'package:omusiber/widgets/news/news_card.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';

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
  final AppStartupController _startupController = AppStartupController.instance;
  static const Duration _backgroundRefreshDelay = Duration(seconds: 3);
  final List<NewsView> _articles = [];
  final Set<NewsView> _animateAllowedSet = {};
  final Set<NewsView> _hasAnimatedSet = {};
  static const int _mockTodayNewsCount = 0;
  static const int _mockTodayCommunityCount = 0;
  static const int _mockWeekNewsCount = 6;
  static const int _mockWeekCommunityCount = 9;
  String _selectedSortKey = 'newest';
  String _selectedDatePreset = 'all';
  final Set<String> _selectedTags = <String>{};

  bool _isInitialLoading = true;
  String? _errorMessage;

  bool _showBackToTopButton = false;
  final ScrollController _scrollController = ScrollController();
  bool _refreshQueued = false;
  Timer? _backgroundRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startupController.addListener(_handleStartupChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _startupController.removeListener(_handleStartupChanged);
    _backgroundRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleStartupChanged() {
    if (!_startupController.canUseAuthenticatedApis || _refreshQueued) {
      return;
    }

    _scheduleBackgroundRefresh();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _scheduleBackgroundRefresh() {
    final delay = _startupController.startupDeferral(_backgroundRefreshDelay);
    _backgroundRefreshTimer?.cancel();
    if (delay == Duration.zero) {
      _refreshQueued = true;
      unawaited(
        _refreshInBackground().whenComplete(() {
          _refreshQueued = false;
        }),
      );
      return;
    }
    _backgroundRefreshTimer = Timer(delay, () {
      if (!mounted || _refreshQueued) {
        return;
      }
      _refreshQueued = true;
      unawaited(
        _refreshInBackground().whenComplete(() {
          _refreshQueued = false;
        }),
      );
    });
  }

  void _scrollToNewsSection() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        360,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openMasterTab(int index) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MasterView(initialTabIndex: index),
      ),
    );
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
            _errorMessage = null;
            _animateAllowedSet.addAll(hydratedCached);
            _articles.clear();
            _articles.addAll(hydratedCached);
          }
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleStartupChanged();
      });
    } catch (e) {
      debugPrint("Failed to load initial news cache: $e");
      if (_articles.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleStartupChanged();
        });
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
          _errorMessage = null;
          _articles.clear();
          _articles.addAll(hydratedData);
          _animateAllowedSet.addAll(hydratedData);
        });
      }
    } catch (e) {
      if (e is StateError) {
        return;
      }
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

  List<String> get _availableTags {
    final tags =
        _articles
            .expand((item) => item.tags)
            .where((tag) => tag.trim().isNotEmpty)
            .map((tag) => tag.trim())
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  String get _sortLabel {
    switch (_selectedSortKey) {
      case 'oldest':
        return 'En Eski';
      case 'popular':
        return 'En Çok Okunan';
      case 'today':
        return 'Bugün';
      case 'newest':
      default:
        return 'En Yeni';
    }
  }

  String get _filterSummary {
    final parts = <String>[];

    switch (_selectedDatePreset) {
      case 'today':
        parts.add('Bugün');
        break;
      case 'week':
        parts.add('Bu Hafta');
        break;
    }

    if (_selectedTags.isNotEmpty) {
      if (_selectedTags.length == 1) {
        parts.add(_selectedTags.first);
      } else {
        parts.add('${_selectedTags.length} etiket');
      }
    }

    if (parts.isEmpty) {
      return 'Tümü';
    }

    return parts.join(' • ');
  }

  bool _isToday(DateTime? date) {
    if (date == null) {
      return false;
    }

    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isThisWeek(DateTime? date) {
    if (date == null) {
      return false;
    }

    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return !date.isBefore(startOfWeek) && date.isBefore(endOfWeek);
  }

  List<NewsView> get _filteredArticles {
    final items = _articles.where((item) {
      final matchesDate = switch (_selectedDatePreset) {
        'today' => _isToday(item.publishedAt),
        'week' => _isThisWeek(item.publishedAt),
        _ => true,
      };

      if (!matchesDate) {
        return false;
      }

      if (_selectedTags.isEmpty) {
        return true;
      }

      return item.tags.any(_selectedTags.contains);
    }).toList();

    items.sort((a, b) {
      switch (_selectedSortKey) {
        case 'oldest':
          final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        case 'popular':
          return b.viewCount.compareTo(a.viewCount);
        case 'today':
          final aToday = _isToday(a.publishedAt) ? 1 : 0;
          final bToday = _isToday(b.publishedAt) ? 1 : 0;
          if (aToday != bToday) {
            return bToday.compareTo(aToday);
          }
          final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        case 'newest':
        default:
          final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
      }
    });

    return items;
  }

  Widget _buildFilterPill(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? colorScheme.primaryContainer.withValues(alpha: 0.92)
                : colorScheme.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : colorScheme.outlineVariant.withValues(alpha: 0.38),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: active ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasActiveFilters =
        _selectedDatePreset != 'all' || _selectedTags.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.36),
          ),
        ),
        child: Row(
          children: [
            Text(
              'Filtrele',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            _buildFilterPill(
              context,
              label: _sortLabel,
              onTap: _openFilterSheet,
              active: true,
            ),
            const SizedBox(width: 8),
            _buildFilterPill(
              context,
              label: _filterSummary,
              onTap: _openFilterSheet,
              active: hasActiveFilters,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    String tempSortKey = _selectedSortKey;
    String tempDatePreset = _selectedDatePreset;
    final Set<String> tempTags = {..._selectedTags};

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildChoice({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => onTap(),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: colorScheme.primaryContainer.withValues(
                  alpha: 0.9,
                ),
                backgroundColor: colorScheme.surfaceContainerLow,
                side: BorderSide(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.24)
                      : colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haber filtreleri',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Sıralama',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        buildChoice(
                          label: 'En Yeni',
                          selected: tempSortKey == 'newest',
                          onTap: () =>
                              setModalState(() => tempSortKey = 'newest'),
                        ),
                        buildChoice(
                          label: 'En Eski',
                          selected: tempSortKey == 'oldest',
                          onTap: () =>
                              setModalState(() => tempSortKey = 'oldest'),
                        ),
                        buildChoice(
                          label: 'En Çok Okunan',
                          selected: tempSortKey == 'popular',
                          onTap: () =>
                              setModalState(() => tempSortKey = 'popular'),
                        ),
                        buildChoice(
                          label: 'Bugün',
                          selected: tempSortKey == 'today',
                          onTap: () =>
                              setModalState(() => tempSortKey = 'today'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Zaman aralığı',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        buildChoice(
                          label: 'Tümü',
                          selected: tempDatePreset == 'all',
                          onTap: () =>
                              setModalState(() => tempDatePreset = 'all'),
                        ),
                        buildChoice(
                          label: 'Bugün',
                          selected: tempDatePreset == 'today',
                          onTap: () =>
                              setModalState(() => tempDatePreset = 'today'),
                        ),
                        buildChoice(
                          label: 'Bu Hafta',
                          selected: tempDatePreset == 'week',
                          onTap: () =>
                              setModalState(() => tempDatePreset = 'week'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Etiketler',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_availableTags.isEmpty)
                      Text(
                        'Henüz filtrelenebilir etiket yok.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTags.map((tag) {
                          return FilterChip(
                            label: Text(tag),
                            selected: tempTags.contains(tag),
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  tempTags.add(tag);
                                } else {
                                  tempTags.remove(tag);
                                }
                              });
                            },
                            labelStyle: theme.textTheme.labelLarge?.copyWith(
                              color: tempTags.contains(tag)
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            selectedColor: colorScheme.primaryContainer
                                .withValues(alpha: 0.9),
                            backgroundColor: colorScheme.surfaceContainerLow,
                            side: BorderSide(
                              color: tempTags.contains(tag)
                                  ? colorScheme.primary.withValues(alpha: 0.24)
                                  : colorScheme.outlineVariant.withValues(
                                      alpha: 0.3,
                                    ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                tempSortKey = 'newest';
                                tempDatePreset = 'all';
                                tempTags.clear();
                              });
                            },
                            child: const Text('Sıfırla'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _selectedSortKey = tempSortKey;
                                _selectedDatePreset = tempDatePreset;
                                _selectedTags
                                  ..clear()
                                  ..addAll(tempTags);
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Uygula'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionLabel(BuildContext context, String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Center(
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildTodayEventBlock(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMasterTab(1),
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "En yakın etkinlik",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Yapay Zeka Atölyesi",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "17:30",
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  ">",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayNewsBlock(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _scrollToNewsSection,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.34),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.72,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.newspaper_rounded,
                    size: 17,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bugün yayımlanan haber",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$_mockTodayNewsCount haber",
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  ">",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCommunityBlock(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMasterTab(2),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.34),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.72,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.forum_rounded,
                    size: 17,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bugün topluluk gönderileri",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$_mockTodayCommunityCount gönderi",
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  ">",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThisWeekBlock(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMasterTab(1),
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.secondary.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_repeat_rounded,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bu hafta öne çıkan etkinlik",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Kariyer Günleri",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Per",
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  ">",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThisWeekNewsBlock(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _scrollToNewsSection,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.34),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bu hafta yayımlanan haber",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$_mockWeekNewsCount haber",
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  ">",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThisWeekCommunityBlock(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMasterTab(2),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.34),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.72,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    size: 17,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bu hafta topluluk gönderileri",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$_mockWeekCommunityCount gönderi",
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  ">",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        key: const PageStorageKey('news_tab_loading'),
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildLoadingSection('Bugun')),
          const SliverToBoxAdapter(child: _LoadingSummaryCard()),
          const SliverToBoxAdapter(child: _LoadingSummaryCard()),
          SliverToBoxAdapter(child: _buildLoadingSection('Haberler')),
          const SliverToBoxAdapter(child: _LoadingFilterRow()),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _LoadingNewsCard(),
              );
            }, childCount: 3),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildLoadingSection(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          AppSkeleton(
            width: label.length * 11.0,
            height: 18,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: AppSkeleton(
              height: 1,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool showThisWeekFirst =
        _mockTodayNewsCount == 0 && _mockTodayCommunityCount == 0;
    final visibleArticles = _filteredArticles;

    if (_isInitialLoading) {
      return _buildLoadingState(context);
    }

    // Loading State
    /* if (false && _isInitialLoading) {
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
    } */

    if (_errorMessage != null) {
      return Center(child: Text("Hata: $_errorMessage"));
    }

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
            controller: _scrollController,
            key: const PageStorageKey('news_tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (showThisWeekFirst) ...[
                SliverToBoxAdapter(
                  child: _buildSectionLabel(context, "Bu Hafta"),
                ),
                SliverToBoxAdapter(child: _buildThisWeekBlock(context)),
                SliverToBoxAdapter(child: _buildThisWeekNewsBlock(context)),
                SliverToBoxAdapter(
                  child: _buildThisWeekCommunityBlock(context),
                ),
                SliverToBoxAdapter(child: _buildSectionLabel(context, "Bugün")),
                SliverToBoxAdapter(child: _buildTodayEventBlock(context)),
                SliverToBoxAdapter(child: _buildTodayNewsBlock(context)),
                SliverToBoxAdapter(child: _buildTodayCommunityBlock(context)),
              ] else ...[
                SliverToBoxAdapter(child: _buildSectionLabel(context, "Bugün")),
                SliverToBoxAdapter(child: _buildTodayEventBlock(context)),
                SliverToBoxAdapter(child: _buildTodayNewsBlock(context)),
                SliverToBoxAdapter(child: _buildTodayCommunityBlock(context)),
                SliverToBoxAdapter(
                  child: _buildSectionLabel(context, "Bu Hafta"),
                ),
                SliverToBoxAdapter(child: _buildThisWeekBlock(context)),
                SliverToBoxAdapter(child: _buildThisWeekNewsBlock(context)),
                SliverToBoxAdapter(
                  child: _buildThisWeekCommunityBlock(context),
                ),
              ],
              SliverToBoxAdapter(
                child: _buildSectionLabel(context, "Haberler"),
              ),
              SliverToBoxAdapter(child: _buildFilterBar(context)),
              // The List of News
              if (visibleArticles.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.34,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.filter_alt_off_rounded,
                            size: 32,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Bu filtrelerle eşleşen haber yok.',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Filtreleri değiştirip tekrar deneyebilirsin.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final newsItem = visibleArticles[index];
                    final bool isAllowed = _animateAllowedSet.contains(
                      newsItem,
                    );
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
                  }, childCount: visibleArticles.length),
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

class _LoadingSummaryCard extends StatelessWidget {
  const _LoadingSummaryCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: AppSkeleton(
        height: 74,
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
    );
  }
}

class _LoadingFilterRow extends StatelessWidget {
  const _LoadingFilterRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Expanded(child: AppSkeleton(height: 38)),
          SizedBox(width: 8),
          Expanded(child: AppSkeleton(height: 38)),
        ],
      ),
    );
  }
}

class _LoadingNewsCard extends StatelessWidget {
  const _LoadingNewsCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(
            height: 136,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          SizedBox(height: 14),
          AppSkeleton(
            height: 16,
            width: 190,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              AppSkeleton(
                height: 18,
                width: 18,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              SizedBox(width: 8),
              AppSkeleton(
                height: 10,
                width: 84,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
          SizedBox(height: 14),
          AppSkeleton(
            height: 10,
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          SizedBox(height: 7),
          AppSkeleton(
            height: 10,
            width: 210,
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              AppSkeleton(
                height: 12,
                width: 60,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              Spacer(),
              AppSkeleton(
                height: 12,
                width: 76,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
