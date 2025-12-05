import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // We use CustomScrollView to allow for a collapsible "Large" AppBar
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              // This handles the back button automatically
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text("Ayarlar"),
            backgroundColor: colorScheme.surface,
            surfaceTintColor: colorScheme.surfaceTint,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- Account Section ---
                  _buildSectionHeader(context, "Hesap"),
                  _buildSettingsTile(
                    context,
                    icon: Icons.person_outline,
                    title: "Profil Düzenle",
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.lock_outline,
                    title: "Şifre ve Güvenlik",
                    onTap: () {},
                  ),

                  const SizedBox(height: 24),

                  // --- App Settings Section ---
                  _buildSectionHeader(context, "Uygulama"),
                  _buildSettingsTile(
                    context,
                    icon: Icons.notifications_outlined,
                    title: "Bildirimler",
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.language,
                    title: "Dil / Language",
                    subtitle: "Türkçe",
                    onTap: () {},
                  ),
                  
                  // Example of a Switch (Toggle)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.dark_mode_outlined, color: colorScheme.onSecondaryContainer),
                    ),
                    title: Text(
                      "Karanlık Mod",
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    trailing: Switch(
                      value: false, // Connect to your theme provider
                      onChanged: (val) {},
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Other Section ---
                  _buildSectionHeader(context, "Diğer"),
                  _buildSettingsTile(
                    context,
                    icon: Icons.info_outline,
                    title: "Hakkında",
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.logout,
                    title: "Çıkış Yap",
                    textColor: colorScheme.error,
                    iconColor: colorScheme.error,
                    onTap: () {},
                  ),
                  
                  // Bottom padding for scrolling
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for Section Headers
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0, left: 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  // Helper widget for Standard Settings Tiles
  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? colorScheme.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor ?? colorScheme.primary),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ),
    );
  }
}