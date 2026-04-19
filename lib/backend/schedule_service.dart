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
    try {
      final token = await AuthService().getIdToken();
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.trim().isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ProgramSchedule.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load schedules: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching schedules: $e');
      rethrow;
    }
  }
}
