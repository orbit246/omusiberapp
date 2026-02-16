import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfile profile;
  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = UserProfileService();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _departmentController;

  String? _selectedGender;
  String? _selectedCampus;
  bool _isSaving = false;

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
    _nameController = TextEditingController(text: widget.profile.name);
    _ageController = TextEditingController(
      text: widget.profile.age?.toString() ?? "",
    );
    _departmentController = TextEditingController(
      text: widget.profile.department ?? "",
    );
    _selectedGender = widget.profile.gender;
    _selectedCampus = widget.profile.campus;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updates = {
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'department': _departmentController.text.trim(),
        'gender': _selectedGender,
        'campus': _selectedCampus,
      };

      await _profileService.updateUserProfile(widget.profile.uid, updates);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              onPressed: _saveProfile,
              icon: const Icon(Icons.check),
              tooltip: "Kaydet",
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
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
              ),
              const SizedBox(height: 24),

              Text(
                "Temel Bilgiler",
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Name field
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

              Row(
                children: [
                  // Age field
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  // Gender field
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedGender,
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
                      onChanged: (val) => setState(() => _selectedGender = val),
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

              // Department (Master)
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
                  if (val != null && val.length > 32)
                    return "En fazla 32 karakter";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campus
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedCampus,
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
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    "Değişiklikleri Kaydet",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }
}
