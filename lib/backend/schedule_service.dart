import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/view/schedule_model.dart';
import 'package:omusiber/backend/auth/auth_service.dart';

class ScheduleService {
  // Singleton
  static final ScheduleService _instance =
      ScheduleService._privateConstructor();
  ScheduleService._privateConstructor();
  factory ScheduleService() => _instance;

  Future<List<ProgramSchedule>> fetchSchedules({
    String? departmentKey,
    int? scheduleId,
    String? programName,
    String? classKey,
    int? classIndex,
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
    _log(
      'fetchSchedules sent uri=$uri params=${queryParameters.isEmpty ? '{}' : queryParameters}',
    );

    try {
      final token = await AuthService().getIdToken();
      final hasAuthToken = token != null && token.trim().isNotEmpty;
      _log('GET $uri authPresent=$hasAuthToken');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (hasAuthToken) 'Authorization': 'Bearer $token',
        },
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
