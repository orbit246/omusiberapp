import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omusiber/backend/auth/auth_service.dart';
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
  final AuthService _authService = AuthService();

  // State to hold the result of the 1/1000 random chance
  bool _isEasterEggMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // We use CustomScrollView to allow for a collapsible "Large" AppBar
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final isLoggedIn = user != null;

          return CustomScrollView(
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
                      if (isLoggedIn) ...[
                        // User Info Card
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: user.photoURL != null
                                    ? NetworkImage(user.photoURL!)
                                    : null,
                                child: user.photoURL == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName ?? "Kullanıcı",
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    Text(
                                      user.email ?? "Anonim",
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // _buildSettingsTile(context,
                        //     icon: Icons.person_outline,
                        //     title: "Profil Düzenle",
                        //     onTap: () {}),
                        // _buildSettingsTile(context,
                        //     icon: Icons.lock_outline,
                        //     title: "Şifre ve Güvenlik",
                        //     onTap: () {}),
                      ] else ...[
                        _buildSettingsTile(
                          context,
                          icon: Icons.login,
                          title: "Giriş Yap (Öğrenci)",
                          subtitle: "Google ile giriş yapın",
                          onTap: () async {
                            try {
                              await _authService.signInWithGoogle();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                        ),
                        _buildSettingsTile(
                          context,
                          icon: Icons.person_off_outlined,
                          title: "Misafir Girişi",
                          subtitle: "Kayıt olmadan devam et",
                          onTap: () => _showAnonLoginDialog(context),
                        ),
                      ],

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

                      // Dark Mode Switch (Toggle)
                      GestureDetector(
                        onLongPress: () {
                          // 100% chance easter egg on long press
                          setState(() {
                            _isEasterEggMode = true; // Force easter egg mode ON
                          });

                          // Toggle the theme state as if the switch was pressed
                          final isCurrentlyDark =
                              themeManager.themeMode == ThemeMode.dark;
                          themeManager.toggleTheme(!isCurrentlyDark);
                        },
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ListenableBuilder(
                            listenable: themeManager,
                            builder: (context, _) {
                              final isDarkMode =
                                  themeManager.themeMode == ThemeMode.dark;
                              Widget iconWidget;
                              final iconColor =
                                  colorScheme.onSecondaryContainer;
                              const iconSize = 24.0;

                              if (_isEasterEggMode) {
                                iconWidget = isDarkMode
                                    ? Image.asset(
                                        'assets/cookie.png',
                                        height: iconSize,
                                        width: iconSize,
                                      )
                                    : Image.asset(
                                        'assets/quarter_moon.png',
                                        height: iconSize,
                                        width: iconSize,
                                      );
                              } else {
                                iconWidget = Icon(
                                  Icons.dark_mode_outlined,
                                  color: iconColor,
                                  size: iconSize,
                                );
                              }

                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Transform.rotate(
                                  angle: _isEasterEggMode ? 100 : 0,
                                  child: iconWidget,
                                ),
                              );
                            },
                          ),
                          title: Text(
                            "Karanlık Mod",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: ListenableBuilder(
                            listenable: themeManager,
                            builder: (context, _) {
                              return Switch(
                                value: themeManager.themeMode == ThemeMode.dark,
                                onChanged: (val) {
                                  final random = Random();
                                  final newEasterEggMode =
                                      random.nextInt(1000) == 0;
                                  setState(() {
                                    _isEasterEggMode = newEasterEggMode;
                                  });
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
                      _buildSettingsTile(
                        context,
                        icon: Icons.info_outline,
                        title: "Hakkında",
                        onTap: () {},
                      ),

                      // Sign Out Button (Only if logged in)
                      if (isLoggedIn)
                        _buildSettingsTile(
                          context,
                          icon: Icons.logout,
                          title: "Çıkış Yap",
                          textColor: colorScheme.error,
                          iconColor: colorScheme.error,
                          onTap: () async {
                            await _authService.signOut();
                          },
                        ),

                      // Bottom padding for scrolling
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Header Builder
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

  // Tile Builder
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

  void _showAnonLoginDialog(BuildContext context) {
    bool tosAccepted = false;
    bool privacyAccepted = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Misafir Girişi"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Misafir olarak devam etmek için aşağıdaki sözleşmeleri kabul etmelisiniz.",
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text("Hizmet Şartları'nı kabul ediyorum"),
                    value: tosAccepted,
                    onChanged: (val) {
                      setState(() => tosAccepted = val ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text("Gizlilik Politikası'nı kabul ediyorum"),
                    value: privacyAccepted,
                    onChanged: (val) {
                      setState(() => privacyAccepted = val ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("İptal"),
                ),
                FilledButton(
                  onPressed: (tosAccepted && privacyAccepted)
                      ? () async {
                          Navigator.pop(context); // Close dialog
                          try {
                            await _authService.signInAnonymously(
                              acceptedTos: tosAccepted,
                              acceptedPrivacy: privacyAccepted,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        }
                      : null,
                  child: const Text("Devam Et"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
