import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/academic_faculty_model.dart';
import 'package:omusiber/backend/view/note_model.dart';
import 'package:omusiber/backend/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotesService {
  static const String _storageKey = 'local_notes';

  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

  final UserProfileService _profileService = UserProfileService();

  // Helper to generate IDs
  String get _generateId =>
      DateTime.now().millisecondsSinceEpoch.toString() +
      Random().nextInt(10000).toString();

  Future<List<Note>> getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString(_storageKey);
    if (notesJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(notesJson);
      final notes = decoded.map((e) => Note.fromJson(e)).toList();
      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return notes;
    } catch (e) {
      debugPrint("Error parsing notes: $e");
      return [];
    }
  }

  Future<void> saveNote(Note note) async {
    final notes = await getNotes();
    final index = notes.indexWhere((n) => n.id == note.id);

    if (index >= 0) {
      notes[index] = note;
    } else {
      notes.add(note);
    }

    await _saveNotesList(notes);
  }

  Future<void> deleteNote(String id) async {
    final notes = await getNotes();
    notes.removeWhere((n) => n.id == id);
    await _saveNotesList(notes);
  }

  Future<void> _saveNotesList(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(notes.map((n) => n.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  // --- Context Awareness ---

  Future<String> suggestContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return "Genel";
      }

      final profile = await _profileService.fetchUserProfile(user.uid);
      if (profile == null ||
          profile.departmentKey == null ||
          profile.gradeKey == null) {
        return "Genel";
      }

      final faculties = await _profileService.fetchAcademicFaculties();
      AcademicDepartment? selectedDepartment;
      AcademicGrade? selectedGrade;
      for (final faculty in faculties) {
        for (final department in faculty.departments) {
          if (department.key != profile.departmentKey) {
            continue;
          }
          selectedDepartment = department;
          for (final grade in department.grades) {
            if (grade.key == profile.gradeKey) {
              selectedGrade = grade;
              break;
            }
          }
          break;
        }
        if (selectedDepartment != null) {
          break;
        }
      }

      final gradeLevel = selectedGrade?.level;
      if (selectedDepartment == null || gradeLevel == null) {
        return "Genel";
      }

      final schedules = await ScheduleService().fetchSchedules(
        departmentKey: selectedDepartment.key,
      );
      if (schedules.isEmpty) {
        return "Genel";
      }

      final program = schedules.first;

      // Determine day
      final now = DateTime.now();
      final weekday = now.weekday; // 1=Mon, 7=Sun

      // Map to Turkish keys used in map
      // Note: Make sure casing matches API (usually uppercase)
      final days = [
        "PAZARTESİ",
        "SALI",
        "ÇARŞAMBA",
        "PERŞEMBE",
        "CUMA",
        "CUMARTESİ",
        "PAZAR",
      ];

      if (weekday < 1 || weekday > 7) return "Genel";
      final todayStr = days[weekday - 1];

      final targetGrade = program.gradeForLevel(gradeLevel);

      final lessons = targetGrade[todayStr];
      if (lessons == null || lessons.isEmpty) return "Genel";

      // Check time
      for (final lesson in lessons) {
        final timeParts = lesson.time.split(':');
        if (timeParts.length == 2) {
          final h = int.tryParse(timeParts[0]);
          final m = int.tryParse(timeParts[1]);

          if (h != null && m != null) {
            // Create DateTime for lesson start on *today*
            final start = DateTime(now.year, now.month, now.day, h, m);
            // Assume 50 mins duration
            final end = start.add(const Duration(minutes: 50));

            // Allow 10 min break buffer?
            // "Active class" logic: strictly during class.
            if (now.isAfter(start.subtract(const Duration(minutes: 5))) &&
                now.isBefore(end.add(const Duration(minutes: 5)))) {
              // Found matching class!
              return "Ders: ${lesson.courseName}";
            }
          }
        }
      }

      return "Genel";
    } catch (e) {
      debugPrint("Context suggestion error: $e");
      return "Genel";
    }
  }

  String createId() => _generateId;
}
