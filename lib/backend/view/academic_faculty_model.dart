class AcademicGrade {
  final String key;
  final String name;
  final int? level;

  const AcademicGrade({required this.key, required this.name, this.level});

  factory AcademicGrade.fromJson(Map<String, dynamic> json) {
    final rawLevel = json['level'];
    return AcademicGrade(
      key: (json['key'] as String? ?? '').trim(),
      name: _localizeGradeName((json['name'] as String? ?? '').trim()),
      level: rawLevel is num ? rawLevel.toInt() : int.tryParse('$rawLevel'),
    );
  }

  static String _localizeGradeName(String name) {
    return name.replaceAll(RegExp(r'\bgrade\b', caseSensitive: false), 'Sınıf');
  }
}

class AcademicDepartment {
  final String key;
  final String name;
  final List<AcademicGrade> grades;

  const AcademicDepartment({
    required this.key,
    required this.name,
    required this.grades,
  });

  factory AcademicDepartment.fromJson(Map<String, dynamic> json) {
    final rawGrades = json['grades'];
    return AcademicDepartment(
      key: (json['key'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      grades: rawGrades is List
          ? rawGrades
                .whereType<Map>()
                .map(
                  (grade) =>
                      AcademicGrade.fromJson(grade.cast<String, dynamic>()),
                )
                .where((grade) => grade.key.isNotEmpty && grade.name.isNotEmpty)
                .toList(growable: false)
          : const <AcademicGrade>[],
    );
  }
}

class AcademicFaculty {
  final String key;
  final String name;
  final List<AcademicDepartment> departments;

  const AcademicFaculty({
    required this.key,
    required this.name,
    required this.departments,
  });

  factory AcademicFaculty.fromJson(Map<String, dynamic> json) {
    final rawDepartments = json['departments'];
    return AcademicFaculty(
      key: (json['key'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      departments: rawDepartments is List
          ? rawDepartments
                .whereType<Map>()
                .map(
                  (department) => AcademicDepartment.fromJson(
                    department.cast<String, dynamic>(),
                  ),
                )
                .where(
                  (department) =>
                      department.key.isNotEmpty && department.name.isNotEmpty,
                )
                .toList(growable: false)
          : const <AcademicDepartment>[],
    );
  }
}
