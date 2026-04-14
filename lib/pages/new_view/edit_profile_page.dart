import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omusiber/backend/profile_identity.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';

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
  late final TextEditingController _departmentController;

  UserProfile? _profile;
  String? _selectedGender;
  String? _selectedCampus;
  String? _resolvedUid;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

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
    _departmentController = TextEditingController();

    final initialProfile = widget.initialProfile;
    if (initialProfile != null) {
      _applyProfile(initialProfile);
      _resolvedUid = initialProfile.uid;
      _isLoading = false;
    }

    _resolvedUid = widget.uid ?? _auth.currentUser?.uid;
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _ageController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
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
    });

    final profile = await _profileService.fetchUserProfile(uid);
    if (!mounted) return;

    if (profile == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'Profil bilgisi su anda yuklenemedi.';
      });
      return;
    }

    setState(() {
      _applyProfile(profile);
      _isLoading = false;
    });
  }

  void _applyProfile(UserProfile profile) {
    final derivedStudentId = extractStudentIdFromEmail(profile.email);
    _profile = profile;
    _nameController.text = profile.name;
    _studentIdController.text = profile.studentId ?? derivedStudentId ?? "";
    _ageController.text = profile.age?.toString() ?? "";
    _departmentController.text = profile.department ?? "";
    _selectedGender = profile.gender;
    _selectedCampus = profile.campus;
  }

  Future<void> _saveProfile() async {
    final uid = _resolvedUid;
    if (_profile == null || _isLoading || uid == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updates = {
        'name': _nameController.text.trim(),
        'studentId': _studentIdController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'department': _departmentController.text.trim(),
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Hata oluştu: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              onPressed: _loadProfile,
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
          const Expanded(
            child: Text(
              "Profil bilgilerinizi doldurarak topluluktaki etkileşiminizi artırabilirsiniz.",
              style: TextStyle(fontSize: 13),
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
                TextFormField(
                  controller: _departmentController,
                  decoration: InputDecoration(
                    labelText: "Bölüm / Uzmanlık (Örn: Bilgisayar Müh.)",
                    prefixIcon: const Icon(Icons.school_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  maxLength: 32,
                  validator: (val) {
                    if (val != null && val.length > 32) {
                      return "En fazla 32 karakter";
                    }
                    return null;
                  },
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
