import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/api_identity_service.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/view/schedule_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScheduleCacheEntry {
  const _ScheduleCacheEntry({required this.cachedAt, required this.schedules});

  final DateTime cachedAt;
  final List<ProgramSchedule> schedules;
}

class ScheduleService {
  // Singleton
  static final ScheduleService _instance =
      ScheduleService._privateConstructor();
  ScheduleService._privateConstructor();
  factory ScheduleService() => _instance;

  static const Duration _cacheDuration = Duration(minutes: 10);
  static const String _persistentCachePrefix = 'cached_schedules_v1_';
  static const String _latestPersistentCacheKey = 'cached_schedules_latest_v1';
  final Map<String, _ScheduleCacheEntry> _cacheByQuery =
      <String, _ScheduleCacheEntry>{};

  Future<List<ProgramSchedule>> fetchSchedules({
    String? departmentKey,
    int? scheduleId,
    String? programName,
    String? classKey,
    int? classIndex,
    bool forceRefresh = false,
  }) async {
    final queryParameters = <String, String>{};
    final normalizedDepartmentKey = departmentKey?.trim();
    final normalizedProgramName = programName?.trim();
    final normalizedClassKey = classKey?.trim();

    if (normalizedDepartmentKey != null && normalizedDepartmentKey.isNotEmpty) {
      queryParameters['departmentKey'] = normalizedDepartmentKey;
    }
    if (scheduleId != null) {
      queryParameters['scheduleId'] = '$scheduleId';
    }
    if (normalizedProgramName != null && normalizedProgramName.isNotEmpty) {
      queryParameters['programName'] = normalizedProgramName;
    }
    if (normalizedClassKey != null && normalizedClassKey.isNotEmpty) {
      queryParameters['classKey'] = normalizedClassKey;
    }
    if (classIndex != null) {
      queryParameters['classIndex'] = '$classIndex';
    }

    final uri = Uri.parse('${Constants.baseUrl}/schedules').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final cacheKey = uri.toString();
    var cachedEntry = _cacheByQuery[cacheKey];
    cachedEntry ??= await _loadPersistentCache(cacheKey);
    if (!forceRefresh &&
        cachedEntry != null &&
        DateTime.now().difference(cachedEntry.cachedAt) < _cacheDuration) {
      _log('Returning cached schedules for $cacheKey');
      return cachedEntry.schedules;
    }

    _log(
      'fetchSchedules sent uri=$uri params=${queryParameters.isEmpty ? '{}' : queryParameters}',
    );

    try {
      final headers = await ApiIdentityService.instance.buildHeaders(
        includeJsonContentType: true,
      );
      final hasAuthToken = headers['Authorization']?.trim().isNotEmpty == true;
      _log('GET $uri authPresent=$hasAuthToken');

      final response = await http
          .get(uri, headers: {...headers, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      _log(
        'Response status=${response.statusCode} body=${_truncate(response.body)}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _log('Decoded schedule payload items=${data.length}');

        final schedules = data
            .map((json) => ProgramSchedule.fromJson(json))
            .toList();
        _cacheByQuery[cacheKey] = _ScheduleCacheEntry(
          cachedAt: DateTime.now(),
          schedules: List<ProgramSchedule>.unmodifiable(schedules),
        );
        await _savePersistentCache(cacheKey, data);
        _log(
          'Parsed schedules count=${schedules.length} details=${_summarizeSchedules(schedules)}',
        );
        return schedules;
      } else {
        throw Exception('Failed to load schedules: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ScheduleService ERROR] Error fetching schedules: $e');
      if (cachedEntry != null && cachedEntry.schedules.isNotEmpty) {
        _log(
          'Returning persistent schedules after network failure for $cacheKey',
        );
        return cachedEntry.schedules;
      }
      rethrow;
    }
  }

  String _persistentKey(String cacheKey) {
    final encoded = base64UrlEncode(utf8.encode(cacheKey));
    return '$_persistentCachePrefix$encoded';
  }

  Future<_ScheduleCacheEntry?> _loadPersistentCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_persistentKey(cacheKey));
      raw ??= prefs.getString(_latestPersistentCacheKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['data'] is! List) {
        return null;
      }

      final schedules = (decoded['data'] as List)
          .whereType<Map>()
          .map((item) => ProgramSchedule.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
      final entry = _ScheduleCacheEntry(
        cachedAt:
            DateTime.tryParse(decoded['cachedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        schedules: List<ProgramSchedule>.unmodifiable(schedules),
      );
      _cacheByQuery[cacheKey] = entry;
      return entry;
    } catch (e) {
      debugPrint('[ScheduleService] Failed to load persistent cache: $e');
      return null;
    }
  }

  Future<void> _savePersistentCache(String cacheKey, List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'cachedAt': DateTime.now().toIso8601String(),
        'data': data,
      });
      await prefs.setString(_persistentKey(cacheKey), payload);
      await prefs.setString(_latestPersistentCacheKey, payload);
    } catch (e) {
      debugPrint('[ScheduleService] Failed to save persistent cache: $e');
    }
  }

  void _log(String message) {
    debugPrint('[ScheduleService] $message');
  }

  String _truncate(String value, {int max = 1000}) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= max) {
      return compact;
    }
    return '${compact.substring(0, max)}...';
  }

  String _summarizeSchedules(List<ProgramSchedule> schedules) {
    if (schedules.isEmpty) {
      return 'none';
    }

    return schedules
        .take(10)
        .map((schedule) {
          final classKeys = schedule.classesByKey.keys.join('|');
          return 'id=${schedule.id}, program="${schedule.programName}", classes=[$classKeys]';
        })
        .join('; ');
  }
}
