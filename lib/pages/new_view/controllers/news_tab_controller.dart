import 'package:flutter/foundation.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/background_refresh_coordinator.dart';
import 'package:omusiber/backend/cache_compare.dart';
import 'package:omusiber/backend/master_news_widgets_repository.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/backend/startup_logger.dart';
import 'package:omusiber/backend/view/master_news_widgets_view.dart';
import 'package:omusiber/backend/view/news_view.dart';

class NewsRefreshFeedback {
  const NewsRefreshFeedback({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;
}

class NewsTabController extends ChangeNotifier {
  NewsTabController({
    NewsFetcher? newsFetcher,
    MasterNewsWidgetsRepository? widgetsRepository,
    AppStartupController? startupController,
  }) : _newsFetcher = newsFetcher ?? NewsFetcher(),
       _widgetsRepository = widgetsRepository ?? MasterNewsWidgetsRepository(),
       _startupController = startupController ?? AppStartupController.instance {
    _backgroundRefresh = BackgroundRefreshCoordinator(
      startupController: _startupController,
      delay: _backgroundRefreshDelay,
      refresh: refreshInBackground,
      canRefresh: _canRunStartupRefresh,
    );
    _startupController.addListener(_handleStartupChanged);
  }

  static const Duration _backgroundRefreshDelay = Duration(seconds: 10);
  static const int _initialVisibleNewsCount = 5;
  static const int _newsLoadMoreStep = 5;

  final NewsFetcher _newsFetcher;
  final MasterNewsWidgetsRepository _widgetsRepository;
  final AppStartupController _startupController;
  late final BackgroundRefreshCoordinator _backgroundRefresh;

  final List<NewsView> _articles = [];
  final List<NewsFaculty> _faculties = [];
  final Set<String> _selectedTags = <String>{};

  MasterNewsWidgetsView? _summaryWidgets;
  String _selectedSortKey = 'newest';
  String _selectedDatePreset = 'all';
  String? _selectedFacultySlug;
  bool _isSummaryLoading = true;
  bool _isNewsLoading = true;
  bool _isFacultyNewsLoading = false;
  String? _errorMessage;
  int _visibleNewsCount = _initialVisibleNewsCount;
  bool _initialCacheLoadComplete = false;
  bool _startupRefreshComplete = false;
  Future<void>? _facultiesLoadFuture;

  List<NewsView> get articles => List.unmodifiable(_articles);
  List<NewsFaculty> get faculties => List.unmodifiable(_faculties);
  Set<String> get selectedTags => Set.unmodifiable(_selectedTags);
  MasterNewsWidgetsView? get summaryWidgets => _summaryWidgets;
  String get selectedSortKey => _selectedSortKey;
  String get selectedDatePreset => _selectedDatePreset;
  String? get selectedFacultySlug => _selectedFacultySlug;
  bool get isSummaryLoading => _isSummaryLoading;
  bool get isNewsLoading => _isNewsLoading;
  bool get isFacultyNewsLoading => _isFacultyNewsLoading;
  String? get errorMessage => _errorMessage;
  int get visibleNewsCount => _visibleNewsCount;
  bool get hasMoreVisibleNews =>
      visibleFilteredArticles.length < filteredArticles.length;

  String _mapErrorMessage(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();

    if (normalized.contains('502') || normalized.contains('bad gateway')) {
      return 'Haberler Yüklenemedi, Sonra Tekrardan Deneyin';
    }

    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection refused') ||
        normalized.contains('connection closed') ||
        normalized.contains('connection reset') ||
        normalized.contains('timed out')) {
      return 'Haberler Yüklenemedi, İnternet Bağlantınızı Kontrol Edin';
    }

    return raw.replaceFirst('Exception: ', '');
  }

  List<String> get availableTags {
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

  String get sortLabel {
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

  String get filterSummary {
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

    final facultyName = selectedFacultyName;
    if (facultyName != null) {
      parts.add(facultyName);
    }

    if (parts.isEmpty) {
      return 'Tümü';
    }

    return parts.join(' • ');
  }

  String? get selectedFacultyName {
    final selectedSlug = _selectedFacultySlug;
    if (selectedSlug == null) {
      return null;
    }

    for (final faculty in _faculties) {
      if (faculty.slug == selectedSlug) {
        return faculty.name;
      }
    }

    return selectedSlug;
  }

  List<NewsView> get filteredArticles {
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

  List<NewsView> get visibleFilteredArticles {
    final filtered = filteredArticles;
    if (_visibleNewsCount >= filtered.length) {
      return filtered;
    }
    return filtered.take(_visibleNewsCount).toList(growable: false);
  }

  Future<void> loadInitialData() async {
    try {
      StartupLogger.log('NewsTabController.loadInitialData() started');
      _isSummaryLoading = true;
      _isNewsLoading = true;
      _errorMessage = null;
      notifyListeners();

      final cachedResults = await Future.wait<dynamic>([
        _widgetsRepository.getCachedWidgets(),
        _newsFetcher.getCachedNews(),
      ]);
      final cachedSummaryWidgets = cachedResults[0] as MasterNewsWidgetsView?;
      final cachedNews = cachedResults[1] as List<NewsView>;

      _summaryWidgets = cachedSummaryWidgets;
      _articles
        ..clear()
        ..addAll(cachedNews);
      _resetVisibleNewsCount();
      _isSummaryLoading = false;
      _isNewsLoading = cachedNews.isEmpty;
      _errorMessage = null;
      _initialCacheLoadComplete = true;
      notifyListeners();
      _handleStartupChanged();
    } catch (error) {
      debugPrint("Failed to load initial news cache: $error");
      StartupLogger.log('NewsTabController.loadInitialData() failed: $error');
      _isSummaryLoading = false;
      _isNewsLoading = false;
      _errorMessage = _mapErrorMessage(error);
      _initialCacheLoadComplete = true;
      notifyListeners();
      _handleStartupChanged();
    }
  }

  void loadMoreNews() {
    final total = filteredArticles.length;
    if (_visibleNewsCount >= total) {
      return;
    }

    _visibleNewsCount = (_visibleNewsCount + _newsLoadMoreStep)
        .clamp(_initialVisibleNewsCount, total)
        .toInt();
    notifyListeners();
  }

  Future<List<NewsFaculty>> ensureFacultiesForFilters() async {
    if (_faculties.isNotEmpty) {
      return List<NewsFaculty>.unmodifiable(_faculties);
    }

    await _loadFaculties();
    return List<NewsFaculty>.unmodifiable(_faculties);
  }

  Future<void> refreshInBackground() async {
    try {
      final newData = await _newsFetcher.fetchLatestNews(
        forceRefresh: true,
        facultySlug: _selectedFacultySlug,
        fallbackToCacheOnError: false,
      );
      final widgets = await _fetchFreshSummaryWidgetsOrNull();
      final resolvedWidgets =
          widgets ?? _summaryWidgets ?? const MasterNewsWidgetsView();
      final shouldReplaceArticles = !jsonListEquals<NewsView>(
        _articles,
        newData,
        (item) => item.toJson(),
      );
      final shouldReplaceWidgets = !_summaryWidgetsMatch(
        _summaryWidgets,
        resolvedWidgets,
      );
      final shouldClearLoading = _isNewsLoading && _articles.isEmpty;

      if (!shouldReplaceArticles &&
          !shouldReplaceWidgets &&
          !shouldClearLoading &&
          _errorMessage == null) {
        _startupRefreshComplete = true;
        return;
      }

      _isNewsLoading = false;
      _errorMessage = null;
      if (shouldReplaceWidgets || _summaryWidgets == null) {
        _summaryWidgets = resolvedWidgets;
      }
      if (shouldReplaceArticles) {
        _articles
          ..clear()
          ..addAll(newData);
        _resetVisibleNewsCount();
      }
      notifyListeners();
      _startupRefreshComplete = true;
    } catch (error) {
      if (error is StateError) {
        return;
      }
      if (_articles.isEmpty) {
        _isNewsLoading = false;
        _errorMessage = _mapErrorMessage(error);
        notifyListeners();
      }
    }
  }

  Future<NewsRefreshFeedback?> refreshFromUser() async {
    try {
      final fetchedData = await _newsFetcher.fetchLatestNews(
        forceRefresh: true,
        facultySlug: _selectedFacultySlug,
        fallbackToCacheOnError: false,
      );
      final widgets = await _fetchFreshSummaryWidgetsOrNull();
      await _loadFaculties(forceRefresh: true);

      if (_selectedFacultySlug != null) {
        _summaryWidgets =
            widgets ?? _summaryWidgets ?? const MasterNewsWidgetsView();
        _articles
          ..clear()
          ..addAll(fetchedData);
        _resetVisibleNewsCount();
        notifyListeners();
        return const NewsRefreshFeedback(
          message: 'Haberler yenilendi',
          isSuccess: true,
        );
      }

      final newItems = fetchedData.where((newItem) {
        return !_articles.contains(newItem);
      }).toList();

      _summaryWidgets =
          widgets ?? _summaryWidgets ?? const MasterNewsWidgetsView();

      if (newItems.isNotEmpty) {
        _articles.insertAll(0, newItems);
        notifyListeners();
        return NewsRefreshFeedback(
          message: 'Yeni ${newItems.length} haber yüklendi',
          isSuccess: true,
        );
      }

      notifyListeners();
      return const NewsRefreshFeedback(
        message: 'Yeni haber bulunamadı',
        isSuccess: false,
      );
    } catch (error) {
      debugPrint("Refresh failed: $error");
      return null;
    }
  }

  Future<void> applyFilters({
    required String sortKey,
    required String datePreset,
    required String? facultySlug,
    required Set<String> tags,
  }) async {
    final facultyChanged = _selectedFacultySlug != facultySlug;

    _selectedSortKey = sortKey;
    _selectedDatePreset = datePreset;
    _selectedFacultySlug = facultySlug;
    _selectedTags
      ..clear()
      ..addAll(tags);
    _resetVisibleNewsCount();
    notifyListeners();

    if (facultyChanged) {
      await _reloadNewsForFacultyFilter();
    }
  }

  Future<void> clearActiveFilters() async {
    final hadFacultyFilter = _selectedFacultySlug != null;

    _selectedDatePreset = 'all';
    _selectedFacultySlug = null;
    _selectedTags.clear();
    _resetVisibleNewsCount();
    notifyListeners();

    if (hadFacultyFilter) {
      await _reloadNewsForFacultyFilter();
    }
  }

  Future<void> toggleNewsLike(int newsId, bool isLiked) async {
    final index = _articles.indexWhere((item) => item.id == newsId);
    if (index == -1) return;

    final current = _articles[index];
    final nextLikeCount = isLiked
        ? current.likeCount + 1
        : (current.likeCount > 0 ? current.likeCount - 1 : 0);

    _articles[index] = current.copyWith(
      isFavorited: isLiked,
      likeCount: nextLikeCount,
    );
    notifyListeners();

    await _newsFetcher.trackNewsLike(newsId, isLiked: isLiked);
  }

  Future<void> _loadFaculties({bool forceRefresh = false}) async {
    if (!forceRefresh && _facultiesLoadFuture != null) {
      return _facultiesLoadFuture;
    }

    final loadFuture = _loadFacultiesNow(forceRefresh: forceRefresh);
    if (!forceRefresh) {
      _facultiesLoadFuture = loadFuture.whenComplete(() {
        _facultiesLoadFuture = null;
      });
      return _facultiesLoadFuture!;
    }
    return loadFuture;
  }

  Future<void> _loadFacultiesNow({bool forceRefresh = false}) async {
    final faculties = await _newsFetcher.fetchFaculties(
      forceRefresh: forceRefresh,
    );

    _faculties
      ..clear()
      ..addAll(faculties);
    if (faculties.isNotEmpty &&
        _selectedFacultySlug != null &&
        !_faculties.any((faculty) => faculty.slug == _selectedFacultySlug)) {
      _selectedFacultySlug = null;
    }
    notifyListeners();
  }

  Future<void> _reloadNewsForFacultyFilter() async {
    _isFacultyNewsLoading = true;
    notifyListeners();

    try {
      final fetchedData = await _newsFetcher.fetchLatestNews(
        forceRefresh: true,
        facultySlug: _selectedFacultySlug,
        fallbackToCacheOnError: false,
      );
      _articles
        ..clear()
        ..addAll(fetchedData);
      _resetVisibleNewsCount();
    } catch (error) {
      debugPrint("Faculty-filtered news failed: $error");
    } finally {
      _isFacultyNewsLoading = false;
      notifyListeners();
    }
  }

  void _resetVisibleNewsCount() {
    _visibleNewsCount = _initialVisibleNewsCount;
  }

  bool _summaryWidgetsMatch(
    MasterNewsWidgetsView? current,
    MasterNewsWidgetsView next,
  ) {
    return jsonPayloadEquals(current?.toJson(), next.toJson());
  }

  Future<MasterNewsWidgetsView?> _fetchFreshSummaryWidgetsOrNull() async {
    try {
      return await _widgetsRepository.fetchWidgets(
        forceRefresh: true,
        fallbackToCacheOnError: false,
      );
    } catch (error) {
      debugPrint("Summary widgets refresh failed: $error");
      return null;
    }
  }

  bool _canRunStartupRefresh() {
    return _startupController.canUseAuthenticatedApis &&
        _initialCacheLoadComplete &&
        !_startupRefreshComplete;
  }

  void _handleStartupChanged() {
    if (!_canRunStartupRefresh()) {
      return;
    }
    _backgroundRefresh.schedule();
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

  @override
  void dispose() {
    _startupController.removeListener(_handleStartupChanged);
    _backgroundRefresh.dispose();
    super.dispose();
  }
}
