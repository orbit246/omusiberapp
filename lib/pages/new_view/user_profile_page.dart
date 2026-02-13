import 'package:flutter/material.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';
import 'package:omusiber/widgets/badge_widget.dart';

class UserProfilePage extends StatelessWidget {
  final UserProfile profile;

  const UserProfilePage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text("Profil"),
            backgroundColor: colorScheme.surface,
            surfaceTintColor: colorScheme.surfaceTint,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Header Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(
                        0.5,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage:
                              profile.photoUrl != null &&
                                  profile.photoUrl!.isNotEmpty
                              ? NetworkImage(profile.photoUrl!)
                              : null,
                          child:
                              profile.photoUrl == null ||
                                  profile.photoUrl!.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: colorScheme.onPrimaryContainer,
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          profile.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "@${profile.studentId}",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (profile.role != 'student') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              profile.role.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Badges Section
                  if (profile.badges.isNotEmpty) ...[
                    _buildSectionHeader(context, "Rozetler"),
                    const SizedBox(height: 12),
                    BadgeList(badges: profile.badges),
                    const SizedBox(height: 24),
                  ],

                  // Info Section
                  _buildSectionHeader(context, "Hakkında"),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    context,
                    icon: Icons.school_outlined,
                    label: "Öğrenci Numarası",
                    value: profile.studentId,
                  ),
                  if (profile.email != null)
                    _buildInfoTile(
                      context,
                      icon: Icons.email_outlined,
                      label: "E-posta",
                      value: profile.email!,
                    ),
                  if (profile.department != null &&
                      profile.department!.isNotEmpty)
                    _buildInfoTile(
                      context,
                      icon: Icons.school_outlined,
                      label: "Bölüm / Uzmanlık",
                      value: profile.department!,
                    ),
                  if (profile.campus != null && profile.campus!.isNotEmpty)
                    _buildInfoTile(
                      context,
                      icon: Icons.map_outlined,
                      label: "Yerleşke",
                      value: profile.campus!,
                    ),
                  if (profile.gender != null && profile.gender!.isNotEmpty)
                    _buildInfoTile(
                      context,
                      icon: Icons.wc_outlined,
                      label: "Cinsiyet",
                      value: profile.gender!,
                    ),
                  if (profile.age != null)
                    _buildInfoTile(
                      context,
                      icon: Icons.cake_outlined,
                      label: "Yaş",
                      value: profile.age!.toString(),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
