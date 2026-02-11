class Lesson {
  final String day;
  final String time;
  final String code;
  final String name;
  final String lecturer;
  final String room;

  Lesson({
    required this.day,
    required this.time,
    required this.code,
    required this.name,
    required this.lecturer,
    required this.room,
  });

  @override
  String toString() {
    return '$day $time: $code - $name ($room)';
  }
}

class WeeklySchedule {
  final List<Lesson> grade1Lessons;
  final List<Lesson> grade2Lessons;

  WeeklySchedule(this.grade1Lessons, this.grade2Lessons);
}

class ScheduleParser {
  /// Parses standard raw Excel data into a WeeklySchedule object.
  /// Expects the specific format:
  /// Left columns (0-5): Day, Time, Code, Name, Lecturer, Room (Grade 1)
  /// Right columns (6-11): Day, Time, Code, Name, Lecturer, Room (Grade 2)
  static WeeklySchedule parse(List<List<dynamic>> rows) {
    List<Lesson> g1 = [];
    List<Lesson> g2 = [];

    // 1. Find the header row index (Look for "Ders Kodu")
    int headerRowIndex = -1;
    for (int i = 0; i < rows.length && i < 20; i++) {
      final row = rows[i];
      if (row.any((cell) => cell.toString().contains("Ders Kodu"))) {
        headerRowIndex = i;
        break;
      }
    }

    if (headerRowIndex == -1) return WeeklySchedule([], []);

    // 2. Iterate data rows
    // Track current day because merged cells might return null for subsequent rows
    String currentDayG1 = "";
    String currentDayG2 = "";

    // Helper to clean strings
    String clean(dynamic v) => v?.toString().trim() ?? "";

    for (int i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      // Ensure row has enough columns
      while (row.length < 12) row.add(null);

      // --- Grade 1 Parsing (Cols 0-5) ---
      String day1 = clean(row[0]);
      if (day1.isNotEmpty) currentDayG1 = day1;

      String time1 = clean(row[1]);
      String code1 = clean(row[2]);
      String name1 = clean(row[3]);
      String lecturer1 = clean(row[4]);
      String room1 = clean(row[5]);

      // Valid lesson check: needs a Name or Code.
      // Sometimes empty rows exist for formatting.
      if (name1.isNotEmpty || code1.isNotEmpty) {
        g1.add(
          Lesson(
            day: currentDayG1,
            time: time1,
            code: code1,
            name: name1,
            lecturer: lecturer1,
            room: room1,
          ),
        );
      }

      // --- Grade 2 Parsing (Cols 6-11) ---
      String day2 = clean(row[6]);
      if (day2.isNotEmpty) currentDayG2 = day2;

      String time2 = clean(row[7]);
      String code2 = clean(row[8]);
      String name2 = clean(row[9]);
      String lecturer2 = clean(row[10]);
      String room2 = clean(row[11]);

      if (name2.isNotEmpty || code2.isNotEmpty) {
        g2.add(
          Lesson(
            day: currentDayG2,
            time: time2,
            code: code2,
            name: name2,
            lecturer: lecturer2,
            room: room2,
          ),
        );
      }
    }

    return WeeklySchedule(g1, g2);
  }
}
