import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventRepository {
  static const String _storageKey = 'cached_events_list';
  static final Set<String> _locallyJoinedEventIds = <String>{};
  List<PostView>? _cachedEvents;

  EventRepository({
    // Keep constructor parameters optional to avoid breaking existing calls
    dynamic firestore,
    String? collectionPath,
    Duration? minRefreshDelay,
    Duration? cacheTtl,
  });

  Future<List<PostView>> getCachedEvents() async {
    if (_cachedEvents != null && _cachedEvents!.isNotEmpty) {
      _sortEventsMostRecent(_cachedEvents!);
      return _cachedEvents!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        _cachedEvents = decoded.map((item) => PostView.fromJson(item)).toList();
        _sortEventsMostRecent(_cachedEvents!);
        return _cachedEvents!;
      }
    } catch (e) {
      debugPrint('Failed to load events from persistent cache: $e');
    }
    return [];
  }

  String get _baseUrl => Constants.baseUrl;

  Future<String> _getAuthToken() async {
    var user = FirebaseAuth.instance.currentUser;
    user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
    if (user == null) {
      throw Exception('Authentication failed: no Firebase user available.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication failed: empty Firebase ID token.');
    }
    return token;
  }

  Future<Map<String, String>> _authorizedHeaders({
    bool includeJsonContentType = false,
  }) async {
    final token = await _getAuthToken();
    return {
      if (includeJsonContentType) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _optionalAuthHeaders({
    bool includeJsonContentType = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : null;
    return {
      if (includeJsonContentType) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<PostView>> fetchEvents({bool forceRefresh = false}) async {
    // 1. Return cached events if available and not forcing refresh
    if (!forceRefresh) {
      final cached = await getCachedEvents();
      if (cached.isNotEmpty) return cached;
    }

    try {
      // User requested to call it directly as it doesn't require authentication
      final response = await http.get(Uri.parse('$_baseUrl/events'));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body);

      // Use the updated PostView.fromJson which handles the new API fields
      final List<PostView> events = data
          .map<PostView>((jsonItem) => PostView.fromJson(jsonItem))
          .toList();
      _sortEventsMostRecent(events);

      // Persist to storage
      _cachedEvents = events;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        json.encode(events.map((e) => e.toJson()).toList()),
      );

      return events;
    } catch (e) {
      debugPrint('Error fetching events from API: $e');

      // Try fallback to cache
      final cached = await getCachedEvents();
      if (cached.isNotEmpty) return cached;

      // Return just the example event on error, so the user can see it
      return [
        PostView(
          id: 'example-event-error',
          title: 'Siber Güvenlik Konferansı (Offline)',
          description: 'Ağ hatası oluştu veya sunucuya erişilemiyor.',
          tags: ['Siber Güvenlik', 'Örnek'],
          maxContributors: 100,
          remainingContributors: 50,
          ticketPrice: 0.0,
          location: 'Mühendislik Fakültesi',
          thubnailUrl:
              'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?auto=format&fit=crop&w=800&q=80',
          imageLinks: [],
          metadata: {
            'datetimeText': '20 Ekim 2025',
            'eventDate': DateTime.now().toIso8601String(),
          },
        ),
      ];
    }
  }

  Stream<List<PostView>> eventsStream({bool forceRefresh = false}) {
    // Return a single-event stream for compatibility
    return Stream.fromFuture(fetchEvents(forceRefresh: forceRefresh));
  }

  Future<void> addEvent(PostView event) async {
    final dynamic rawEventDate = event.metadata['eventDate'];
    final String eventDate = rawEventDate is DateTime
        ? rawEventDate.toIso8601String()
        : rawEventDate?.toString() ?? DateTime.now().toIso8601String();
    final dynamic rawEventLength = event.metadata['eventLength'];
    final double? eventLength = rawEventLength is num
        ? rawEventLength.toDouble()
        : double.tryParse(rawEventLength?.toString() ?? '');

    // Prepare content for API
    final Map<String, dynamic> body = {
      'title': event.title,
      'date': eventDate,
      'description': event.description,
      'tags': jsonEncode(event.tags), // Send as JSON string
    };

    if (eventLength != null) {
      body['eventLength'] = eventLength;
    }
    if (event.location.trim().isNotEmpty) {
      body['location'] = event.location.trim();
    }
    if (event.maxContributors > 0) {
      body['maxJoiners'] = event.maxContributors;
    }
    if (event.thubnailUrl.trim().isNotEmpty) {
      body['thumbnailUrl'] = event.thubnailUrl;
    }
    if (event.imageLinks.isNotEmpty) {
      body['carouselImages'] = jsonEncode(event.imageLinks);
    }

    try {
      final headers = await _authorizedHeaders(includeJsonContentType: true);
      final response = await http.post(
        Uri.parse('$_baseUrl/events/create'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('Event created successfully.');
        return;
      } else {
        throw Exception(
          'Failed to create event: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error creating event via API: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      final headers = await _authorizedHeaders(includeJsonContentType: true);
      // API expects integer ID if possible, but our ID is String.
      // We try to parse it. If it's not a number (like 'example-event'), it will fail on server side or we skip.
      final int? idAsInt = int.tryParse(eventId);
      if (idAsInt == null) {
        debugPrint('Cannot delete event with non-integer ID: $eventId');
        return;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/events/delete'),
        headers: headers,
        body: jsonEncode({'id': idAsInt}),
      );
      if (response.statusCode != 200) {
        debugPrint('Failed to delete event: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting event: $e');
    }
  }

  Future<void> joinEvent(String eventId) async {
    if (_locallyJoinedEventIds.contains(eventId)) {
      return;
    }

    // API expects int ID usually
    final int? idAsInt = int.tryParse(eventId);
    final bodyId = idAsInt ?? eventId;

    try {
      final headers = await _authorizedHeaders(includeJsonContentType: true);
      final response = await http.post(
        Uri.parse('$_baseUrl/events/$bodyId/join'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Katilma basarisiz: ${response.statusCode}');
      }
      _locallyJoinedEventIds.add(eventId);
    } catch (e) {
      debugPrint("Error joining event: $e");
      rethrow;
    }
  }

  Future<bool> isEventJoined(String eventId) async {
    final bodyId = _eventBodyId(eventId);
    if (bodyId == null) return false;

    try {
      final headers = await _optionalAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/events/$bodyId/is-joined'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        return _locallyJoinedEventIds.contains(eventId);
      }

      final data = jsonDecode(response.body);
      final isJoined = data is Map<String, dynamic>
          ? (data['isJoined'] as bool? ?? false)
          : false;
      if (isJoined) {
        _locallyJoinedEventIds.add(eventId);
      }
      return isJoined;
    } catch (_) {
      return _locallyJoinedEventIds.contains(eventId);
    }
  }

  Future<PostView?> fetchEventById(String eventId) async {
    final bodyId = _eventBodyId(eventId);
    if (bodyId == null) return null;

    try {
      final headers = await _optionalAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/events/$bodyId'),
        headers: headers,
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      final fetched = PostView.fromJson(data);
      if (fetched.isJoined) {
        _locallyJoinedEventIds.add(fetched.id);
      }
      _upsertCachedEvent(fetched);
      return fetched;
    } catch (_) {
      return null;
    }
  }

  Future<void> trackEventView(String eventId) async {
    final bodyId = _eventBodyId(eventId);
    if (bodyId == null) return;
    await _postEventInteraction(endpoint: 'view', bodyId: bodyId);
  }

  Future<void> trackEventLike(String eventId, {required bool isLiked}) async {
    if (!isLiked) return;
    final bodyId = _eventBodyId(eventId);
    if (bodyId == null) return;
    await _postEventInteraction(endpoint: 'like', bodyId: bodyId);
  }

  Future<void> updateEvent(String eventId, PostView updatedEvent) async {
    debugPrint('updateEvent called but API update is not yet implemented.');
  }

  dynamic _eventBodyId(String eventId) {
    final idAsInt = int.tryParse(eventId);
    if (idAsInt != null) return idAsInt;
    if (eventId.trim().isEmpty) return null;
    return eventId;
  }

  void _sortEventsMostRecent(List<PostView> events) {
    DateTime resolveSortDate(PostView e) {
      if (e.eventDate != null) return e.eventDate!;

      final createdRaw = e.metadata['createdAt'];
      final createdAt = createdRaw != null
          ? DateTime.tryParse(createdRaw.toString())
          : null;
      if (createdAt != null) return createdAt;

      final eventRaw = e.metadata['eventDate'];
      final eventMetaDate = eventRaw != null
          ? DateTime.tryParse(eventRaw.toString())
          : null;
      if (eventMetaDate != null) return eventMetaDate;

      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    events.sort((a, b) => resolveSortDate(b).compareTo(resolveSortDate(a)));
  }

  void _upsertCachedEvent(PostView event) {
    if (_cachedEvents == null) {
      _cachedEvents = [event];
      return;
    }
    final idx = _cachedEvents!.indexWhere((e) => e.id == event.id);
    if (idx == -1) {
      _cachedEvents!.add(event);
    } else {
      _cachedEvents![idx] = event;
    }
    _sortEventsMostRecent(_cachedEvents!);
  }

  Future<void> _postEventInteraction({
    required String endpoint,
    required dynamic bodyId,
  }) async {
    try {
      final headers = await _authorizedHeaders(includeJsonContentType: true);
      final response = await http.post(
        Uri.parse('$_baseUrl/events/$endpoint'),
        headers: headers,
        body: jsonEncode({'id': bodyId}),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint(
          'Failed to send events/$endpoint for id=$bodyId: '
          '${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error sending events/$endpoint for id=$bodyId: $e');
    }
  }

  void clearCache() {
    // No-op for now
  }
}
