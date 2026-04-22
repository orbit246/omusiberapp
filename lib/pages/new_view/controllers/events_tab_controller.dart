import 'package:flutter/foundation.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/background_refresh_coordinator.dart';
import 'package:omusiber/backend/cache_compare.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/post_view.dart';

class EventsTabController extends ChangeNotifier {
  EventsTabController({
    EventRepository? repository,
    AppStartupController? startupController,
  }) : _repository = repository ?? EventRepository(),
       _startupController = startupController ?? AppStartupController.instance {
    _backgroundRefresh = BackgroundRefreshCoordinator(
      startupController: _startupController,
      delay: _backgroundRefreshDelay,
      refresh: refreshInBackground,
      canRefresh: () => _startupController.canUseAuthenticatedApis,
    );
    _startupController.addListener(_handleStartupChanged);
  }

  static const Duration _backgroundRefreshDelay = Duration(seconds: 4);

  final EventRepository _repository;
  final AppStartupController _startupController;
  late final BackgroundRefreshCoordinator _backgroundRefresh;

  final List<PostView> _events = [];
  bool _isInitialLoading = true;
  String? _errorMessage;

  List<PostView> get events => List.unmodifiable(_events);
  bool get isInitialLoading => _isInitialLoading;
  String? get errorMessage => _errorMessage;

  String _mapErrorMessage(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();

    if (normalized.contains('502') || normalized.contains('bad gateway')) {
      return 'Etkinlikler Yüklenemedi, Sonra Tekrardan Deneyin';
    }

    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection refused') ||
        normalized.contains('connection closed') ||
        normalized.contains('connection reset') ||
        normalized.contains('timed out')) {
      return 'Etkinlikler Yüklenemedi, İnternet Bağlantınızı Kontrol Edin';
    }

    return raw.replaceFirst('Exception: ', '');
  }

  Future<void> loadInitialData() async {
    try {
      final cached = await _repository.getCachedEvents();
      final cachedEvents = _freshWithMocks(cached);
      if (cached.isNotEmpty) {
        _isInitialLoading = false;
        _errorMessage = null;
        _events
          ..clear()
          ..addAll(cachedEvents);
        notifyListeners();
      }
    } catch (error) {
      debugPrint("Failed to load initial events cache: $error");
    } finally {
      _handleStartupChanged();
    }
  }

  Future<void> refresh() => refreshInBackground();

  Future<void> refreshInBackground() async {
    try {
      final fresh = await _repository.fetchEvents(
        forceRefresh: true,
        fallbackToCacheOnError: false,
      );
      final freshEvents = _freshWithMocks(fresh);
      final shouldReplaceEvents = !jsonListEquals<PostView>(
        _events,
        freshEvents,
        (item) => item.toJson(),
      );
      final shouldClearLoading = _isInitialLoading && _events.isEmpty;

      if (!shouldReplaceEvents &&
          !shouldClearLoading &&
          _errorMessage == null) {
        return;
      }

      _isInitialLoading = false;
      _errorMessage = null;
      if (shouldReplaceEvents) {
        _events
          ..clear()
          ..addAll(freshEvents);
      }
      notifyListeners();
    } catch (error) {
      debugPrint("Background refresh failed: $error");
      if (_events.isEmpty) {
        _isInitialLoading = false;
        _errorMessage = _mapErrorMessage(error);
        notifyListeners();
      }
    }
  }

  Future<void> trackEventLike(String eventId, {required bool isLiked}) {
    return _repository.trackEventLike(eventId, isLiked: isLiked);
  }

  List<PostView> _freshWithMocks(List<PostView> fresh) {
    return [...fresh];
  }

  void _handleStartupChanged() {
    if (!_startupController.canUseAuthenticatedApis) {
      return;
    }
    _backgroundRefresh.schedule(ignoreStartupDeferral: _events.isEmpty);
  }

  @override
  void dispose() {
    _startupController.removeListener(_handleStartupChanged);
    _backgroundRefresh.dispose();
    super.dispose();
  }
}
