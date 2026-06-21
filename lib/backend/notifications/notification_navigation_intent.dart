import 'dart:async';
import 'dart:convert';

class NotificationNavigationIntentService {
  NotificationNavigationIntentService._();

  static final NotificationNavigationIntentService instance =
      NotificationNavigationIntentService._();
  static const int newsTabIndex = 0;
  static const int eventsTabIndex = 1;
  static const int communityTabIndex = 2;

  final StreamController<int> _tabIndexController =
      StreamController<int>.broadcast();

  int? _pendingTabIndex;

  Stream<int> get tabIndexStream => _tabIndexController.stream;

  int? consumePendingTabIndex() {
    final tabIndex = _pendingTabIndex;
    _pendingTabIndex = null;
    return tabIndex;
  }

  void queueDefaultEventsTab() {
    _pendingTabIndex = eventsTabIndex;
    _tabIndexController.add(eventsTabIndex);
  }

  bool queueFromData(Map<String, dynamic> data) {
    if (data.isEmpty) {
      queueDefaultEventsTab();
      return true;
    }

    final tabIndex = _tabIndexFromData(data);
    if (tabIndex == null) {
      return false;
    }

    _pendingTabIndex = tabIndex;
    _tabIndexController.add(tabIndex);
    return true;
  }

  bool queueFromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      queueDefaultEventsTab();
      return true;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return queueFromData(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      queueDefaultEventsTab();
      return true;
    }

    queueDefaultEventsTab();
    return true;
  }

  int? _tabIndexFromData(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['category'] ?? data['targetTab'] ?? '')
        .toString()
        .toLowerCase();
    if (type.contains('news') || type.contains('announcement')) {
      return newsTabIndex;
    }
    if (type.contains('event')) {
      return eventsTabIndex;
    }
    if (type.contains('community')) {
      return communityTabIndex;
    }

    final deepLink =
        (data['deepLinkUrl'] ??
                data['deepLinkUri'] ??
                data['deeplink'] ??
                data['deep_link'] ??
                data['url'] ??
                data['link'])
            .toString()
            .toLowerCase();
    if (deepLink.contains('/community/post/') ||
        deepLink.contains('/community/')) {
      return communityTabIndex;
    }
    if (deepLink.contains('/event/') || deepLink.contains('/events/')) {
      return eventsTabIndex;
    }
    if (deepLink.contains('/news/') || deepLink.contains('/haber/')) {
      return newsTabIndex;
    }

    return null;
  }
}
