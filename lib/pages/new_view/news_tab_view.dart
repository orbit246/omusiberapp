import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/share_service.dart';
import 'package:omusiber/backend/startup_logger.dart';
import 'package:omusiber/backend/view/master_news_widgets_view.dart';
import 'package:omusiber/backend/view/news_view.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';
import 'package:omusiber/pages/news_item_page.dart';
import 'package:omusiber/pages/new_view/controllers/news_tab_controller.dart';
import 'package:omusiber/pages/new_view/master_view.dart';
import 'package:omusiber/pages/schedule_page.dart';
import 'package:omusiber/widgets/home/notification_consent_addon.dart';
import 'package:omusiber/widgets/news/news_card.dart';
import 'package:omusiber/widgets/shared/app_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsTabView extends StatefulWidget {
  const NewsTabView({super.key});

  @override
  State<NewsTabView> createState() => _NewsTabViewState();
}

class _NewsTabViewState extends State<NewsTabView> {
  static const int _imagePrefetchLimit = 2;
  static const String _todayExpandedPrefsKey = 'news_summary_today_expanded';
  static const String _weekExpandedPrefsKey = 'news_summary_week_expanded';
  late final NewsTabController _controller;
  final SimpleNotifications _notifications = SimpleNotifications();
  final Map<String, bool> _summarySectionExpanded = <String, bool>{
    'today': false,
    'week': false,
  };
  final Set<String> _prefetchedImageUrls = <String>{};

  bool _showBackToTopButton = false;
  final ScrollController _scrollController = ScrollController();
  bool _notificationPermissionGranted = true;
  bool _notificationPermissionLoaded = false;
  bool _notificationRequestInFlight = false;
  bool _notificationPromptHandled = false;
  Timer? _notificationPromptTimer;
  String? _lastControllerViewSignature;

  MasterNewsWidgetsView? get _summaryWidgets => _controller.summaryWidgets;
  String get _selectedSortKey => _controller.selectedSortKey;
  String get _selectedDatePreset => _controller.selectedDatePreset;
  String? get _selectedFacultySlug => _controller.selectedFacultySlug;
  Set<String> get _selectedTags => _controller.selectedTags;
  bool get _isSummaryLoading => _controller.isSummaryLoading;
  bool get _isNewsLoading => _controller.isNewsLoading;
  bool get _isFacultyNewsLoading => _controller.isFacultyNewsLoading;
  bool get _shouldShowColdStartShimmer =>
      _controller.shouldShowColdStartShimmer;
  String? get _errorMessage => _controller.errorMessage;
  List<NewsView> get _filteredArticles => _controller.filteredArticles;
  List<NewsView> get _visibleFilteredArticles =>
      _controller.visibleFilteredArticles;
  List<String> get _availableTags => _controller.availableTags;
  String get _sortLabel => _controller.sortLabel;
  String get _filterSummary => _controller.filterSummary;

  @override
  void initState() {
    super.initState();
    StartupLogger.log('NewsTabView.initState()');
    _controller = NewsTabController()..addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_restoreSummarySectionExpansionState());
      unawaited(_refreshNotificationConsentState());
      unawaited(_controller.loadInitialData());
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _notificationPromptTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _precacheNewsImagesIfNeeded(_controller.articles);
    final nextSignature = _buildControllerViewSignature();
    if (_lastControllerViewSignature == nextSignature) {
      return;
    }
    _lastControllerViewSignature = nextSignature;
    setState(() {});
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

  void _openSchedulePage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SchedulePage()));
  }

  void _loadMoreNews() {
    _controller.loadMoreNews();
  }

  bool _isCollapsibleSummarySection(MasterNewsWidgetSection section) {
    return section.id == 'today' || section.id == 'week';
  }

  bool _isPrimaryGlassSummarySection(MasterNewsWidgetSection section) {
    return section.id == 'today' || section.id == 'week';
  }

  Color _summarySectionAccentColor(
    BuildContext context,
    MasterNewsWidgetSection section,
  ) {
    switch (section.id) {
      case 'today':
        return const Color(0xFF8BCF2F);
      case 'week':
        return const Color(0xFF3D6DFF);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  bool _isSummarySectionExpanded(MasterNewsWidgetSection section) {
    return _summarySectionExpanded[section.id] ?? true;
  }

  String? _summarySectionSubtitle(MasterNewsWidgetSection section) {
    switch (section.id) {
      case 'today':
        return 'Günlük Gelişmeler';
      case 'week':
        return 'Haftalık Gelişmeler';
      default:
        return null;
    }
  }

  void _toggleSummarySection(MasterNewsWidgetSection section) {
    if (!_isCollapsibleSummarySection(section)) return;
    final nextValue = !_isSummarySectionExpanded(section);
    setState(() {
      _summarySectionExpanded[section.id] = nextValue;
    });
    unawaited(_persistSummarySectionExpansionState(section.id, nextValue));
  }

  Future<void> _restoreSummarySectionExpansionState() async {
    final prefs = await SharedPreferences.getInstance();
    final todayExpanded = prefs.getBool(_todayExpandedPrefsKey);
    final weekExpanded = prefs.getBool(_weekExpandedPrefsKey);
    if (!mounted) return;

    final nextTodayExpanded =
        todayExpanded ?? _summarySectionExpanded['today']!;
    final nextWeekExpanded = weekExpanded ?? _summarySectionExpanded['week']!;
    if (_summarySectionExpanded['today'] == nextTodayExpanded &&
        _summarySectionExpanded['week'] == nextWeekExpanded) {
      return;
    }

    setState(() {
      _summarySectionExpanded['today'] = nextTodayExpanded;
      _summarySectionExpanded['week'] = nextWeekExpanded;
    });
  }

  Future<void> _persistSummarySectionExpansionState(
    String sectionId,
    bool isExpanded,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final prefsKey = switch (sectionId) {
      'today' => _todayExpandedPrefsKey,
      'week' => _weekExpandedPrefsKey,
      _ => null,
    };
    if (prefsKey == null) {
      return;
    }
    await prefs.setBool(prefsKey, isExpanded);
  }

  Future<List<NewsFaculty>> _ensureFacultiesForFilters() async {
    return _controller.ensureFacultiesForFilters();
  }

  Future<void> _handleRefresh() async {
    final feedback = await _controller.refreshFromUser();
    if (!mounted || feedback == null) {
      return;
    }
    _showToast(
      feedback.message,
      feedback.isSuccess ? Icons.check_circle_rounded : Icons.info_rounded,
      feedback.isSuccess,
    );
  }

  Future<void> _retryInitialLoad() async {
    await _controller.retryInitialLoad();
  }

  void _clearActiveFilters() {
    unawaited(_controller.clearActiveFilters());
  }

  NewsView _bindNewsActionsForItem(NewsView item) {
    return item.copyWith(
      onToggleFavorite: (isLiked) => _handleNewsLikeToggle(item.id, isLiked),
      onShare: () => unawaited(ShareService.shareNews(context, item)),
      onOpen: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewsItemPage(view: item)),
        );
      },
    );
  }

  String _buildControllerViewSignature() {
    final summarySignature =
        _summaryWidgets?.toJson().toString() ?? 'no-summary';
    final articlesSignature = _visibleFilteredArticles
        .map(
          (item) =>
              '${item.id}:${item.likeCount}:${item.viewCount}:${item.isFavorited}',
        )
        .join('|');

    return [
      summarySignature,
      articlesSignature,
      _filteredArticles.length,
      _isSummaryLoading,
      _isNewsLoading,
      _isFacultyNewsLoading,
      _errorMessage ?? '',
      _selectedSortKey,
      _selectedDatePreset,
      _selectedFacultySlug ?? '',
      _selectedTags.join('|'),
      _shouldShowColdStartShimmer,
    ].join('::');
  }

  void _precacheNewsImagesIfNeeded(List<NewsView> items) {
    final urlsToPrefetch = items
        .take(_imagePrefetchLimit)
        .map((item) => item.heroImage?.trim() ?? '')
        .where((url) => url.isNotEmpty)
        .toSet();
    final pendingUrls = urlsToPrefetch.difference(_prefetchedImageUrls);
    if (pendingUrls.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final url in pendingUrls) {
        _prefetchedImageUrls.add(url);
        unawaited(precacheImage(CachedNetworkImageProvider(url), context));
      }
    });
  }

  void _handleNewsLikeToggle(int newsId, bool isLiked) {
    unawaited(_controller.toggleNewsLike(newsId, isLiked));
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

  Future<void> _refreshNotificationConsentState({
    bool schedulePrompt = false,
  }) async {
    final hasPermission = await _notifications.checkPermission();
    if (!mounted) return;

    setState(() {
      _notificationPermissionGranted = hasPermission;
      _notificationPermissionLoaded = true;
    });

    if (!hasPermission && schedulePrompt) {
      unawaited(_scheduleNotificationPrompt());
    }
  }

  Future<void> _scheduleNotificationPrompt() async {
    if (_notificationPromptHandled) {
      return;
    }

    final shouldShow = await _notifications.shouldShowEnablePrompt();
    if (!mounted || !shouldShow) {
      return;
    }

    _notificationPromptHandled = true;
    _notificationPromptTimer?.cancel();
    _notificationPromptTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _notificationPermissionGranted) {
        return;
      }
      unawaited(_showNotificationPrompt());
    });
  }

  Future<void> _showNotificationPrompt() async {
    await _notifications.markEnablePromptSeen();
    if (!mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Bildirimleri etkinleştir',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fakültene özel haberler, etkinlikler ve topluluk gönderileri yayına alındığında hızlıca haber al.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Daha sonra'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Etkinleştir'),
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

    if (shouldEnable == true) {
      await _enableNotifications();
    }
  }

  Future<void> _enableNotifications() async {
    if (_notificationRequestInFlight) {
      return;
    }

    setState(() => _notificationRequestInFlight = true);
    final granted = await _notifications.requestPermission();
    if (!mounted) return;

    await _refreshNotificationConsentState();
    if (!mounted) return;

    setState(() => _notificationRequestInFlight = false);

    _showToast(
      granted
          ? 'Bildirimler etkinleştirildi.'
          : 'Bildirim izni verilmedi. Ayarlardan daha sonra açabilirsin.',
      granted ? Icons.check_circle_rounded : Icons.info_rounded,
      granted,
    );
  }

  Widget _buildFilterPill(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final accentColor = const Color(0xFF3D6DFF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? [
                      accentColor.withValues(alpha: 0.95),
                      accentColor.withValues(alpha: 0.78),
                    ]
                  : [const Color(0xFF1A2740), const Color(0xFF111C31)],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? accentColor.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.72),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveFilters =
        _selectedDatePreset != 'all' ||
        _selectedTags.isNotEmpty ||
        _selectedFacultySlug != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: _buildPrimaryGlassSurface(
        context,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: const Color(0xFF0F1E34).withValues(alpha: 0.98),
        borderColor: Colors.white.withValues(alpha: 0.12),
        accentColor: const Color(0xFF3D6DFF),
        child: Row(
          children: [
            Icon(
              Icons.filter_alt_outlined,
              size: 20,
              color: const Color(0xFF3D6DFF),
            ),
            const SizedBox(width: 10),
            Text(
              'Filtrele',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_isFacultyNewsLoading) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFF3D6DFF),
                ),
              ),
            ],
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
            if (hasActiveFilters) ...[
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _clearActiveFilters,
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34151A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    String tempSortKey = _selectedSortKey;
    String tempDatePreset = _selectedDatePreset;
    String? tempFacultySlug = _selectedFacultySlug;
    final Set<String> tempTags = {..._selectedTags};
    final facultiesFuture = _ensureFacultiesForFilters();

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
              child: SingleChildScrollView(
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
                        'Fakülte',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<NewsFaculty>>(
                        future: facultiesFuture,
                        builder: (context, snapshot) {
                          final faculties =
                              snapshot.data ?? const <NewsFaculty>[];

                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              faculties.isEmpty) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Fakülte listesi yükleniyor.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          if (faculties.isEmpty) {
                            return Text(
                              'Fakülte listesi şu anda yüklenemedi.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            );
                          }

                          return Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              buildChoice(
                                label: 'Tümü',
                                selected: tempFacultySlug == null,
                                onTap: () =>
                                    setModalState(() => tempFacultySlug = null),
                              ),
                              ...faculties.map((faculty) {
                                return buildChoice(
                                  label: faculty.name,
                                  selected: tempFacultySlug == faculty.slug,
                                  onTap: () => setModalState(
                                    () => tempFacultySlug = faculty.slug,
                                  ),
                                );
                              }),
                            ],
                          );
                        },
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
                                    ? colorScheme.primary.withValues(
                                        alpha: 0.24,
                                      )
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
                                  tempFacultySlug = null;
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
                                Navigator.of(context).pop();
                                unawaited(
                                  _controller.applyFilters(
                                    sortKey: tempSortKey,
                                    datePreset: tempDatePreset,
                                    facultySlug: tempFacultySlug,
                                    tags: tempTags,
                                  ),
                                );
                              },
                              child: const Text('Uygula'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String title, {
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleSectionHeader(
    BuildContext context,
    MasterNewsWidgetSection section,
  ) {
    final theme = Theme.of(context);
    final isExpanded = _isSummarySectionExpanded(section);
    final subtitle = _summarySectionSubtitle(section);
    final borderRadius = BorderRadius.circular(18);
    final accentColor = _summarySectionAccentColor(context, section);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Semantics(
        button: true,
        toggled: isExpanded,
        label:
            '${section.title} bolumunu ${isExpanded ? 'daralt' : 'genislet'}',
        child: _buildPrimaryGlassSurface(
          context,
          borderRadius: borderRadius,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          onTap: () => _toggleSummarySection(section),
          accentColor: accentColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.98),
                      accentColor.withValues(alpha: 0.76),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Align(
                alignment: Alignment.center,
                child: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: 0.88),
                  size: 24,
                ),
              ),
            ],
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
          if (_notificationPermissionLoaded && !_notificationPermissionGranted)
            SliverToBoxAdapter(
              child: NotificationConsentAddon(
                onEnable: _enableNotifications,
                isLoading: _notificationRequestInFlight,
              ),
            ),
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

  Widget _buildNewsLoadingIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Haberler yukleniyor...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialLoadError(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 34,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Haberler yuklenemedi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _retryInitialLoad,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
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

  List<Widget> _buildSummarySlivers(BuildContext context) {
    final summaryWidgets = _summaryWidgets;
    if (summaryWidgets == null) {
      if (_isSummaryLoading) {
        debugPrint(
          '[NewsTabView] Summary widgets are null; showing loading state.',
        );
        return const [
          SliverToBoxAdapter(child: _LoadingSummaryCard()),
          SliverToBoxAdapter(child: _LoadingSummaryCard()),
        ];
      }

      return [
        SliverToBoxAdapter(
          child: _buildSummaryUnavailableCard(
            context,
            'Ozet widget verisi su anda kullanilamiyor.',
          ),
        ),
      ];
    }

    if (summaryWidgets.sections.isEmpty) {
      debugPrint(
        '[NewsTabView] Summary widgets parsed with 0 sections; showing fallback card.',
      );
      return [
        SliverToBoxAdapter(
          child: _buildSummaryUnavailableCard(
            context,
            'Ozet widget verisi API tarafindan henuz donmedi.',
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    for (final section in summaryWidgets.sections) {
      if (section.title.trim().isNotEmpty) {
        final isCollapsible = _isCollapsibleSummarySection(section);
        slivers.add(
          SliverToBoxAdapter(
            child: isCollapsible
                ? _buildCollapsibleSectionHeader(context, section)
                : _buildSectionLabel(context, section.title),
          ),
        );
        if (isCollapsible && !_isSummarySectionExpanded(section)) {
          continue;
        }
      }

      if (section.cards.isEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: _buildSummaryUnavailableCard(
              context,
              'Bu bolum icin API kart verisi donmedi.',
            ),
          ),
        );
        continue;
      }

      for (var index = 0; index < section.cards.length; index++) {
        slivers.add(
          SliverToBoxAdapter(
            child: _buildApiSummaryCard(
              context,
              section: section,
              card: section.cards[index],
              isLastInSection: index == section.cards.length - 1,
            ),
          ),
        );
      }
    }

    return slivers;
  }

  Widget _buildSummaryUnavailableCard(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
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
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiSummaryCard(
    BuildContext context, {
    required MasterNewsWidgetSection section,
    required MasterNewsWidgetCard card,
    required bool isLastInSection,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final style = _summaryCardStyle(context, section: section, card: card);
    final accentColor = _summarySectionAccentColor(context, section);
    final usePrimaryGlass = _isPrimaryGlassSummarySection(section);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, isLastInSection ? 16 : 10),
      child: _buildPrimaryGlassSurface(
        context,
        borderRadius: BorderRadius.circular(style.borderRadius),
        padding: const EdgeInsets.all(16),
        onTap: card.isInteractive ? () => _handleSummaryCardTap(card) : null,
        backgroundColor: style.backgroundColor,
        borderColor: style.borderColor,
        accentColor: accentColor,
        child: Row(
          children: [
            Container(
              width: style.iconBoxSize,
              height: style.iconBoxSize,
              decoration: BoxDecoration(
                color: style.iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                style.icon,
                size: style.iconSize,
                color: style.iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: usePrimaryGlass
                          ? Colors.white.withValues(alpha: 0.78)
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: usePrimaryGlass
                          ? Colors.white
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (card.trailingText != null &&
                card.trailingText!.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                card.trailingText!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: style.trailingColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (card.isInteractive) ...[
              const SizedBox(width: 6),
              Text(
                '>',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryGlassSurface(
    BuildContext context, {
    required BorderRadius borderRadius,
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    VoidCallback? onTap,
    Color? backgroundColor,
    Color? borderColor,
    Color? accentColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedAccent = accentColor ?? colorScheme.primary;
    final resolvedBackground =
        backgroundColor ?? const Color(0xFF0F1E34).withValues(alpha: 0.98);

    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF152746),
              resolvedBackground,
              const Color(0xFF0B1529),
            ],
          ),
          border: Border.all(
            color: borderColor ?? Colors.white.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -18,
              top: -14,
              child: IgnorePointer(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: resolvedAccent.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSummaryCardTap(MasterNewsWidgetCard card) {
    switch (card.actionType) {
      case MasterNewsWidgetActionType.openTab:
        final tabIndex = card.targetTabIndex;
        if (tabIndex == null) return;
        _openMasterTab(tabIndex);
        break;
      case MasterNewsWidgetActionType.openSchedule:
        _openSchedulePage();
        break;
      case MasterNewsWidgetActionType.scrollNewsList:
        _scrollToNewsSection();
        break;
      case MasterNewsWidgetActionType.none:
        break;
    }
  }

  _SummaryCardStyle _summaryCardStyle(
    BuildContext context, {
    required MasterNewsWidgetSection section,
    required MasterNewsWidgetCard card,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = section.id == 'today';
    final usePrimaryGlass = _isPrimaryGlassSummarySection(section);
    final accentColor = _summarySectionAccentColor(context, section);

    switch (card.kind) {
      case MasterNewsWidgetCardKind.event:
        if (usePrimaryGlass) {
          return _SummaryCardStyle(
            borderRadius: 24,
            backgroundColor: const Color(0xFF11213A).withValues(alpha: 0.98),
            borderColor: Colors.white.withValues(alpha: 0.12),
            iconBackgroundColor: accentColor,
            iconColor: Colors.white,
            icon: isToday
                ? Icons.event_available_rounded
                : Icons.event_repeat_rounded,
            iconBoxSize: 38,
            iconSize: 18,
            trailingColor: Colors.white,
          );
        }
        return isToday
            ? _SummaryCardStyle(
                borderRadius: 24,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
                borderColor: colorScheme.primary.withValues(alpha: 0.16),
                iconBackgroundColor: colorScheme.primaryContainer,
                iconColor: colorScheme.onPrimaryContainer,
                icon: Icons.event_available_rounded,
                iconBoxSize: 38,
                iconSize: 18,
                trailingColor: colorScheme.primary,
              )
            : _SummaryCardStyle(
                borderRadius: 24,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
                borderColor: colorScheme.secondary.withValues(alpha: 0.18),
                iconBackgroundColor: colorScheme.secondaryContainer,
                iconColor: colorScheme.onSecondaryContainer,
                icon: Icons.event_repeat_rounded,
                iconBoxSize: 38,
                iconSize: 18,
                trailingColor: colorScheme.secondary,
              );
      case MasterNewsWidgetCardKind.news:
        if (usePrimaryGlass) {
          return _SummaryCardStyle(
            borderRadius: 22,
            backgroundColor: const Color(0xFF11213A).withValues(alpha: 0.98),
            borderColor: Colors.white.withValues(alpha: 0.12),
            iconBackgroundColor: accentColor,
            iconColor: Colors.white,
            icon: isToday ? Icons.newspaper_rounded : Icons.date_range_rounded,
            iconBoxSize: 36,
            iconSize: 18,
            trailingColor: Colors.white,
          );
        }
        return isToday
            ? _SummaryCardStyle(
                borderRadius: 22,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.82),
                borderColor: colorScheme.outlineVariant.withValues(alpha: 0.34),
                iconBackgroundColor: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.72),
                iconColor: colorScheme.primary,
                icon: Icons.newspaper_rounded,
                iconBoxSize: 34,
                iconSize: 17,
                trailingColor: colorScheme.primary,
              )
            : _SummaryCardStyle(
                borderRadius: 22,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
                borderColor: colorScheme.outlineVariant.withValues(alpha: 0.34),
                iconBackgroundColor: colorScheme.secondaryContainer,
                iconColor: colorScheme.onSecondaryContainer,
                icon: Icons.date_range_rounded,
                iconBoxSize: 38,
                iconSize: 18,
                trailingColor: colorScheme.secondary,
              );
      case MasterNewsWidgetCardKind.lesson:
        if (usePrimaryGlass) {
          return _SummaryCardStyle(
            borderRadius: 22,
            backgroundColor: const Color(0xFF11213A).withValues(alpha: 0.98),
            borderColor: Colors.white.withValues(alpha: 0.12),
            iconBackgroundColor: accentColor,
            iconColor: Colors.white,
            icon: Icons.menu_book_rounded,
            iconBoxSize: 36,
            iconSize: 18,
            trailingColor: Colors.white,
          );
        }
        return isToday
            ? _SummaryCardStyle(
                borderRadius: 22,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.84),
                borderColor: colorScheme.tertiary.withValues(alpha: 0.22),
                iconBackgroundColor: colorScheme.tertiaryContainer,
                iconColor: colorScheme.onTertiaryContainer,
                icon: Icons.menu_book_rounded,
                iconBoxSize: 36,
                iconSize: 18,
                trailingColor: colorScheme.tertiary,
              )
            : _SummaryCardStyle(
                borderRadius: 22,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
                borderColor: colorScheme.outlineVariant.withValues(alpha: 0.34),
                iconBackgroundColor: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.72),
                iconColor: colorScheme.primary,
                icon: Icons.menu_book_rounded,
                iconBoxSize: 34,
                iconSize: 17,
                trailingColor: colorScheme.primary,
              );
      case MasterNewsWidgetCardKind.community:
      case MasterNewsWidgetCardKind.unknown:
        if (usePrimaryGlass) {
          return _SummaryCardStyle(
            borderRadius: 22,
            backgroundColor: const Color(0xFF11213A).withValues(alpha: 0.98),
            borderColor: Colors.white.withValues(alpha: 0.12),
            iconBackgroundColor: accentColor,
            iconColor: Colors.white,
            icon: isToday ? Icons.forum_rounded : Icons.groups_rounded,
            iconBoxSize: 36,
            iconSize: 18,
            trailingColor: Colors.white,
          );
        }
        return _SummaryCardStyle(
          borderRadius: 22,
          backgroundColor: colorScheme.surface.withValues(
            alpha: isToday ? 0.82 : 0.88,
          ),
          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.34),
          iconBackgroundColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.72,
          ),
          iconColor: colorScheme.primary,
          icon: isToday ? Icons.forum_rounded : Icons.groups_rounded,
          iconBoxSize: 34,
          iconSize: 17,
          trailingColor: colorScheme.primary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleArticles = _visibleFilteredArticles;

    if ((_isSummaryLoading && _isNewsLoading) || _shouldShowColdStartShimmer) {
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

    if (_errorMessage != null && !_isNewsLoading && visibleArticles.isEmpty) {
      return _buildInitialLoadError(context, _errorMessage!);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.axis == Axis.vertical) {
            final shouldShowBackToTop = scrollInfo.metrics.pixels >= 500;
            if (shouldShowBackToTop != _showBackToTopButton) {
              setState(() => _showBackToTopButton = shouldShowBackToTop);
            }
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          displacement: 20,
          edgeOffset: 0,
          child: CustomScrollView(
            cacheExtent: 300,
            controller: _scrollController,
            key: const PageStorageKey('news_tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (_notificationPermissionLoaded &&
                  !_notificationPermissionGranted)
                SliverToBoxAdapter(
                  child: NotificationConsentAddon(
                    onEnable: _enableNotifications,
                    isLoading: _notificationRequestInFlight,
                  ),
                ),
              ..._buildSummarySlivers(context),
              SliverToBoxAdapter(
                child: _buildSectionLabel(
                  context,
                  "Haberler",
                  isLoading: _isNewsLoading,
                ),
              ),
              SliverToBoxAdapter(child: _buildFilterBar(context)),
              // The List of News
              if (_isNewsLoading && visibleArticles.isEmpty)
                SliverToBoxAdapter(child: _buildNewsLoadingIndicator(context))
              else if (visibleArticles.isEmpty)
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
                    final newsItem = _bindNewsActionsForItem(
                      visibleArticles[index],
                    );
                    return Padding(
                      key: ValueKey(newsItem),
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: NewsCard(view: newsItem),
                    );
                  }, childCount: visibleArticles.length),
                ),
              if (!_isNewsLoading &&
                  visibleArticles.isNotEmpty &&
                  visibleArticles.length < _filteredArticles.length)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: FilledButton.tonalIcon(
                      onPressed: _loadMoreNews,
                      icon: const Icon(Icons.expand_more_rounded),
                      label: Text(
                        'Daha fazla haber göster (${_filteredArticles.length - visibleArticles.length})',
                      ),
                    ),
                  ),
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

class _SummaryCardStyle {
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color trailingColor;
  final IconData icon;
  final double iconBoxSize;
  final double iconSize;

  const _SummaryCardStyle({
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.trailingColor,
    required this.icon,
    required this.iconBoxSize,
    required this.iconSize,
  });
}
