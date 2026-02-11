class ProgramSchedule {
  final int id;
  final String programName;
  final String academicYear;
  final String semester;
  final Map<String, List<ScheduleLesson>> grade1;
  final Map<String, List<ScheduleLesson>> grade2;
  final String updatedAt;

  ProgramSchedule({
    required this.id,
    required this.programName,
    required this.academicYear,
    required this.semester,
    required this.grade1,
    required this.grade2,
    required this.updatedAt,
  });

  factory ProgramSchedule.fromJson(Map<String, dynamic> json) {
    var scheduleData = json['schedule'] ?? {};

    // Handle nested structure (e.g. schedule['SheetName']['grade1'])
    if (scheduleData is Map && !scheduleData.containsKey('grade1')) {
      for (var value in scheduleData.values) {
        if (value is Map && value.containsKey('grade1')) {
          scheduleData = value;
          break;
        }
      }
    }

    // Helper to parse day map
    Map<String, List<ScheduleLesson>> parseGrade(dynamic gradeData) {
      if (gradeData == null) return {};
      final map = <String, List<ScheduleLesson>>{};
      if (gradeData is Map) {
        gradeData.forEach((day, lessons) {
          if (lessons is List) {
            final parsedLessons = lessons
                .map((l) => ScheduleLesson.fromJson(l))
                // Filter out invalid/empty lessons
                .where((l) => l.courseName.isNotEmpty && l.time.isNotEmpty)
                .toList();

            if (parsedLessons.isNotEmpty) {
              map[day.toString()] = parsedLessons;
            }
          }
        });
      }
      return map;
    }

    return ProgramSchedule(
      id: json['id'] ?? 0,
      programName: json['programName'] ?? '',
      academicYear: json['academicYear'] ?? '',
      semester: json['semester'] ?? '',
      grade1: parseGrade(scheduleData['grade1']),
      grade2: parseGrade(scheduleData['grade2']),
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}

class ScheduleLesson {
  final String time;
  final String courseCode;
  final String courseName;
  final String instructor;
  final String classroom;

  ScheduleLesson({
    required this.time,
    required this.courseCode,
    required this.courseName,
    required this.instructor,
    required this.classroom,
  });

  factory ScheduleLesson.fromJson(Map<String, dynamic> json) {
    String rawTime = (json['time'] ?? '').toString();
    String rawCode = (json['courseCode'] ?? '').toString();
    String rawName = (json['courseName'] ?? '').toString();
    String rawInst = (json['instructor'] ?? '').toString();
    String rawRoom = (json['classroom'] ?? '').toString();

    // HEURISTIC: Check for shifted data
    // If 'time' is NOT a number but 'courseCode' IS a number (fraction), assume shift.
    // Example: time="PAZARTESİ", code="0.45", name="Code", inst="Name"
    if (double.tryParse(rawTime) == null) {
      if (double.tryParse(rawCode) != null) {
        // Shift values
        rawTime = rawCode;
        rawCode = rawName; // BGP226
        rawName = rawInst; // Bilgisayar Ağlarının...
        rawInst = rawRoom; // Öğr. Gör...
        rawRoom = ''; // Lost/Empty
      }
    }

    // Parse Excel fraction time (0.xxx)
    final double? dayFraction = double.tryParse(rawTime);
    if (dayFraction != null && dayFraction < 1.0 && dayFraction > 0.0) {
      final int totalMinutes = (dayFraction * 24 * 60).round();
      final int hour = totalMinutes ~/ 60;
      final int minute = totalMinutes % 60;
      rawTime =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }

    // If time is still invalid/text (like "PAZARTESİ"), it will be filtered out by logic in ProgramSchedule in parseGrade

    return ScheduleLesson(
      time: rawTime,
      courseCode: rawCode,
      courseName: rawName,
      instructor: rawInst,
      classroom: rawRoom,
    );
  }
}
