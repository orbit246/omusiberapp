class ProgramSchedule {
  final int id;
  final String programName;
  final String academicYear;
  final String semester;
  final Map<String, Map<String, List<ScheduleLesson>>> classesByKey;
  final String updatedAt;
  final List<String> availableClassKeys;
  final List<String> registeredClassKeys;
  final bool manualOverrideEnabled;
  final String effectiveSource;
  final ScheduleAcademicContext? academicContext;

  ProgramSchedule({
    required this.id,
    required this.programName,
    required this.academicYear,
    required this.semester,
    required this.classesByKey,
    required this.updatedAt,
    this.availableClassKeys = const <String>[],
    this.registeredClassKeys = const <String>[],
    this.manualOverrideEnabled = false,
    this.effectiveSource = '',
    this.academicContext,
  });

  factory ProgramSchedule.fromJson(Map<String, dynamic> json) {
    dynamic scheduleData = json['schedule'] ?? const <String, dynamic>{};

    if (scheduleData is Map &&
        !scheduleData.keys.any((key) => _looksLikeClassSchedule(value: key))) {
      for (final value in scheduleData.values) {
        if (value is Map &&
            value.keys.any((key) => _looksLikeClassSchedule(value: key))) {
          scheduleData = value;
          break;
        }
      }
    }

    final classesByKey = <String, Map<String, List<ScheduleLesson>>>{};
    if (scheduleData is Map) {
      for (final entry in scheduleData.entries) {
        final classKey = entry.key.toString().trim();
        if (classKey.isEmpty) {
          continue;
        }

        final parsedGrade = _parseClassSchedule(entry.value);
        if (parsedGrade.isNotEmpty) {
          classesByKey[classKey] = parsedGrade;
        }
      }
    }

    return ProgramSchedule(
      id: json['id'] ?? 0,
      programName: json['programName'] ?? '',
      academicYear: json['academicYear'] ?? '',
      semester: json['semester'] ?? '',
      classesByKey: classesByKey,
      updatedAt: json['updatedAt'] ?? '',
      availableClassKeys: _parseStringList(json['availableClassKeys']),
      registeredClassKeys: _parseStringList(json['registeredClassKeys']),
      manualOverrideEnabled: json['manualOverrideEnabled'] == true,
      effectiveSource: (json['effectiveSource'] ?? '').toString().trim(),
      academicContext: _parseAcademicContext(json['academicContext']),
    );
  }

  static bool _looksLikeClassSchedule({required Object? value}) {
    final key = value?.toString().trim().toLowerCase() ?? '';
    if (key.isEmpty) {
      return false;
    }
    return key.startsWith('grade') || key.contains('-grade');
  }

  static Map<String, List<ScheduleLesson>> _parseClassSchedule(
    dynamic gradeData,
  ) {
    if (gradeData == null) {
      return const <String, List<ScheduleLesson>>{};
    }

    final map = <String, List<ScheduleLesson>>{};
    if (gradeData is Map) {
      gradeData.forEach((day, lessons) {
        if (lessons is List) {
          final parsedLessons = lessons
              .whereType<Map>()
              .map(
                (lesson) =>
                    ScheduleLesson.fromJson(lesson.cast<String, dynamic>()),
              )
              .where(
                (lesson) =>
                    lesson.courseName.isNotEmpty && lesson.time.isNotEmpty,
              )
              .toList(growable: false);
          map[day.toString()] = parsedLessons;
        }
      });
    }
    return map;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static ScheduleAcademicContext? _parseAcademicContext(dynamic value) {
    if (value is Map<String, dynamic>) {
      return ScheduleAcademicContext.fromJson(value);
    }
    if (value is Map) {
      return ScheduleAcademicContext.fromJson(value.cast<String, dynamic>());
    }
    return null;
  }

  List<String> get preferredClassKeys {
    final preferred = <String>[];
    for (final key in registeredClassKeys) {
      if (!preferred.contains(key)) {
        preferred.add(key);
      }
    }
    for (final key in availableClassKeys) {
      if (!preferred.contains(key)) {
        preferred.add(key);
      }
    }
    for (final key in classesByKey.keys) {
      if (!preferred.contains(key)) {
        preferred.add(key);
      }
    }
    return List<String>.unmodifiable(preferred);
  }

  bool hasClassKey(String classKey) => classesByKey.containsKey(classKey);

  Map<String, List<ScheduleLesson>> scheduleForClassKey(String classKey) {
    return classesByKey[classKey] ?? const <String, List<ScheduleLesson>>{};
  }

  Map<String, List<ScheduleLesson>> gradeForLevel(int level) {
    return scheduleForClassKey('grade$level');
  }
}

class ScheduleAcademicContext {
  final int? scheduleId;
  final String? programName;
  final String? classKey;
  final int? selectedClassIndex;
  final List<String> availableClassKeys;
  final int? inferredGrade;
  final String? matchedBy;
  final bool isSeededFallback;
  final bool isRandomFallback;
  final ScheduleContextNode? faculty;
  final ScheduleContextNode? department;
  final ScheduleGradeNode? grade;

  const ScheduleAcademicContext({
    this.scheduleId,
    this.programName,
    this.classKey,
    this.selectedClassIndex,
    this.availableClassKeys = const <String>[],
    this.inferredGrade,
    this.matchedBy,
    this.isSeededFallback = false,
    this.isRandomFallback = false,
    this.faculty,
    this.department,
    this.grade,
  });

  factory ScheduleAcademicContext.fromJson(Map<String, dynamic> json) {
    return ScheduleAcademicContext(
      scheduleId: _asInt(json['scheduleId']),
      programName: _asTrimmedString(json['programName']),
      classKey: _asTrimmedString(json['classKey']),
      selectedClassIndex: _asInt(json['selectedClassIndex']),
      availableClassKeys: ProgramSchedule._parseStringList(
        json['availableClassKeys'],
      ),
      inferredGrade: _asInt(json['inferredGrade']),
      matchedBy: _asTrimmedString(json['matchedBy']),
      isSeededFallback: json['isSeededFallback'] == true,
      isRandomFallback: json['isRandomFallback'] == true,
      faculty: ScheduleContextNode.maybeFromJson(json['faculty']),
      department: ScheduleContextNode.maybeFromJson(json['department']),
      grade: ScheduleGradeNode.maybeFromJson(json['grade']),
    );
  }

  bool get hasScheduleMatch => scheduleId != null;
  bool get isInferredFallback => isSeededFallback || isRandomFallback;
}

class ScheduleContextNode {
  final String key;
  final String name;

  const ScheduleContextNode({required this.key, required this.name});

  factory ScheduleContextNode.fromJson(Map<String, dynamic> json) {
    return ScheduleContextNode(
      key: _asTrimmedString(json['key']) ?? '',
      name: _asTrimmedString(json['name']) ?? '',
    );
  }

  static ScheduleContextNode? maybeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      final node = ScheduleContextNode.fromJson(value);
      return node.key.isNotEmpty || node.name.isNotEmpty ? node : null;
    }
    if (value is Map) {
      final node = ScheduleContextNode.fromJson(value.cast<String, dynamic>());
      return node.key.isNotEmpty || node.name.isNotEmpty ? node : null;
    }
    return null;
  }
}

class ScheduleGradeNode extends ScheduleContextNode {
  final int? level;

  const ScheduleGradeNode({
    required super.key,
    required super.name,
    this.level,
  });

  factory ScheduleGradeNode.fromJson(Map<String, dynamic> json) {
    return ScheduleGradeNode(
      key: _asTrimmedString(json['key']) ?? '',
      name: _asTrimmedString(json['name']) ?? '',
      level: _asInt(json['level']),
    );
  }

  static ScheduleGradeNode? maybeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      final node = ScheduleGradeNode.fromJson(value);
      return node.key.isNotEmpty || node.name.isNotEmpty || node.level != null
          ? node
          : null;
    }
    if (value is Map) {
      final node = ScheduleGradeNode.fromJson(value.cast<String, dynamic>());
      return node.key.isNotEmpty || node.name.isNotEmpty || node.level != null
          ? node
          : null;
    }
    return null;
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

    if (double.tryParse(rawTime) == null && double.tryParse(rawCode) != null) {
      rawTime = rawCode;
      rawCode = rawName;
      rawName = rawInst;
      rawInst = rawRoom;
      rawRoom = '';
    }

    final dayFraction = double.tryParse(rawTime);
    if (dayFraction != null && dayFraction < 1.0 && dayFraction > 0.0) {
      final totalMinutes = (dayFraction * 24 * 60).round();
      final hour = totalMinutes ~/ 60;
      final minute = totalMinutes % 60;
      rawTime =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }

    return ScheduleLesson(
      time: rawTime,
      courseCode: rawCode,
      courseName: rawName,
      instructor: rawInst,
      classroom: rawRoom,
    );
  }
}

String? _asTrimmedString(dynamic value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _asInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}');
}
