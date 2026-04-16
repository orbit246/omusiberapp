import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omusiber/backend/master_news_widgets_repository.dart';
import 'package:omusiber/backend/profile_identity.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/academic_faculty_model.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';
import 'package:url_launcher/url_launcher.dart';

class EditProfilePage extends StatefulWidget {
  final String? uid;
  final UserProfile? initialProfile;

  const EditProfilePage({super.key, this.uid, this.initialProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

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
  String? _loadError;
  String? _academicSelectionNotice;
  int _departmentRequestToken = 0;
  int _gradeRequestToken = 0;

  final List<String> _genders = ["Erkek", "Kadın", "Belirtmek İstemiyorum"];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _studentIdController = TextEditingController();
    _ageController = TextEditingController();

    final initialProfile = widget.initialProfile;
    if (initialProfile != null) {
      _applyProfile(initialProfile);
      _resolvedUid = initialProfile.uid;
      _isLoading = false;
    }

    _resolvedUid = widget.uid ?? _auth.currentUser?.uid;
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

  Future<void> _loadInitialData() async {
    final uid = _resolvedUid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Profil bilgisi için aktif kullanıcı bulunamadı.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
      _academicSelectionNotice = null;
    });

    try {
      final profile = await _profileService.fetchUserProfile(uid);

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _isLoading = false;
          _loadError = 'Profil bilgisi şu anda yüklenemedi.';
        });
        return;
      }

      _applyProfile(profile);
      await _loadAcademicOptions();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
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
        _academicSelectionNotice =
            'Kayıtlı fakülte bilgisi güncel listede bulunamadı. Lütfen yeniden seçin.';
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
        _availableDepartments = departments;
        _isDepartmentsLoading = false;
      });
    } catch (e) {
      if (!mounted || requestToken != _departmentRequestToken) return;
      setState(() {
        _isDepartmentsLoading = false;
        _academicSelectionNotice = e.toString().replaceFirst('Exception: ', '');
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
        _availableGrades = grades;
        _isGradesLoading = false;
      });
    } catch (e) {
      if (!mounted || requestToken != _gradeRequestToken) return;
      setState(() {
        _isGradesLoading = false;
        _academicSelectionNotice = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _reconcileAcademicSelection() {
    String? notice;

    final selectedFaculty = _selectedFaculty;
    if (_selectedFacultyKey != null && selectedFaculty == null) {
      _selectedFacultyKey = null;
      _selectedDepartmentKey = null;
      _selectedGradeKey = null;
      _availableDepartments = const [];
      _availableGrades = const [];
      notice =
          'Kayıtlı fakülte bilgisi güncel listede bulunamadı. Lütfen yeniden seçin.';
    }

    final selectedDepartment = _selectedDepartment;
    if (_selectedDepartmentKey != null && selectedDepartment == null) {
      _selectedDepartmentKey = null;
      _selectedGradeKey = null;
      _availableGrades = const [];
      notice =
          'Kayıtlı bölüm bilgisi güncel listede bulunamadı. Lütfen yeniden seçin.';
    }

    final hasSelectedGrade = _selectedGradeKey != null;
    final gradeStillExists = _availableGrades.any(
      (grade) => grade.key == _selectedGradeKey,
    );
    if (hasSelectedGrade && !gradeStillExists) {
      _selectedGradeKey = null;
      notice =
          'Kayıtlı sınıf bilgisi güncel listede bulunamadı. Lütfen yeniden seçin.';
    }

    _academicSelectionNotice = notice;
  }

  Future<void> _persistAcademicSelection() async {
    final uid = _resolvedUid;
    if (uid == null) return;

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
      final refreshedProfile = await _profileService.fetchUserProfile(uid);
      if (mounted && refreshedProfile != null) {
        setState(() {
          _applyProfile(refreshedProfile);
        });
      }
      unawaited(
        MasterNewsWidgetsRepository().fetchWidgets(forceRefresh: true),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _academicSelectionNotice = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Akademik bilgiler kaydedilemedi: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAcademicSyncing = false;
        });
      }
    }
  }

  Future<void> _onFacultyChanged(String? facultyKey) async {
    setState(() {
      _selectedFacultyKey = facultyKey;
      _selectedDepartmentKey = null;
      _selectedGradeKey = null;
      _availableDepartments = const [];
      _availableGrades = const [];
      _academicSelectionNotice = null;
    });

    await _persistAcademicSelection();
    if (facultyKey != null) {
      await _loadDepartmentsForFaculty(facultyKey);
    }
  }

  Future<void> _onDepartmentChanged(String? departmentKey) async {
    setState(() {
      _selectedDepartmentKey = departmentKey;
      _selectedGradeKey = null;
      _availableGrades = const [];
      _academicSelectionNotice = null;
    });

    await _persistAcademicSelection();
    if (departmentKey != null) {
      await _loadGradesForDepartment(departmentKey);
    }
  }

  Future<void> _onGradeChanged(String? gradeKey) async {
    if (!mounted) return;
    setState(() {
      _selectedGradeKey = gradeKey;
      _academicSelectionNotice = null;
    });
    await _persistAcademicSelection();
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

  Future<void> _saveProfile() async {
    final uid = _resolvedUid;
    if (_profile == null || _isLoading || uid == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final facultyKey = _selectedFacultyKey;
      final departmentKey = facultyKey == null ? null : _selectedDepartmentKey;
      final gradeKey = departmentKey == null ? null : _selectedGradeKey;
      final updates = {
        'name': _nameController.text.trim(),
        'studentId': _studentIdController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'facultyKey': facultyKey,
        'departmentKey': departmentKey,
        'gradeKey': gradeKey,
        'gender': _selectedGender,
      };

      await _profileService.updateUserProfile(uid, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil başarıyla güncellendi.")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Hata oluştu: $message")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  Widget _buildStatusCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Profil bilgileri getiriliyor. Sayfa acildi, alanlar birazdan dolacak.",
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _loadError!,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: _loadInitialData,
              child: const Text("Tekrar dene"),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _academicSelectionNotice ??
                  (_isAcademicSyncing
                      ? "Akademik seçiminiz kaydediliyor."
                      : "Profil bilgilerinizi doldurarak topluluktaki etkileşiminizi artırabilirsiniz."),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isReady = _profile != null && !_isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profili Düzenle"),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: isReady ? _saveProfile : null,
              icon: const Icon(Icons.check),
              tooltip: "Kaydet",
            ),
        ],
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
                _buildStatusCard(theme),
                const SizedBox(height: 24),
                Text(
                  "Temel Bilgiler",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Ad Soyad",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  maxLength: 32,
                  validator: (val) {
                    if (val == null || val.isEmpty) return "Ad soyad gerekli";
                    if (val.length > 32) return "En fazla 32 karakter";
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _studentIdController,
                  decoration: InputDecoration(
                    labelText: "Öğrenci Numarası",
                    helperText:
                        _profile?.email != null &&
                            extractStudentIdFromEmail(_profile?.email) != null
                        ? "E-postanızdan otomatik dolduruldu. İsterseniz değiştirebilir veya boş bırakabilirsiniz."
                        : "İsteğe bağlı. Öğrenci değilseniz boş bırakabilirsiniz.",
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    if (!RegExp(r'^\d{6,}$').hasMatch(val.trim())) {
                      return "En az 6 haneli sayı olmalı";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _ageController,
                        decoration: InputDecoration(
                          labelText: "Yaş",
                          prefixIcon: const Icon(Icons.cake_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (val) {
                          if (val == null || val.isEmpty) return null;
                          final age = int.tryParse(val);
                          if (age == null) return "Geçersiz";
                          if (age <= 13 || age >= 70) return "14-69 olmalı";
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('gender-$_selectedGender'),
                        isExpanded: true,
                        initialValue: _selectedGender,
                        decoration: InputDecoration(
                          labelText: "Cinsiyet",
                          prefixIcon: const Icon(Icons.wc_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                        ),
                        items: _genders
                            .map(
                              (g) => DropdownMenuItem(
                                value: g,
                                child: Text(g, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedGender = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  "Okul Bilgileri",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'faculty-${_selectedFacultyKey ?? 'empty'}-${_academicFaculties.length}',
                  ),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: "Fakülte",
                    prefixIcon: const Icon(Icons.school_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  initialValue: _selectedFacultyKey,
                  items: _academicFaculties
                      .map(
                        (faculty) => DropdownMenuItem<String>(
                          value: faculty.key,
                          child: Text(
                            faculty.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isAcademicSyncing ? null : _onFacultyChanged,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'department-${_selectedFacultyKey ?? 'none'}-${_selectedDepartmentKey ?? 'empty'}',
                  ),
                  isExpanded: true,
                  initialValue: _selectedDepartmentKey,
                  decoration: InputDecoration(
                    labelText: "Bölüm",
                    helperText: _selectedFacultyKey == null
                        ? "Önce fakülte seçin."
                        : _isDepartmentsLoading
                        ? "Bölümler getiriliyor."
                        : null,
                    prefixIcon: const Icon(Icons.apartment_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
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
                  onChanged: _selectedFacultyKey == null ||
                          _isDepartmentsLoading ||
                          _isAcademicSyncing
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
                  decoration: InputDecoration(
                    labelText: "Sınıf",
                    helperText: _selectedDepartmentKey == null
                        ? "Önce bölüm seçin."
                        : _isGradesLoading
                        ? "Sınıflar getiriliyor."
                        : null,
                    prefixIcon: const Icon(Icons.format_list_numbered_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
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
                          child: Text(
                            grade.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _selectedDepartmentKey == null ||
                          _isGradesLoading ||
                          _isAcademicSyncing
                      ? null
                      : _onGradeChanged,
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: isReady && !_isSaving ? _saveProfile : null,
                    icon: const Icon(Icons.save),
                    label: const Text(
                      "Değişiklikleri Kaydet",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
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
