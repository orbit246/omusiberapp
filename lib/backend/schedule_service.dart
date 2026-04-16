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

  Future<List<ProgramSchedule>> fetchSchedules({String? departmentKey}) async {
    final normalizedDepartmentKey = departmentKey?.trim();
    final uri = Uri.parse('${Constants.baseUrl}/schedules').replace(
      queryParameters:
          normalizedDepartmentKey != null && normalizedDepartmentKey.isNotEmpty
          ? <String, String>{'departmentKey': normalizedDepartmentKey}
          : null,
    );
    try {
      final token = await AuthService().getIdToken();
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
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
