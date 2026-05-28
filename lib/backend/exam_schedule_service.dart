import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

enum ExamDeliveryType { standard, online, campus }

class ExamEntry {
  const ExamEntry({
    required this.sectionTitle,
    required this.programName,
    required this.year,
    required this.courseCode,
    required this.courseName,
    required this.examDate,
    required this.rawDate,
    required this.rawHour,
    required this.classroom,
    required this.studentCount,
    required this.lecturerName,
    required this.deliveryType,
  });

  final String sectionTitle;
  final String programName;
  final int year;
  final String courseCode;
  final String courseName;
  final DateTime? examDate;
  final String rawDate;
  final String rawHour;
  final String classroom;
  final int? studentCount;
  final String lecturerName;
  final ExamDeliveryType deliveryType;

  bool get isOnline => deliveryType == ExamDeliveryType.online;
  bool get isCampus => deliveryType == ExamDeliveryType.campus;

  String get displayLocation {
    if (isOnline) {
      return '';
    }
    if (isCampus) {
      return 'EĞİTİM FAKÜLTESİ B-BLOK DERSLİKLERİ';
    }
    return classroom;
  }

  String get onlineNotice =>
      'sinav.omu.edu.tr üzerinden sınav giriş bilgilerini,sınav tarihi ve saatini kontrol ediniz.';
}

class ExamScheduleService {
  static const String _assetPath = 'assets/exams.txt';

  Future<List<ExamEntry>> loadExams() async {
    final content = await rootBundle.loadString(_assetPath);
    return _ExamScheduleParser(content).parse();
  }
}

class _ExamScheduleParser {
  _ExamScheduleParser(this.content);

  final String content;

  String? _currentSectionTitle;
  String? _currentProgramName;
  int? _currentYear;
  ExamDeliveryType _currentMode = ExamDeliveryType.standard;
  String _modeDate = '';
  String _modeHour = '';
  String _modeClassroom = '';
  String _modeLecturer = '';

  List<ExamEntry> parse() {
    final exams = <ExamEntry>[];

    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      if (_isModeHeader(line, 'online')) {
        _currentMode = ExamDeliveryType.online;
        _resetModeDefaults();
        continue;
      }

      if (_isModeHeader(line, 'campus')) {
        _currentMode = ExamDeliveryType.campus;
        _resetModeDefaults();
        continue;
      }

      final section = _parseSectionHeader(line);
      if (section != null) {
        _currentSectionTitle = section.sectionTitle;
        _currentProgramName = section.programName;
        _currentYear = section.year;
        _currentMode = ExamDeliveryType.standard;
        _resetModeDefaults();
        continue;
      }

      if (_currentSectionTitle == null ||
          _currentProgramName == null ||
          _currentYear == null) {
        continue;
      }

      final exam = _parseExamLine(rawLine);
      if (exam != null) {
        exams.add(exam);
      }
    }

    exams.sort(_compareExams);
    return exams;
  }

  void _resetModeDefaults() {
    _modeDate = '';
    _modeHour = '';
    _modeClassroom = '';
    _modeLecturer = '';
  }

  bool _isModeHeader(String line, String label) {
    final normalized = line.toLowerCase().replaceAll(' ', '');
    return normalized == '$label:' || normalized == label;
  }

  _ExamSectionHeader? _parseSectionHeader(String line) {
    if (line.contains('\t')) {
      return null;
    }

    final match = RegExp(r'^(.*?)(?:\s*-\s*(\d+))?:?$').firstMatch(line);
    if (match == null) {
      return null;
    }

    final programName = (match.group(1) ?? '').trim();
    final rawYear = (match.group(2) ?? '').trim();
    if (programName.isEmpty || rawYear.isEmpty) {
      return null;
    }

    final year = int.tryParse(rawYear);
    if (year == null) {
      return null;
    }

    return _ExamSectionHeader(
      sectionTitle: line.replaceFirst(RegExp(r':$'), '').trim(),
      programName: programName,
      year: year,
    );
  }

  ExamEntry? _parseExamLine(String rawLine) {
    final fields = rawLine.split('\t').map((item) => item.trim()).toList();
    if (fields.every((item) => item.isEmpty)) {
      return null;
    }

    final hasCourseCode = _looksLikeCourseCode(_fieldAt(fields, 0)) &&
        !_looksLikeDate(_fieldAt(fields, 1));
    final nameIndex = hasCourseCode ? 1 : 0;
    final dateIndex = hasCourseCode ? 2 : 1;
    final hourIndex = hasCourseCode ? 3 : 2;
    final classroomIndex = hasCourseCode ? 4 : 3;
    final studentCountIndex = hasCourseCode ? 5 : 4;
    final lecturerIndex = hasCourseCode ? 6 : 5;

    final courseName = _fieldAt(fields, nameIndex);
    if (courseName.isEmpty) {
      return null;
    }

    var rawDate = _fieldAt(fields, dateIndex);
    var rawHour = _normalizeHour(_fieldAt(fields, hourIndex));
    var classroom = _fieldAt(fields, classroomIndex);
    var lecturerName = _fieldAt(fields, lecturerIndex);

    if (_currentMode != ExamDeliveryType.standard) {
      if (rawDate.isEmpty) rawDate = _modeDate;
      if (rawHour.isEmpty) rawHour = _modeHour;
      if (classroom.isEmpty) classroom = _modeClassroom;
      if (lecturerName.isEmpty) lecturerName = _modeLecturer;

      if (rawDate.isNotEmpty) _modeDate = rawDate;
      if (rawHour.isNotEmpty) _modeHour = rawHour;
      if (classroom.isNotEmpty) _modeClassroom = classroom;
      if (lecturerName.isNotEmpty) _modeLecturer = lecturerName;
    }

    return ExamEntry(
      sectionTitle: _currentSectionTitle!,
      programName: _currentProgramName!,
      year: _currentYear!,
      courseCode: hasCourseCode ? _fieldAt(fields, 0) : '',
      courseName: courseName,
      examDate: _parseDate(rawDate, rawHour),
      rawDate: rawDate,
      rawHour: rawHour,
      classroom: classroom,
      studentCount: int.tryParse(_fieldAt(fields, studentCountIndex)),
      lecturerName: lecturerName,
      deliveryType: _currentMode,
    );
  }

  String _fieldAt(List<String> fields, int index) {
    if (index < 0 || index >= fields.length) {
      return '';
    }
    return fields[index].trim();
  }

  bool _looksLikeCourseCode(String value) {
    if (value.isEmpty || value.contains(' ')) {
      return false;
    }
    return RegExp(r'\d').hasMatch(value);
  }

  bool _looksLikeDate(String value) {
    return RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(value.trim());
  }

  String _normalizeHour(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAll('.', ':');
  }

  DateTime? _parseDate(String rawDate, String rawHour) {
    if (rawDate.isEmpty) {
      return null;
    }

    final dateParts = rawDate.split('/');
    if (dateParts.length != 3) {
      return null;
    }

    final month = int.tryParse(dateParts[0]);
    final day = int.tryParse(dateParts[1]);
    final year = int.tryParse(dateParts[2]);
    if (month == null || day == null || year == null) {
      return null;
    }

    var hour = 0;
    var minute = 0;
    if (rawHour.isNotEmpty) {
      final timeParts = rawHour.split(':');
      if (timeParts.length == 2) {
        hour = int.tryParse(timeParts[0]) ?? 0;
        minute = int.tryParse(timeParts[1]) ?? 0;
      }
    }

    return DateTime(year, month, day, hour, minute);
  }

  int _compareExams(ExamEntry a, ExamEntry b) {
    final aDate = a.examDate;
    final bDate = b.examDate;

    if (aDate != null && bDate != null) {
      final byDate = aDate.compareTo(bDate);
      if (byDate != 0) {
        return byDate;
      }
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }

    final byProgram = a.programName.toLowerCase().compareTo(
      b.programName.toLowerCase(),
    );
    if (byProgram != 0) {
      return byProgram;
    }

    return a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase());
  }
}

class _ExamSectionHeader {
  const _ExamSectionHeader({
    required this.sectionTitle,
    required this.programName,
    required this.year,
  });

  final String sectionTitle;
  final String programName;
  final int year;
}
