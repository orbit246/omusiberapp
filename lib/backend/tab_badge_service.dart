import 'package:shared_preferences/shared_preferences.dart';

class TabBadgeService {
  static const _keyNews = 'last_viewed_news';
  static const _keyEvents = 'last_viewed_events';
  static const _keyNotifs = 'last_viewed_notifs';
  static const _keyCommunity = 'last_viewed_community';

  Future<void> markNewsViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNews, DateTime.now().toIso8601String());
  }

  Future<void> markEventsViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEvents, DateTime.now().toIso8601String());
  }

  Future<void> markNotifsViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotifs, DateTime.now().toIso8601String());
  }

  Future<void> markCommunityViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCommunity, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastViewedNews() async {
    return _getDate(_keyNews);
  }

  Future<DateTime?> getLastViewedEvents() async {
    return _getDate(_keyEvents);
  }

  Future<DateTime?> getLastViewedNotifs() async {
    return _getDate(_keyNotifs);
  }

  Future<DateTime?> getLastViewedCommunity() async {
    return _getDate(_keyCommunity);
  }

  Future<DateTime?> _getDate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(key);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }
}
