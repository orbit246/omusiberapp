import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omusiber/backend/view/note_model.dart';
import 'package:omusiber/backend/schedule_service.dart';
import 'package:omusiber/backend/view/schedule_model.dart';

class NotesService {
  static const String _storageKey = 'local_notes';

  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

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
      final prefs = await SharedPreferences.getInstance();
      final int? progId = prefs.getInt('selected_program_id');
      final int gradeIndex = prefs.getInt('selected_grade_index') ?? 0;

      if (progId == null) return "Genel";

      // Ideally cache schedules but fetching is okay for now if not too frequent
      final schedules = await ScheduleService().fetchSchedules();

      ProgramSchedule program;
      try {
        program = schedules.firstWhere((s) => s.id == progId);
      } catch (e) {
        // Fallback if ID changed or not found
        if (schedules.isNotEmpty)
          program = schedules.first;
        else
          return "Genel";
      }

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

      Map<String, List<ScheduleLesson>> targetGrade;
      if (gradeIndex == 0) {
        targetGrade = program.grade1;
      } else {
        targetGrade = program.grade2;
      }

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
