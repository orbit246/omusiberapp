import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omusiber/backend/auth/auth_service.dart';
import 'package:omusiber/backend/theme_manager.dart';
import 'package:omusiber/backend/tab_badge_service.dart';
import 'package:omusiber/backend/user_profile_service.dart';
import 'package:omusiber/backend/view/user_profile_model.dart';
import 'package:omusiber/models/user_badge.dart';
import 'package:omusiber/widgets/badge_widget.dart';

import 'package:omusiber/pages/new_view/notifications_tab_view.dart';
import 'package:omusiber/pages/new_view/about_page.dart';
import 'package:omusiber/pages/new_view/feedback_page.dart';
import 'package:omusiber/backend/update_service.dart';
import 'dart:math';
import 'package:omusiber/pages/new_view/edit_profile_page.dart';

// SettingsPage must be a StatefulWidget to hold the initial random state for the easter egg
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final themeManager = ThemeManager();
  final AuthService _authService = AuthService();
  final UserProfileService _profileService = UserProfileService();

  // State to hold the result of the 1/1000 random chance
  bool _isEasterEggMode = false;

  // State to hold user badges
  List<UserBadge> _userBadges = [];
  bool _loadingBadges = false;
  bool _isPrivate = false;
  UserProfile? _userProfile;
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadUserBadges();
    _loadUserProfile();
  }

  /// Load user profile from Firestore or Backend
  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loadingProfile = true);

    try {
      final profile = await _profileService.fetchUserProfile(user.uid);
      if (mounted) {
        setState(() {
          if (profile != null) {
            _userProfile = profile;
            _isPrivate = profile.isPrivate;
          } else {
            // Default profile for Guest / First time
            _userProfile = UserProfile(
              uid: user.uid,
              studentId: user.isAnonymous
                  ? "misafir"
                  : (user.email?.split('@')[0] ?? "unknown"),
              name:
                  user.displayName ??
                  (user.isAnonymous ? "Misafir Kullanıcı" : "Öğrenci"),
              role: user.isAnonymous ? "guest" : "student",
              photoUrl: user.photoURL,
              email: user.email,
            );
            _isPrivate = false;
          }
          _loadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  /// Load user badges from backend
  Future<void> _loadUserBadges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _loadingBadges = true;
    });

    try {
      final badges = await _profileService.fetchUserBadges(user.uid);
      if (mounted) {
        setState(() {
          _userBadges = badges;
          _loadingBadges = false;
        });
      }
    } catch (e) {
      print('Error loading badges: $e');
      if (mounted) {
        setState(() {
          _loadingBadges = false;
        });
      }
    }
  }

  Future<void> _togglePrivacy(bool val) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isPrivate = val;
    });

    try {
      await _profileService.updatePrivacySetting(user.uid, val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              val ? "Profiliniz gizlendi." : "Profiliniz artık görünür.",
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isPrivate = !val;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gizlilik ayarı güncellenemedi.")),
        );
      }
    }
  }

  void _showPrivacyConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Profil Gizlensin mi?"),
        content: const Text(
          "Profilinizi gizlediğinizde, diğer kullanıcılar sizi öğrenci numarası ile arattığında bulamazlar. Devam etmek istiyor musunuz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _togglePrivacy(true);
            },
            child: const Text("Gizle"),
          ),
        ],
      ),
    );
  }

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
                          child: _loadingProfile
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Row(
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.isAnonymous
                                                    ? "Misafir Kullanıcı"
                                                    : (_userProfile?.name ??
                                                          user.displayName ??
                                                          "Kullanıcı"),
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                              Text(
                                                user.isAnonymous
                                                    ? "Anonim Hesap"
                                                    : (user.email ??
                                                          "E-posta yok"),
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                              if (_userProfile != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  "${_userProfile?.department ?? 'Bölüm belirtilmedi'} • ${_userProfile?.campus ?? 'Kampüs belirtilmedi'}",
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (_userProfile != null)
                                          IconButton(
                                            onPressed: () async {
                                              final updated =
                                                  await Navigator.of(
                                                    context,
                                                  ).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          EditProfilePage(
                                                            profile:
                                                                _userProfile!,
                                                          ),
                                                    ),
                                                  );
                                              if (updated == true) {
                                                _loadUserProfile();
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  colorScheme.surface,
                                              foregroundColor:
                                                  colorScheme.primary,
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Display badges
                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // Badges section
                                    if (_loadingBadges)
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      )
                                    else if (_userBadges.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Henüz rozetiniz yok',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: Colors.grey.shade600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.workspace_premium_rounded,
                                                size: 16,
                                                color: colorScheme.primary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Rozetler',
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color:
                                                          colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          BadgeList(badges: _userBadges),
                                        ],
                                      ),

                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),

                                    // Privacy Toggle
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Gizli Profil",
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              Text(
                                                "Aratıldığında profiliniz görünmez",
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: _isPrivate,
                                          onChanged: (val) {
                                            if (val) {
                                              _showPrivacyConfirmation();
                                            } else {
                                              _togglePrivacy(false);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),

                        // If Anonymous, allow upgrading/switching to Google
                        if (user.isAnonymous)
                          _buildSettingsTile(
                            context,
                            icon: Icons.login,
                            title: "Öğrenci Girişi Yap",
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
                      ] else ...[
                        // Should technically not be reached if main.dart forces Anon Login
                        // But keep it for safety.
                        _buildSettingsTile(
                          context,
                          icon: Icons.login,
                          title: "Giriş Yap (Öğrenci)",
                          subtitle: "Google ile giriş yapın",
                          onTap: () async {
                            try {
                              final user = await _authService
                                  .signInWithGoogle();
                              if (user == null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Giriş işlemi iptal edildi veya yapılandırma hatası oluştu.',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // --- App Settings Section ---
                      _buildSectionHeader(context, "Uygulama"),
                      _buildSettingsTile(
                        context,
                        icon: Icons.notifications_outlined,
                        title: "Bildirimler",
                        onTap: () {
                          TabBadgeService().markNotifsViewed();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                appBar: AppBar(
                                  title: const Text("Bildirimler"),
                                ),
                                body: const NotificationsTabView(),
                              ),
                            ),
                          );
                        },
                      ),
                      _buildSettingsTile(
                        context,
                        icon: Icons.language,
                        title: "Dil / Language",
                        subtitle: "Türkçe",
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Farklı Dil desteği yakında geliyor!",
                              ),
                            ),
                          );
                        },
                      ),
                      _buildSettingsTile(
                        context,
                        icon: Icons.system_update_outlined,
                        title: "Güncellemeleri Denetle",
                        onTap: () async {
                          final started = await UpdateService()
                              .checkForUpdate();
                          if (!started && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Sürümünüz güncel."),
                              ),
                            );
                          }
                        },
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
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (context) => const AboutBottomSheet(),
                          );
                        },
                      ),

                      _buildSettingsTile(
                        context,
                        icon: Icons.feedback_outlined,
                        title: "Geri Dönüş",
                        subtitle: "Hata bildirimi ve öneriler",
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const FeedbackPage(),
                            ),
                          );
                        },
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
}
