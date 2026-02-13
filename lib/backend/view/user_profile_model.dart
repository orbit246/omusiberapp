import 'package:omusiber/models/user_badge.dart';

class UserProfile {
  final String uid;
  final String studentId;
  final String? email;
  final String name;
  final String? photoUrl;
  final String role;
  final List<UserBadge> badges;
  final bool isPrivate;
  // Extended fields
  final String? gender;
  final int? age;
  final String? department;
  final String? campus;

  UserProfile({
    required this.uid,
    required this.studentId,
    this.email,
    required this.name,
    this.photoUrl,
    required this.role,
    this.badges = const [],
    this.isPrivate = false,
    this.gender,
    this.age,
    this.department,
    this.campus,
  });

  factory UserProfile.fromFirestore(
    Map<String, dynamic> data,
    String uid, {
    List<UserBadge> badges = const [],
  }) {
    return UserProfile(
      uid: uid,
      studentId: data['studentId'] ?? '',
      email: data['email'],
      name: data['name'] ?? 'Kullanıcı',
      photoUrl: data['photoUrl'],
      role: data['role'] ?? 'student',
      badges: badges,
      isPrivate: data['isPrivate'] ?? false,
      gender: data['gender'],
      age: data['age'],
      department: data['department'],
      campus: data['campus'],
    );
  }
}
