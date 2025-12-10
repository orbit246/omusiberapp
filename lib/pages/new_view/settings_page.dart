import 'package:flutter/material.dart';
import 'package:omusiber/backend/theme_manager.dart';
import 'dart:math';

// SettingsPage must be a StatefulWidget to hold the initial random state for the easter egg
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final themeManager = ThemeManager();
  
  // State to hold the result of the 1/1000 random chance
  bool _isEasterEggMode = false;

  // Secret tap sequence variables removed.
  // int _tapCount = 0;
  // DateTime? _lastTapTime;

  // Secret tap handler function removed.

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
                  _buildSettingsTile(context, icon: Icons.person_outline, title: "Profil Düzenle", onTap: () {}),
                  _buildSettingsTile(context, icon: Icons.lock_outline, title: "Şifre ve Güvenlik", onTap: () {}),

                  const SizedBox(height: 24),

                  // --- App Settings Section ---
                  _buildSectionHeader(context, "Uygulama"),
                  _buildSettingsTile(context, icon: Icons.notifications_outlined, title: "Bildirimler", onTap: () {}),
                  _buildSettingsTile(
                    context,
                    icon: Icons.language,
                    title: "Dil / Language",
                    subtitle: "Türkçe",
                    onTap: () {},
                  ),

                  // Dark Mode Switch (Toggle)
                  // Wrapped in GestureDetector to capture long press to force the easter egg
                  GestureDetector(
                    onLongPress: () {
                      // 100% chance easter egg on long press
                      setState(() {
                        _isEasterEggMode = true; // Force easter egg mode ON
                      });

                      // Toggle the theme state as if the switch was pressed
                      final isCurrentlyDark = themeManager.themeMode == ThemeMode.dark;
                      themeManager.toggleTheme(!isCurrentlyDark);
                    },
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      // 2. The ListenableBuilder updates the icon dynamically based on theme mode
                      // and whether the easter egg mode is active.
                      leading: ListenableBuilder(
                        listenable: themeManager,
                        builder: (context, _) {
                          final isDarkMode = themeManager.themeMode == ThemeMode.dark;
                          Widget iconWidget;
                          final iconColor = colorScheme.onSecondaryContainer;
                          const iconSize = 24.0; // Increased size

                          if (_isEasterEggMode) {
                            // Easter egg mode is ON (1/1000 chance hit or long press)
                            // Assets now use the increased size and theme color tint.
                            iconWidget = isDarkMode
                                ? Image.asset('assets/cookie.png', height: iconSize, width: iconSize)
                                : Image.asset('assets/quarter_moon.png', height: iconSize, width: iconSize);
                          } else {
                            // Default mode (icon size also increased for consistency)
                            iconWidget = Icon(Icons.dark_mode_outlined, color: iconColor, size: iconSize);
                          }

                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Transform.rotate(angle: _isEasterEggMode ? 100 : 0, child: iconWidget),
                          );
                        },
                      ),
                      title: Text(
                        "Karanlık Mod",
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      trailing: ListenableBuilder(
                        listenable: themeManager,
                        builder: (context, _) {
                          return Switch(
                            // Check if current mode is Dark
                            value: themeManager.themeMode == ThemeMode.dark,
                            onChanged: (val) {
                              // PRIMARY CLICK: 1/1000 chance logic
                              // 1. Calculate 1/1000 chance for easter egg mode upon every toggle
                              final random = Random();
                              final newEasterEggMode = random.nextInt(1000) == 0;
                              
                              // 2. Update the easter egg state
                              setState(() {
                                _isEasterEggMode = newEasterEggMode;
                              });

                              // 3. Call the toggle function
                              themeManager.toggleTheme(val);
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Other Section ---
                  _buildSectionHeader(context, "Diğer"),
                  _buildSettingsTile(context, icon: Icons.info_outline, title: "Hakkında", onTap: () {}),
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500, color: textColor),
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ),
    );
  }
}