import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/cache_compare.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/view/master_news_widgets_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MasterNewsWidgetsRepository {
  static final MasterNewsWidgetsRepository _instance =
      MasterNewsWidgetsRepository._internal();

  factory MasterNewsWidgetsRepository() => _instance;

  MasterNewsWidgetsRepository._internal();

  static const String _storageKey = 'cached_master_news_widgets_v2';
  static const Duration _cacheDuration = Duration(minutes: 30);
  final Duration timeout = const Duration(seconds: 15);

  MasterNewsWidgetsView? _cachedWidgets;
  DateTime? _lastFetchTime;

  String get _baseUrl => Constants.baseUrl;
  Uri get _widgetsUri => Uri.parse('$_baseUrl/master/news-widgets');

  Future<MasterNewsWidgetsView?> getCachedWidgets() async {
    if (_cachedWidgets != null && _cachedWidgets!.sections.isNotEmpty) {
      _log(
        'Returning in-memory cache with ${_cachedWidgets!.sections.length} sections.',
      );
      return _cachedWidgets;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }

      final decoded = json.decode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      _cachedWidgets = MasterNewsWidgetsView.fromJson(decoded);
      _log(
        'Loaded persisted cache with ${_cachedWidgets!.sections.length} sections.',
      );
      return _cachedWidgets;
    } catch (e) {
      debugPrint('Failed to load master news widgets cache: $e');
      return null;
    }
  }

  Map<String, String> get _baseHeaders => const {'Accept': 'application/json'};

  Future<String> _getAuthToken({bool forceRefresh = false}) async {
    final ready = await AppStartupController.instance
        .ensureAuthenticatedSession();
    if (!ready) {
      throw StateError('Authentication is not ready yet.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Authentication failed: no Firebase user available.');
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw Exception('Authentication failed: empty Firebase ID token.');
    }
    return token;
  }

  Future<Map<String, String>> _authorizedHeaders({
    bool forceRefreshToken = false,
  }) async {
    final token = await _getAuthToken(forceRefresh: forceRefreshToken);
    return {..._baseHeaders, 'Authorization': 'Bearer $token'};
  }

  Future<http.Response> _getWidgetsResponse() async {
    var headers = await _authorizedHeaders();
    _log(
      'GET $_widgetsUri authPresent=${headers['Authorization']?.isNotEmpty == true}',
    );

    var response = await http
        .get(_widgetsUri, headers: headers)
        .timeout(timeout);

    if (response.statusCode != 401) {
      return response;
    }

    _log(
      'Authorized request returned 401; retrying with refreshed Firebase ID token.',
    );
    headers = await _authorizedHeaders(forceRefreshToken: true);
    return http.get(_widgetsUri, headers: headers).timeout(timeout);
  }

  Future<MasterNewsWidgetsView?> fetchWidgets({
    bool forceRefresh = false,
    bool fallbackToCacheOnError = true,
  }) async {
    _log(
      'fetchWidgets(forceRefresh: $forceRefresh) cacheSections=${_cachedWidgets?.sections.length ?? 0} lastFetch=$_lastFetchTime',
    );
    if (!forceRefresh &&
        _cachedWidgets != null &&
        _cachedWidgets!.sections.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      _log('Using warm memory cache.');
      return _cachedWidgets;
    }

    if (!forceRefresh &&
        (_cachedWidgets == null || _cachedWidgets!.sections.isEmpty)) {
      await getCachedWidgets();
      if (_cachedWidgets != null && _cachedWidgets!.sections.isNotEmpty) {
        _log('Using persisted cache after cache lookup.');
        return _cachedWidgets;
      }
    }

    try {
      final response = await _getWidgetsResponse();
      _log(
        'Response status=${response.statusCode} body=${_truncate(response.body)}',
      );

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: _widgetsUri);
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Master news widgets response must be a JSON object.',
        );
      }
      _log('Decoded payload keys=${decoded.keys.join(', ')}');

      final widgets = MasterNewsWidgetsView.fromJson(decoded);
      _log(
        'Parsed sections=${widgets.sections.length} details=${widgets.sections.map((s) => '${s.id}:${s.cards.length}').join(', ')}',
      );
      if (!jsonPayloadEquals(_cachedWidgets?.toJson(), widgets.toJson())) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, json.encode(widgets.toJson()));
      }
      _cachedWidgets = widgets;
      _lastFetchTime = DateTime.now();

      return widgets;
    } catch (e) {
      if (e is StateError) {
        rethrow;
      }

      debugPrint('Failed to fetch master news widgets: $e');
      if (!fallbackToCacheOnError) {
        rethrow;
      }
      _log('Falling back to cached widgets after failure.');
      return _cachedWidgets ?? await getCachedWidgets();
    }
  }

  void _log(String message) {
    debugPrint('[MasterNewsWidgetsRepository] $message');
  }

  String _truncate(String value, {int max = 500}) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= max) {
      return compact;
    }
    return '${compact.substring(0, max)}...';
  }
}
