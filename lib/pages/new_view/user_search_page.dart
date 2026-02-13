import 'package:flutter/material.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';
import 'package:omusiber/pages/new_view/user_profile_page.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final UserProfileService _profileService = UserProfileService();

  bool _isSearching = false;
  UserProfile? _result;
  String? _error;

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _result = null;
    });

    try {
      final user = await _profileService.searchUserByStudentId(query);
      if (mounted) {
        setState(() {
          _result = user;
          _isSearching = false;
          if (user == null) {
            _error = "Öğrenci bulunamadı.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _error = "Arama sırasında bir hata oluştu.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kullanıcı Ara"),
        elevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Öğrenci Numarası (Örn: 21060xxx)",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _performSearch,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              onSubmitted: (_) => _performSearch(),
              textInputAction: TextInputAction.search,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Results Area
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildErrorState(theme)
                  : _result != null
                  ? _buildResultCard(context, theme)
                  : _buildInitialState(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "Öğrenci numarası ile arama yapın",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: theme.colorScheme.error.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, ThemeData theme) {
    final user = _result!;
    return Column(
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UserProfilePage(profile: user),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: user.photoUrl == null || user.photoUrl!.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user.studentId,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
