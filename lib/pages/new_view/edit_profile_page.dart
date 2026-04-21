import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omusiber/backend/master_news_widgets_repository.dart';
import 'package:omusiber/backend/profile_identity.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/academic_faculty_model.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';
import 'package:omusiber/widgets/badge_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class EditProfilePage extends StatefulWidget {
  final String? uid;
  final UserProfile? initialProfile;

  const EditProfilePage({super.key, this.uid, this.initialProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _CachedEditProfile {
  const _CachedEditProfile({required this.profile, required this.cachedAt});

  final UserProfile profile;
  final DateTime cachedAt;

  bool get isFresh => DateTime.now().difference(cachedAt) < _profileCacheTtl;
}

const Duration _profileCacheTtl = Duration(minutes: 5);
final Map<String, _CachedEditProfile> _profileCache = {};

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = UserProfileService();
  final _auth = FirebaseAuth.instance;

  late final TextEditingController _nameController;
  late final TextEditingController _studentIdController;
  late final TextEditingController _ageController;

  UserProfile? _profile;
  List<AcademicFaculty> _academicFaculties = const [];
  List<AcademicDepartment> _availableDepartments = const [];
  List<AcademicGrade> _availableGrades = const [];
  final Map<String, List<AcademicDepartment>> _departmentOptionsCache = {};
  final Map<String, List<AcademicGrade>> _gradeOptionsCache = {};
  String? _selectedGender;
  String? _selectedFacultyKey;
  String? _selectedDepartmentKey;
  String? _selectedGradeKey;
  String? _resolvedUid;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDepartmentsLoading = false;
  bool _isGradesLoading = false;
  bool _isAcademicSyncing = false;
  int _profileStep = 0;
  int _departmentRequestToken = 0;
  int _gradeRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _studentIdController = TextEditingController();
    _ageController = TextEditingController();

    _resolvedUid = widget.uid ?? _auth.currentUser?.uid;

    final initialProfile = widget.initialProfile;
    if (initialProfile != null) {
      _applyProfile(initialProfile);
      _resolvedUid = initialProfile.uid;
      _cacheProfile(initialProfile);
      _isLoading = false;
    } else {
      _applyCachedProfileIfFresh();
    }

    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  AcademicFaculty? get _selectedFaculty {
    final facultyKey = _selectedFacultyKey;
    if (facultyKey == null) return null;
    for (final faculty in _academicFaculties) {
      if (faculty.key == facultyKey) {
        return faculty;
      }
    }
    return null;
  }

  AcademicDepartment? get _selectedDepartment {
    final departmentKey = _selectedDepartmentKey;
    if (departmentKey == null) return null;
    for (final department in _availableDepartments) {
      if (department.key == departmentKey) {
        return department;
      }
    }
    return null;
  }

  bool get _isAcademicStepComplete =>
      _selectedFacultyKey != null &&
      _selectedDepartmentKey != null &&
      _selectedGradeKey != null;

  void _cacheProfile(UserProfile profile) {
    if (profile.uid.isEmpty) return;
    _profileCache[profile.uid] = _CachedEditProfile(
      profile: profile,
      cachedAt: DateTime.now(),
    );
  }

  void _applyCachedProfileIfFresh() {
    if (_profile != null) return;

    final uid = _resolvedUid;
    if (uid == null) return;

    final cached = _profileCache[uid];
    if (cached == null || !cached.isFresh) return;

    _applyProfile(cached.profile);
    _isLoading = false;
  }

  Future<void> _loadInitialData() async {
    final uid = _resolvedUid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = _profile == null;
    });

    try {
      final profile = await _profileService.fetchUserProfile(uid);

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      _applyProfile(profile);
      _cacheProfile(profile);
      await _loadAcademicOptions();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAcademicOptions() async {
    final faculties = await _profileService.fetchAcademicFaculties();
    if (!mounted) return;

    setState(() {
      _academicFaculties = faculties;
    });

    if (_selectedFacultyKey == null) {
      setState(() {
        _availableDepartments = const [];
        _availableGrades = const [];
      });
      return;
    }

    final selectedFacultyExists = _academicFaculties.any(
      (faculty) => faculty.key == _selectedFacultyKey,
    );
    if (!selectedFacultyExists) {
      setState(() {
        _selectedFacultyKey = null;
        _selectedDepartmentKey = null;
        _selectedGradeKey = null;
        _availableDepartments = const [];
        _availableGrades = const [];
      });
      return;
    }

    await _loadDepartmentsForFaculty(
      _selectedFacultyKey!,
      preserveSelection: true,
    );

    if (_selectedDepartmentKey != null) {
      await _loadGradesForDepartment(
        _selectedDepartmentKey!,
        preserveSelection: true,
      );
    }

    if (mounted) {
      setState(_reconcileAcademicSelection);
    }
  }

  Future<void> _loadDepartmentsForFaculty(
    String facultyKey, {
    bool preserveSelection = false,
  }) async {
    final cachedDepartments = _departmentOptionsCache[facultyKey];
    if (cachedDepartments != null) {
      if (!mounted) return;
      setState(() {
        _availableDepartments = cachedDepartments;
        _isDepartmentsLoading = false;
        if (!preserveSelection) {
          _selectedDepartmentKey = null;
          _selectedGradeKey = null;
        }
      });
      return;
    }

    final requestToken = ++_departmentRequestToken;
    if (mounted) {
      setState(() {
        _isDepartmentsLoading = true;
        _availableDepartments = const [];
        _availableGrades = const [];
        if (!preserveSelection) {
          _selectedDepartmentKey = null;
          _selectedGradeKey = null;
        }
      });
    }

    try {
      final departments = await _profileService.fetchAcademicDepartments(
        facultyKey,
      );
      if (!mounted || requestToken != _departmentRequestToken) return;

      setState(() {
        _departmentOptionsCache[facultyKey] = departments;
        _availableDepartments = departments;
        _isDepartmentsLoading = false;
      });
    } catch (e) {
      if (!mounted || requestToken != _departmentRequestToken) return;
      setState(() {
        _isDepartmentsLoading = false;
      });
    }
  }

  Future<void> _loadGradesForDepartment(
    String departmentKey, {
    bool preserveSelection = false,
  }) async {
    final facultyKey = _selectedFacultyKey;
    if (facultyKey == null) {
      if (!mounted) return;
      setState(() {
        _availableGrades = const [];
        if (!preserveSelection) {
          _selectedGradeKey = null;
        }
      });
      return;
    }

    final cachedGrades = _gradeOptionsCache[departmentKey];
    if (cachedGrades != null) {
      if (!mounted) return;
      setState(() {
        _availableGrades = cachedGrades;
        _isGradesLoading = false;
        if (!preserveSelection) {
          _selectedGradeKey = null;
        }
      });
      return;
    }

    final requestToken = ++_gradeRequestToken;
    if (mounted) {
      setState(() {
        _isGradesLoading = true;
        _availableGrades = const [];
        if (!preserveSelection) {
          _selectedGradeKey = null;
        }
      });
    }

    try {
      final grades = await _profileService.fetchAcademicGrades(
        departmentKey,
        facultyKey: facultyKey,
      );
      if (!mounted || requestToken != _gradeRequestToken) return;

      setState(() {
        _gradeOptionsCache[departmentKey] = grades;
        _availableGrades = grades;
        _isGradesLoading = false;
      });
    } catch (e) {
      if (!mounted || requestToken != _gradeRequestToken) return;
      setState(() {
        _isGradesLoading = false;
      });
    }
  }

  void _reconcileAcademicSelection() {
    final selectedFaculty = _selectedFaculty;
    if (_selectedFacultyKey != null && selectedFaculty == null) {
      _selectedFacultyKey = null;
      _selectedDepartmentKey = null;
      _selectedGradeKey = null;
      _availableDepartments = const [];
      _availableGrades = const [];
    }

    final selectedDepartment = _selectedDepartment;
    if (_selectedDepartmentKey != null && selectedDepartment == null) {
      _selectedDepartmentKey = null;
      _selectedGradeKey = null;
      _availableGrades = const [];
    }

    final hasSelectedGrade = _selectedGradeKey != null;
    final gradeStillExists = _availableGrades.any(
      (grade) => grade.key == _selectedGradeKey,
    );
    if (hasSelectedGrade && !gradeStillExists) {
      _selectedGradeKey = null;
    }
  }

  Future<bool> _persistAcademicSelection() async {
    final uid = _resolvedUid;
    if (uid == null) return false;

    final facultyKey = _selectedFacultyKey;
    final departmentKey = facultyKey == null ? null : _selectedDepartmentKey;
    final gradeKey = departmentKey == null ? null : _selectedGradeKey;

    if (mounted) {
      setState(() {
        _isAcademicSyncing = true;
      });
    }

    try {
      await _profileService.updateUserProfile(uid, {
        'facultyKey': facultyKey,
        'departmentKey': departmentKey,
        'gradeKey': gradeKey,
      });
      unawaited(MasterNewsWidgetsRepository().fetchWidgets(forceRefresh: true));
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Akademik bilgiler kaydedilemedi: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isAcademicSyncing = false;
        });
      }
    }
  }

  Future<void> _onFacultyChanged(String? facultyKey) async {
    final cachedDepartments = facultyKey == null
        ? const <AcademicDepartment>[]
        : _departmentOptionsCache[facultyKey];
    setState(() {
      _selectedFacultyKey = facultyKey;
      _selectedDepartmentKey = null;
      _selectedGradeKey = null;
      _availableDepartments = cachedDepartments ?? const [];
      _availableGrades = const [];
      _isDepartmentsLoading = facultyKey != null && cachedDepartments == null;
      _isGradesLoading = false;
    });

    if (facultyKey != null) {
      await _loadDepartmentsForFaculty(facultyKey);
    }
  }

  Future<void> _onDepartmentChanged(String? departmentKey) async {
    final cachedGrades = departmentKey == null
        ? const <AcademicGrade>[]
        : _gradeOptionsCache[departmentKey];
    setState(() {
      _selectedDepartmentKey = departmentKey;
      _selectedGradeKey = null;
      _availableGrades = cachedGrades ?? const [];
      _isGradesLoading = departmentKey != null && cachedGrades == null;
    });

    if (departmentKey != null) {
      await _loadGradesForDepartment(departmentKey);
    }
  }

  Future<void> _onGradeChanged(String? gradeKey) async {
    if (!mounted) return;
    setState(() {
      _selectedGradeKey = gradeKey;
    });
  }

  void _applyProfile(UserProfile profile) {
    final derivedStudentId = extractStudentIdFromEmail(profile.email);
    _profile = profile;
    _nameController.text = profile.name;
    _studentIdController.text = profile.studentId ?? derivedStudentId ?? "";
    _ageController.text = profile.age?.toString() ?? "";
    _selectedGender = profile.gender;
    _selectedFacultyKey = profile.facultyKey;
    _selectedDepartmentKey = profile.departmentKey;
    _selectedGradeKey = profile.gradeKey;
  }

  Future<void> _saveProfile({
    bool validateIdentity = true,
    bool includeIdentity = true,
  }) async {
    final uid = _resolvedUid;
    if (_profile == null || _isLoading || uid == null) return;
    if (validateIdentity && !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final facultyKey = _selectedFacultyKey;
      final departmentKey = facultyKey == null ? null : _selectedDepartmentKey;
      final gradeKey = departmentKey == null ? null : _selectedGradeKey;
      final updates = <String, dynamic>{
        'facultyKey': facultyKey,
        'departmentKey': departmentKey,
        'gradeKey': gradeKey,
      };

      if (includeIdentity) {
        updates.addAll({
          'name': _nameController.text.trim(),
          'studentId': _studentIdController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()),
          'gender': _selectedGender,
        });
      }

      await _profileService.updateUserProfile(uid, updates);

      if (mounted) {
        final refreshedProfile = await _profileService.fetchUserProfile(uid);
        if (!mounted) return;

        setState(() {
          if (refreshedProfile != null) {
            _applyProfile(refreshedProfile);
            _cacheProfile(refreshedProfile);
          }
          _isSaving = false;
        });
        await _showProfileSavedDialog();
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Hata oluştu: $message")));
      }
    } finally {
      if (mounted && _isSaving) setState(() => _isSaving = false);
    }
  }

  Future<void> _showProfileSavedDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          icon: Icon(Icons.check_circle_outline, color: colorScheme.primary),
          title: const Text('Kaydedildi'),
          content: const Text('Profil bilgileriniz kaydedildi.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleBackAction() async {
    if (_profileStep == 0) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    setState(() {
      _profileStep = 0;
    });
  }

  Future<void> _handleSkipAction() async {
    if (_profileStep == 0) {
      setState(() {
        _profileStep = 1;
      });
      return;
    }

    await _saveProfile(validateIdentity: false, includeIdentity: false);
  }

  Future<void> _handleNextAction() async {
    if (_profileStep == 0) {
      if (!_isAcademicStepComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devam etmek için fakülte, bölüm ve sınıf seçin.'),
          ),
        );
        return;
      }

      final saved = await _persistAcademicSelection();
      if (!mounted || !saved) return;

      setState(() {
        _profileStep = 1;
      });
      return;
    }

    _saveProfile();
  }

  Future<void> _showDeleteAccountDialog() async {
    final profile = _profile;
    final user = _auth.currentUser;
    final email = profile?.email ?? user?.email ?? '';
    final uid = _resolvedUid ?? user?.uid ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          title: const Text("Hesabımı Sil"),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bu işlem geri alınamaz. Hesap silme talebiniz işleme alındığında hesabınız ve bu hesaba bağlı veriler kalıcı olarak silinir.",
                ),
                SizedBox(height: 12),
                Text(
                  "Silinecek veriler; profil bilgileriniz, e-posta adresiniz, kullanıcı kimliğiniz (UID), profil fotoğrafı bağlantınız, etkinlik/beğeni/anket gibi uygulama içi etkileşimleriniz, bildirim belirteçleriniz ve backend/Firebase üzerinde tutulan hesap kayıtlarınızı kapsayabilir.",
                ),
                SizedBox(height: 12),
                Text(
                  "Cihazınızda yerel olarak saklanan notlar, uygulama kaldırıldığında veya uygulama verisi temizlendiğinde cihazdan kaldırılır.",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Vazgeç"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Silme Talebi Gönder"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final body = StringBuffer()
      ..writeln('Merhaba,')
      ..writeln()
      ..writeln(
        'AkademiZ hesabimin ve hesabima bagli verilerin silinmesini talep ediyorum.',
      )
      ..writeln()
      ..writeln('UID: ${uid.isEmpty ? "(bulunamadı)" : uid}')
      ..writeln('E-posta: ${email.isEmpty ? "(bulunamadı)" : email}')
      ..writeln()
      ..writeln(
        'Bu talebin geri alinamayacagini ve hesap verilerimin kalici olarak silinecegini anliyorum.',
      );

    final uri = Uri(
      scheme: 'mailto',
      path: 'admin@nortixlabs.com',
      queryParameters: {
        'subject': 'AkademiZ hesap silme talebi',
        'body': body.toString(),
      },
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          "E-posta uygulaması açılamadı. Lütfen admin@nortixlabs.com adresine hesap silme talebinizi gönderin.",
        ),
      ),
    );
  }

  Widget _buildBadgesSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final badges = _profile?.badges ?? const [];

    if (badges.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.workspace_premium_outlined, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Henüz madalyanız yok.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: BadgeList(badges: badges),
    );
  }

  Widget _buildStickyCard({
    required ThemeData theme,
    required String title,
    required Widget child,
    String? subtitle,
    IconData? icon,
  }) {
    final colorScheme = theme.colorScheme;
    final bodyColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.55,
    );
    final headerColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.12),
      bodyColor,
    );

    return Container(
      decoration: BoxDecoration(
        color: bodyColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
            ),
            child: Column(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: colorScheme.primary),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  InputDecoration _buildCardFieldDecoration({
    required ThemeData theme,
    required String labelText,
    required IconData icon,
    String? helperText,
    Widget? suffixIcon,
  }) {
    final colorScheme = theme.colorScheme;
    return InputDecoration(
      labelText: labelText,
      helperText: helperText,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      filled: true,
      fillColor: colorScheme.surface.withValues(alpha: 0.92),
    );
  }

  Widget _buildAcademicCard(ThemeData theme) {
    return _buildStickyCard(
      theme: theme,
      title: 'Okul Bilgileri',
      subtitle:
          'Önce fakülte, bölüm ve sınıf seçin. Diğer bilgiler daha sonra eklenebilir.',
      icon: Icons.school_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(
              'faculty-${_selectedFacultyKey ?? 'empty'}-${_academicFaculties.length}',
            ),
            isExpanded: true,
            decoration: _buildCardFieldDecoration(
              theme: theme,
              labelText: 'Fakülte',
              icon: Icons.account_balance_outlined,
            ),
            initialValue: _selectedFacultyKey,
            items: _academicFaculties
                .map(
                  (faculty) => DropdownMenuItem<String>(
                    value: faculty.key,
                    child: Text(faculty.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _onFacultyChanged,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(
              'department-${_selectedFacultyKey ?? 'none'}-${_selectedDepartmentKey ?? 'empty'}',
            ),
            isExpanded: true,
            initialValue: _selectedDepartmentKey,
            decoration: _buildCardFieldDecoration(
              theme: theme,
              labelText: 'Bölüm',
              icon: Icons.apartment_outlined,
              helperText: _selectedFacultyKey == null
                  ? 'Önce fakülte seçin.'
                  : _isDepartmentsLoading
                  ? 'Bölümler getiriliyor.'
                  : null,
              suffixIcon: _isDepartmentsLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            items: _availableDepartments
                .map(
                  (department) => DropdownMenuItem<String>(
                    value: department.key,
                    child: Text(
                      department.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _selectedFacultyKey == null || _isDepartmentsLoading
                ? null
                : _onDepartmentChanged,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(
              'grade-${_selectedDepartmentKey ?? 'none'}-${_selectedGradeKey ?? 'empty'}',
            ),
            isExpanded: true,
            initialValue: _selectedGradeKey,
            decoration: _buildCardFieldDecoration(
              theme: theme,
              labelText: 'Sınıf',
              icon: Icons.format_list_numbered_outlined,
              helperText: _selectedDepartmentKey == null
                  ? 'Önce bölüm seçin.'
                  : _isGradesLoading
                  ? 'Sınıflar getiriliyor.'
                  : null,
              suffixIcon: _isGradesLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            items: _availableGrades
                .map(
                  (grade) => DropdownMenuItem<String>(
                    value: grade.key,
                    child: Text(grade.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _selectedDepartmentKey == null || _isGradesLoading
                ? null
                : _onGradeChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(ThemeData theme) {
    return _buildStickyCard(
      theme: theme,
      title: 'Kimlik Bilgileri',
      subtitle:
          'Ad soyad ve öğrenci numarası isteğe bağlı. Dilerseniz atlayabilirsiniz.',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: _buildCardFieldDecoration(
              theme: theme,
              labelText: 'Ad Soyad',
              icon: Icons.person_outline,
              helperText: 'İsteğe bağlı.',
            ),
            maxLength: 32,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return null;
              if (val.trim().length > 32) return 'En fazla 32 karakter';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _studentIdController,
            decoration: _buildCardFieldDecoration(
              theme: theme,
              labelText: 'Öğrenci Numarası',
              icon: Icons.numbers_outlined,
              helperText:
                  _profile?.email != null &&
                      extractStudentIdFromEmail(_profile?.email) != null
                  ? 'E-postanızdan otomatik dolduruldu. İsterseniz değiştirebilir veya boş bırakabilirsiniz.'
                  : 'İsteğe bağlı. Öğrenci değilseniz boş bırakabilirsiniz.',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (val) {
              if (val == null || val.trim().isEmpty) return null;
              if (!RegExp(r'^\d{6,}$').hasMatch(val.trim())) {
                return 'En az 6 haneli sayı olmalı';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStepCard(
    ThemeData theme, {
    required bool showInitialLoading,
  }) {
    final colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 330),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _profileStep == 0
                ? _buildAcademicCard(theme)
                : _buildIdentityCard(theme),
          ),
          if (showInitialLoading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: ColoredBox(
                    color: colorScheme.surface.withValues(alpha: 0.04),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            'Profil Yükleniyor',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepActions(bool isReady) {
    final canInteract = isReady && !_isSaving && !_isAcademicSyncing;
    final canGoNext =
        canInteract && (_profileStep != 0 || _isAcademicStepComplete);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: canInteract ? _handleBackAction : null,
          child: const Text('Geri'),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: canInteract ? _handleSkipAction : null,
          child: const Text('Atla'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: canGoNext ? _handleNextAction : null,
          child: const Text('İleri'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInitialProfileLoading = _isLoading && _profile == null;
    final isReady = _profile != null && !isInitialProfileLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profili Düzenle"),
        actions: _isSaving
            ? [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: AbsorbPointer(
            absorbing: !isReady || _isSaving,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileStepCard(
                  theme,
                  showInitialLoading: isInitialProfileLoading,
                ),
                const SizedBox(height: 20),
                _buildStepActions(isReady),
                const SizedBox(height: 32),
                Text(
                  "Madalyalar",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBadgesSection(theme),
                const SizedBox(height: 32),
                Text(
                  "Hesap Yönetimi",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDeleteAccountCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delete_forever_outlined, color: colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Hesabımı Sil",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Hesabınızın ve bağlı verilerinizin kalıcı olarak silinmesini talep edebilirsiniz. Devam etmeden önce geri alınamaz sonuçları açıklayan bir onay penceresi gösterilir.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showDeleteAccountDialog,
              icon: const Icon(Icons.delete_outline),
              label: const Text("Hesabımı Sil"),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
