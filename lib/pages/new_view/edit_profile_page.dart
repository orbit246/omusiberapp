import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _selectedGender;
  String? _selectedCampus;
  String? _selectedFacultyKey;
  String? _selectedDepartmentKey;
  String? _selectedGradeKey;
  String? _resolvedUid;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _academicSelectionNotice;

  final List<String> _genders = ["Erkek", "Kadın", "Belirtmek İstemiyorum"];
  final List<String> _campuses = [
    "Kurupelit Yerleşkesi",
    "Güzel Sanatlar Yerleşkesi",
    "Ballıca Yerleşkesi",
    "Çarşamba Yerleşkesi",
    "Bafra Yerleşkesi",
    "Havza Yerleşkesi",
    "Vezirköprü Yerleşkesi",
    "Kavak Yerleşkesi",
    "Ladik Yerleşkesi",
    "Alaçam Yerleşkesi",
  ];

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

  List<AcademicDepartment> get _availableDepartments =>
      _selectedFaculty?.departments ?? const <AcademicDepartment>[];

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

  List<AcademicGrade> get _availableGrades =>
      _selectedDepartment?.grades ?? const <AcademicGrade>[];

  Future<void> _loadInitialData() async {
    final uid = _resolvedUid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Profil bilgisi icin aktif kullanici bulunamadi.';
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
      final results = await Future.wait<Object?>([
        _profileService.fetchUserProfile(uid),
        _profileService.fetchAcademicFaculties(),
      ]);

      if (!mounted) return;

      final profile = results[0] as UserProfile?;
      final academicFaculties = results[1] as List<AcademicFaculty>;

      if (profile == null) {
        setState(() {
          _academicFaculties = academicFaculties;
          _isLoading = false;
          _loadError = 'Profil bilgisi su anda yuklenemedi.';
        });
        return;
      }

      setState(() {
        _academicFaculties = academicFaculties;
        _applyProfile(profile);
        _reconcileAcademicSelection();
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

  void _reconcileAcademicSelection() {
    String? notice;

    final selectedFaculty = _selectedFaculty;
    if (_selectedFacultyKey != null && selectedFaculty == null) {
      _selectedFacultyKey = null;
      _selectedDepartmentKey = null;
      _selectedGradeKey = null;
      notice =
          'Kayitli fakulte bilgisi guncel listede bulunamadi. Lutfen yeniden secin.';
    }

    final selectedDepartment = _selectedDepartment;
    if (_selectedDepartmentKey != null && selectedDepartment == null) {
      _selectedDepartmentKey = null;
      _selectedGradeKey = null;
      notice =
          'Kayitli bolum bilgisi guncel listede bulunamadi. Lutfen yeniden secin.';
    }

    final hasSelectedGrade = _selectedGradeKey != null;
    final gradeStillExists = _availableGrades.any(
      (grade) => grade.key == _selectedGradeKey,
    );
    if (hasSelectedGrade && !gradeStillExists) {
      _selectedGradeKey = null;
      notice =
          'Kayitli sinif bilgisi guncel listede bulunamadi. Lutfen yeniden secin.';
    }

    _academicSelectionNotice = notice;
  }

  void _onFacultyChanged(String? facultyKey) {
    setState(() {
      _selectedFacultyKey = facultyKey;
      _selectedDepartmentKey = null;
      _selectedGradeKey = null;
      _academicSelectionNotice = null;
    });
  }

  void _onDepartmentChanged(String? departmentKey) {
    setState(() {
      _selectedDepartmentKey = departmentKey;
      _selectedGradeKey = null;
      _academicSelectionNotice = null;
    });
  }

  void _onGradeChanged(String? gradeKey) {
    if (!mounted) return;
    setState(() {
      _selectedGradeKey = gradeKey;
      _academicSelectionNotice = null;
    });
  }

  void _applyProfile(UserProfile profile) {
    final derivedStudentId = extractStudentIdFromEmail(profile.email);
    _profile = profile;
    _nameController.text = profile.name;
    _studentIdController.text = profile.studentId ?? derivedStudentId ?? "";
    _ageController.text = profile.age?.toString() ?? "";
    _selectedGender = profile.gender;
    _selectedCampus = profile.campus;
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
        'campus': _selectedCampus,
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
      ..writeln('UID: ${uid.isEmpty ? "(bulunamadi)" : uid}')
      ..writeln('E-posta: ${email.isEmpty ? "(bulunamadi)" : email}')
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
                  "Profil bilgilerinizi doldurarak topluluktaki etkileşiminizi artırabilirsiniz.",
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
                  onChanged: _onFacultyChanged,
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
                        ? "Once fakulte secin."
                        : null,
                    prefixIcon: const Icon(Icons.apartment_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
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
                  onChanged: _selectedFacultyKey == null
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
                        ? "Once bolum secin."
                        : null,
                    prefixIcon: const Icon(Icons.format_list_numbered_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
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
                  onChanged: _selectedDepartmentKey == null
                      ? null
                      : _onGradeChanged,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('campus-$_selectedCampus'),
                  isExpanded: true,
                  initialValue: _selectedCampus,
                  decoration: InputDecoration(
                    labelText: "Yerleşke / Kampüs",
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  items: _campuses
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCampus = val),
                ),
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
