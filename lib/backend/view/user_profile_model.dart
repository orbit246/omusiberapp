import 'package:omusiber/models/user_badge.dart';

class UserProfile {
  final String uid;
  final String? studentId;
  final String? email;
  final String name;
  final String? photoUrl;
  final String role;
  final List<UserBadge> badges;
  final bool isPrivate;
  // Extended fields
  final String? gender;
  final int? age;
  final String? facultyKey;
  final String? facultyName;
  final String? departmentKey;
  final String? department;
  final String? gradeKey;
  final String? gradeName;
  final String? campus;

  UserProfile({
    required this.uid,
    this.studentId,
    this.email,
    required this.name,
    this.photoUrl,
    required this.role,
    this.badges = const [],
    this.isPrivate = false,
    this.gender,
    this.age,
    this.facultyKey,
    this.facultyName,
    this.departmentKey,
    this.department,
    this.gradeKey,
    this.gradeName,
    this.campus,
  });

  factory UserProfile.fromFirestore(
    Map<String, dynamic> data,
    String uid, {
    List<UserBadge> badges = const [],
  }) {
    String? readTrimmed(dynamic value) {
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return UserProfile(
      uid: uid,
      studentId: readTrimmed(data['studentId']),
      email: readTrimmed(data['email']),
      name: data['name'] ?? 'Kullanıcı',
      photoUrl: readTrimmed(data['photoUrl']),
      role: data['role'] ?? 'member',
      badges: badges,
      isPrivate: data['isPrivate'] ?? false,
      gender: readTrimmed(data['gender']),
      age: data['age'],
      facultyKey: readTrimmed(data['facultyKey']),
      facultyName:
          readTrimmed(data['facultyName']) ?? readTrimmed(data['faculty']),
      departmentKey: readTrimmed(data['departmentKey']),
      department:
          readTrimmed(data['departmentName']) ??
          readTrimmed(data['department']),
      gradeKey: readTrimmed(data['gradeKey']),
      gradeName: readTrimmed(data['gradeName']) ?? readTrimmed(data['grade']),
      campus: readTrimmed(data['campus']),
    );
  }
}
