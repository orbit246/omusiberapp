import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/constants.dart';
import 'package:omusiber/backend/view/academic_faculty_model.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';
import 'package:omusiber/models/user_badge.dart';

class UserProfileService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  static List<AcademicFaculty>? _facultyCache;
  static final Map<String, List<AcademicDepartment>> _departmentCache =
      <String, List<AcademicDepartment>>{};
  static final Map<String, List<AcademicGrade>> _gradeCache =
      <String, List<AcademicGrade>>{};

  static void clearCaches() {
    _facultyCache = null;
    _departmentCache.clear();
    _gradeCache.clear();
  }

  Exception _buildApiException(String fallbackMessage, String responseBody) {
    try {
      final decoded = json.decode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return Exception(message.trim());
        }
      }
      if (decoded is String && decoded.trim().isNotEmpty) {
        return Exception(decoded.trim());
      }
    } catch (_) {
      final trimmed = responseBody.trim();
      if (trimmed.isNotEmpty) {
        return Exception(trimmed);
      }
    }

    return Exception(fallbackMessage);
  }

  /// Helper to get headers with Firebase ID token
  Future<Map<String, String>> _getHeaders() async {
    await AppStartupController.instance.ensureAuthenticatedSession();
    final token = await _auth.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch user badges from the backend API
  Future<List<UserBadge>> fetchUserBadges(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('${Constants.baseUrl}/users/$userId/badges'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> badgeStrings = data['badges'] ?? [];
        return UserBadge.fromStringList(badgeStrings.cast<String>());
      }
      return [];
    } catch (e) {
      print('Error fetching badges: $e');
      return [];
    }
  }

  /// Search for a user by their school ID
  Future<UserProfile?> searchUserByStudentId(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Constants.baseUrl}/users/search?studentId=${studentId.trim()}',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final badges = await fetchUserBadges(data['uid']);
        return UserProfile.fromFirestore(data, data['uid'], badges: badges);
      }
      return null;
    } catch (e) {
      print('Error searching user: $e');
      return null;
    }
  }

  /// Update user privacy setting
  Future<void> updatePrivacySetting(String uid, bool isPrivate) async {
    try {
      final response = await http.patch(
        Uri.parse('${Constants.baseUrl}/users/profile'),
        headers: await _getHeaders(),
        body: json.encode({'isPrivate': isPrivate}),
      );

      if (response.statusCode != 200) {
        throw _buildApiException(
          'Failed to update privacy setting.',
          response.body,
        );
      }
    } catch (e) {
      print('Error updating privacy setting: $e');
      rethrow;
    }
  }

  /// Migrate profile info from an old UID to a new UID
  /// Should be called while authenticated as the NEW user.
  Future<void> migrateProfile(
    String oldUid,
    String newUid,
    UserProfile sourceProfile,
  ) async {
    try {
      final updates = {
        'name': sourceProfile.name,
        'age': sourceProfile.age,
        'facultyKey': sourceProfile.facultyKey,
        'departmentKey': sourceProfile.departmentKey,
        'gradeKey': sourceProfile.gradeKey,
        'gender': sourceProfile.gender,
        'campus': sourceProfile.campus,
        'isPrivate': sourceProfile.isPrivate,
      };

      await updateUserProfile(
        newUid,
        updates,
      ); // Wait, this uses the OLD uid if I pass sourceProfile.uid
      // Actually sourceProfile.uid is oldUid.
      // But updateUserProfile(uid, updates) uses common endpoint users/profile which updates current user.
      // So passed uid is ignored by the backend if it uses "me" or similar.
      // But looking at updateUserProfile:
      // Uri.parse('${Constants.baseUrl}/users/profile')
      // It doesn't use the uid parameter!
    } catch (e) {
      print('Error migrating profile: $e');
    }
  }

  /// Update user profile details
  Future<void> updateUserProfile(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('${Constants.baseUrl}/users/profile'),
        headers: await _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode != 200) {
        throw _buildApiException(
          'Failed to update user profile.',
          response.body,
        );
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  Future<void> requestAccountDeletion({
    String? uid,
    String? email,
    String? appleAuthorizationCode,
    String? appleUserIdentifier,
    List<String> providerIds = const <String>[],
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${Constants.baseUrl}/users/profile'),
        headers: await _getHeaders(),
        body: json.encode({
          if (uid != null && uid.trim().isNotEmpty) 'uid': uid.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (appleAuthorizationCode != null &&
              appleAuthorizationCode.trim().isNotEmpty)
            'appleAuthorizationCode': appleAuthorizationCode.trim(),
          if (appleUserIdentifier != null &&
              appleUserIdentifier.trim().isNotEmpty)
            'appleUserIdentifier': appleUserIdentifier.trim(),
          if (providerIds.isNotEmpty) 'providerIds': providerIds,
        }),
      );

      if (response.statusCode != 200 &&
          response.statusCode != 202 &&
          response.statusCode != 204) {
        throw _buildApiException(
          'Failed to request account deletion.',
          response.body,
        );
      }
    } catch (e) {
      print('Error requesting account deletion: $e');
      rethrow;
    }
  }

  /// Fetch a full user profile by UID
  Future<UserProfile?> fetchUserProfile(String uid) async {
    try {
      // If fetching "me", we can use a special endpoint or just the uid
      final url = uid == _auth.currentUser?.uid
          ? '${Constants.baseUrl}/users/me'
          : '${Constants.baseUrl}/users/$uid';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final badges = await fetchUserBadges(uid);
        return UserProfile.fromFirestore(data, uid, badges: badges);
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  Uri _buildAcademicUri(String path, [Map<String, String?> query = const {}]) {
    final params = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value?.trim();
      if (value != null && value.isNotEmpty) {
        params[entry.key] = value;
      }
    }
    return Uri.parse(
      '${Constants.baseUrl}$path',
    ).replace(queryParameters: params.isEmpty ? null : params);
  }

  List<Map<String, dynamic>> _decodeObjectList(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
    }

    if (decoded is Map<String, dynamic>) {
      final nestedList = decoded['data'] ?? decoded['items'] ?? decoded['result'];
      if (nestedList is List) {
        return nestedList
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList(growable: false);
      }

      return <Map<String, dynamic>>[decoded];
    }

    if (decoded is Map) {
      return _decodeObjectList(decoded.cast<String, dynamic>());
    }

    return const <Map<String, dynamic>>[];
  }

  List<AcademicFaculty> _parseAcademicFaculties(dynamic decoded) {
    return _decodeObjectList(decoded)
        .map(AcademicFaculty.fromJson)
        .where((faculty) => faculty.key.isNotEmpty && faculty.name.isNotEmpty)
        .toList(growable: false);
  }

  List<AcademicGrade> _normalizeGrades(List<AcademicGrade> grades) {
    final sorted = List<AcademicGrade>.of(grades);
    sorted.sort((a, b) {
      final left = a.level ?? 999;
      final right = b.level ?? 999;
      if (left != right) {
        return left.compareTo(right);
      }
      return a.name.compareTo(b.name);
    });
    return List<AcademicGrade>.unmodifiable(sorted);
  }

  Future<List<AcademicFaculty>> _fetchAcademicFacultyTree({
    String? facultyKey,
  }) async {
    final response = await http.get(
      _buildAcademicUri('/academic-faculties', {'facultyKey': facultyKey}),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw _buildApiException(
        'Akademik birim listesi alinamadi.',
        response.body,
      );
    }

    return _parseAcademicFaculties(json.decode(response.body));
  }

  Future<List<AcademicFaculty>> fetchAcademicFaculties({
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh && _facultyCache != null) {
        return _facultyCache!;
      }

      final faculties = await _fetchAcademicFacultyTree();
      _facultyCache = List<AcademicFaculty>.unmodifiable(
        faculties
            .map(
              (faculty) => AcademicFaculty(
                key: faculty.key,
                name: faculty.name,
                departments: const <AcademicDepartment>[],
              ),
            )
            .toList(growable: false),
      );
      return _facultyCache!;
    } catch (e) {
      print('Error fetching academic faculties: $e');
      rethrow;
    }
  }

  Future<List<AcademicDepartment>> fetchAcademicDepartments(
    String facultyKey, {
    bool forceRefresh = false,
  }) async {
    final normalizedKey = facultyKey.trim();
    if (normalizedKey.isEmpty) {
      return const <AcademicDepartment>[];
    }

    if (!forceRefresh && _departmentCache.containsKey(normalizedKey)) {
      return _departmentCache[normalizedKey]!;
    }

    try {
      final faculties = await _fetchAcademicFacultyTree(facultyKey: normalizedKey);
      AcademicFaculty? faculty;
      for (final item in faculties) {
        if (item.key == normalizedKey) {
          faculty = item;
          break;
        }
      }
      faculty ??= faculties.isNotEmpty ? faculties.first : null;

      final departments = faculty == null || faculty.key.isEmpty
          ? const <AcademicDepartment>[]
          : List<AcademicDepartment>.unmodifiable(faculty.departments);
      _departmentCache[normalizedKey] = departments;
      return departments;
    } catch (e) {
      print('Error fetching academic departments for $normalizedKey: $e');
      rethrow;
    }
  }

  Future<List<AcademicGrade>> fetchAcademicGrades(
    String departmentKey, {
    String? facultyKey,
    bool forceRefresh = false,
  }) async {
    final normalizedDepartmentKey = departmentKey.trim();
    if (normalizedDepartmentKey.isEmpty) {
      return const <AcademicGrade>[];
    }

    if (!forceRefresh && _gradeCache.containsKey(normalizedDepartmentKey)) {
      return _gradeCache[normalizedDepartmentKey]!;
    }

    try {
      final departments = facultyKey != null && facultyKey.trim().isNotEmpty
          ? await fetchAcademicDepartments(facultyKey, forceRefresh: forceRefresh)
          : <AcademicDepartment>[];
      AcademicDepartment? department;
      for (final item in departments) {
        if (item.key == normalizedDepartmentKey) {
          department = item;
          break;
        }
      }

      if (department != null && department.key.isNotEmpty) {
        final grades = _normalizeGrades(department.grades);
        _gradeCache[normalizedDepartmentKey] = grades;
        return grades;
      }

      final classResponse = await http.get(
        _buildAcademicUri('/classes', {'departmentKey': normalizedDepartmentKey}),
        headers: await _getHeaders(),
      );

      if (classResponse.statusCode != 200) {
        throw _buildApiException(
          'Sınıf listesi alınamadı.',
          classResponse.body,
        );
      }

      final grades = _normalizeGrades(
        _decodeObjectList(json.decode(classResponse.body))
            .map(AcademicGrade.fromJson)
            .where((grade) => grade.key.isNotEmpty && grade.name.isNotEmpty)
            .toList(growable: false),
      );
      _gradeCache[normalizedDepartmentKey] = grades;
      return grades;
    } catch (e) {
      print('Error fetching academic grades for $normalizedDepartmentKey: $e');
      rethrow;
    }
  }
}
