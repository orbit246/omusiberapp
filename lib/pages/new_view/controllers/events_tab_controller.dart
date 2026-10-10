import 'package:flutter/foundation.dart';
import 'package:omusiber/backend/cache_compare.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/post_view.dart';

class EventsTabController extends ChangeNotifier {
  EventsTabController({EventRepository? repository})
    : _repository = repository ?? EventRepository();

  final EventRepository _repository;

  final List<PostView> _events = [];
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  List<PostView> get events => List.unmodifiable(_events);
  bool get isInitialLoading => _isInitialLoading;
  bool get isRefreshing => _isRefreshing;
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
    }

    // Events are public, so do not wait for Firebase/auth startup or a
    // background-refresh timer before asking for the current list.
    await refreshInBackground();
  }

  Future<void> refresh() => refreshInBackground();

  Future<void> refreshInBackground() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    notifyListeners();
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
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> trackEventLike(String eventId, {required bool isLiked}) {
    return _repository.trackEventLike(eventId, isLiked: isLiked);
  }

  Future<void> toggleEventLike(String eventId, bool isLiked) async {
    final index = _events.indexWhere((event) => event.id == eventId);
    if (index == -1) return;

    final current = _events[index];
    final nextLikeCount = isLiked
        ? current.likeCount + (current.isLiked ? 0 : 1)
        : (current.likeCount - (current.isLiked ? 1 : 0)).clamp(0, 1 << 30);

    _events[index] = current.copyWith(
      isLiked: isLiked,
      metadata: {...current.metadata, 'likes': nextLikeCount},
    );
    notifyListeners();

    try {
      await _repository.trackEventLike(eventId, isLiked: isLiked);
    } catch (error) {
      debugPrint('Event like toggle failed: $error');
      _events[index] = current;
      notifyListeners();
    }
  }

  List<PostView> _freshWithMocks(List<PostView> fresh) {
    final events = [...fresh];
    _repository.sortEventsByClosestDate(events);
    return events;
  }
}
