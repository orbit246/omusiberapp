import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/view/master_news_widgets_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MasterNewsWidgetsRepository {
  static final MasterNewsWidgetsRepository _instance =
      MasterNewsWidgetsRepository._internal();

  factory MasterNewsWidgetsRepository() => _instance;

  MasterNewsWidgetsRepository._internal();

  static const String _storageKey = 'cached_master_news_widgets';
  static const Duration _cacheDuration = Duration(minutes: 30);
  final Duration timeout = const Duration(seconds: 15);

  MasterNewsWidgetsView? _cachedWidgets;
  DateTime? _lastFetchTime;

  String get _baseUrl => Constants.baseUrl;
  Uri get _widgetsUri => Uri.parse('$_baseUrl/master/news-widgets');

  Future<MasterNewsWidgetsView?> getCachedWidgets() async {
    if (_cachedWidgets != null && _cachedWidgets!.sections.isNotEmpty) {
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
      return _cachedWidgets;
    } catch (e) {
      debugPrint('Failed to load master news widgets cache: $e');
      return null;
    }
  }

  Future<String> _getAuthToken() async {
    final ready = await AppStartupController.instance
        .ensureAuthenticatedSession();
    if (!ready) {
      throw StateError('Authentication is not ready yet.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Authentication failed: no Firebase user available.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication failed: empty Firebase ID token.');
    }
    return token;
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final token = await _getAuthToken();
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<MasterNewsWidgetsView?> fetchWidgets({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedWidgets != null &&
        _cachedWidgets!.sections.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _cachedWidgets;
    }

    if (!forceRefresh && (_cachedWidgets == null || _cachedWidgets!.sections.isEmpty)) {
      await getCachedWidgets();
      if (_cachedWidgets != null && _cachedWidgets!.sections.isNotEmpty) {
        return _cachedWidgets;
      }
    }

    try {
      final headers = await _authorizedHeaders();
      final response = await http.get(_widgetsUri, headers: headers).timeout(
        timeout,
      );

      if (response.statusCode != 200) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: _widgetsUri,
        );
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Master news widgets response must be a JSON object.',
        );
      }

      final widgets = MasterNewsWidgetsView.fromJson(decoded);
      _cachedWidgets = widgets;
      _lastFetchTime = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, json.encode(widgets.toJson()));

      return widgets;
    } catch (e) {
      if (e is StateError) {
        rethrow;
      }

      debugPrint('Failed to fetch master news widgets: $e');
      return _cachedWidgets ?? await getCachedWidgets();
    }
  }
}
