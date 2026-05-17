import 'dart:async';
import 'dart:convert';

class NotificationNavigationIntentService {
  NotificationNavigationIntentService._();

  static final NotificationNavigationIntentService instance =
      NotificationNavigationIntentService._();
  static const int eventsTabIndex = 1;

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
    if (type.contains('event')) {
      return eventsTabIndex;
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
    if (deepLink.contains('/event/') || deepLink.contains('/events/')) {
      return eventsTabIndex;
    }

    return null;
  }
}
