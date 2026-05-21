import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/api_identity_service.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/view/schedule_model.dart';

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
    final cachedEntry = _cacheByQuery[cacheKey];
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

      final response = await http.get(
        uri,
        headers: {...headers, 'Accept': 'application/json'},
      );
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
        _log(
          'Parsed schedules count=${schedules.length} details=${_summarizeSchedules(schedules)}',
        );
        return schedules;
      } else {
        throw Exception('Failed to load schedules: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ScheduleService ERROR] Error fetching schedules: $e');
      rethrow;
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
