import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/auth/auth_service.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';
import 'package:omusiber/backend/theme_manager.dart';
import 'package:omusiber/backend/tab_badge_service.dart';
import 'package:omusiber/pages/new_view/edit_profile_page.dart';

import 'package:omusiber/pages/new_view/notifications_tab_view.dart';
import 'package:omusiber/pages/new_view/about_page.dart';
import 'package:omusiber/pages/new_view/feedback_page.dart';
import 'package:omusiber/backend/update_service.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final AppStartupController _startupController = AppStartupController.instance;

  // State to hold the result of the 1/1000 random chance
  bool _isEasterEggMode = false;

  Future<void> _handleGoogleSignIn() async {
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Giriş işlemi iptal edildi veya yapılandırma hatası oluştu.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      final user = await _authService.signInWithApple();
      if (user == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple ile giriş tamamlanamadı.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final notifications = SimpleNotifications();
      final alreadyGranted = await notifications.checkPermission();
      if (!mounted) return;

      if (alreadyGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim izni zaten açık.')),
        );
        return;
      }

      final granted = await notifications.requestPermission();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Bildirim izni verildi.'
                : 'Bildirim izni verilmedi. Ayarlardan daha sonra açabilirsin.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  bool get _canUseAppleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _openLegalDocument(String documentType) async {
    final uri = Uri.https('nortixlabs.com', '/akademiz/$documentType');
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;

    messenger.showSnackBar(
      SnackBar(content: Text('Belge açılamadı: ${uri.toString()}')),
    );
  }

  Future<void> _openCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => EditProfilePage(uid: user.uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // We use CustomScrollView to allow for a collapsible "Large" AppBar
      body: AnimatedBuilder(
        animation: _startupController,
        builder: (context, _) {
          if (!_startupController.isFirebaseReady) {
            return _buildSettingsBody(context, user: null, isAuthLoading: true);
          }

          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              return _buildSettingsBody(
                context,
                user: snapshot.data,
                isAuthLoading:
                    snapshot.connectionState == ConnectionState.waiting,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSettingsBody(
    BuildContext context, {
    required User? user,
    required bool isAuthLoading,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                if (isAuthLoading) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    title: Text(
                      "Hesap hazirlaniyor",
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: const Text(
                      "Bağlantı kurulurken ayarlar yükleniyor.",
                    ),
                  ),
                ] else if (isLoggedIn) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      user.isAnonymous
                          ? "Misafir Kullanıcı"
                          : (user.displayName ?? "Kullanıcı"),
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      user.isAnonymous
                          ? "Anonim Hesap"
                          : (user.email ?? "E-posta yok"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSettingsTile(
                    context,
                    icon: Icons.person_outline,
                    title: "Profilim",
                    subtitle: "Sınıf ve şube bilgilerini profilde gör",
                    onTap: _openCurrentProfile,
                  ),
                  if (user.isAnonymous)
                    Column(
                      children: [
                        _buildSettingsTile(
                          context,
                          icon: Icons.login,
                          title: "Giriş Yap",
                          subtitle: "Google ile giriş yapın",
                          onTap: _handleGoogleSignIn,
                        ),
                        if (_canUseAppleSignIn)
                          _buildSettingsTile(
                            context,
                            icon: Icons.apple,
                            title: "Apple ile Giriş Yap",
                            subtitle: "Apple hesabınızla devam edin",
                            onTap: _handleAppleSignIn,
                          ),
                      ],
                    ),
                ] else ...[
                  _buildSettingsTile(
                    context,
                    icon: Icons.login,
                    title: "Giriş Yap",
                    subtitle: "Google ile giriş yapın",
                    onTap: _handleGoogleSignIn,
                  ),
                  if (_canUseAppleSignIn)
                    _buildSettingsTile(
                      context,
                      icon: Icons.apple,
                      title: "Apple ile Giriş Yap",
                      subtitle: "Apple hesabınızla devam edin",
                      onTap: _handleAppleSignIn,
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
                          appBar: AppBar(title: const Text("Bildirimler")),
                          body: const NotificationsTabView(),
                        ),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.notifications_active_outlined,
                  title: "Bildirim izni",
                  subtitle: "Uygulama için bildirim iznini yönet",
                  onTap: _requestNotificationPermission,
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.language,
                  title: "Dil / Language",
                  subtitle: "Türkçe",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Farklı Dil desteği yakında geliyor!"),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.system_update_outlined,
                  title: "Güncellemeleri Denetle",
                  onTap: () async {
                    final started = await UpdateService().checkForUpdate();
                    if (!started && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Sürümünüz güncel.")),
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
                        final iconColor = colorScheme.onSecondaryContainer;
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
                            final newEasterEggMode = random.nextInt(1000) == 0;
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

                // --- Legal Documents Section ---
                _buildSectionHeader(context, "Legal Belgeler"),
                _buildSettingsTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: "Gizlilik Politikası",
                  subtitle: "nortixlabs.com/akademiz/privacy",
                  onTap: () => _openLegalDocument('privacy'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.description_outlined,
                  title: "Kullanım Şartları",
                  subtitle: "nortixlabs.com/akademiz/terms",
                  onTap: () => _openLegalDocument('terms'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.public_outlined,
                  title: "Açık Rıza Metni",
                  subtitle: "nortixlabs.com/akademiz/consent",
                  onTap: () => _openLegalDocument('consent'),
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
            color: (iconColor ?? colorScheme.primary).withValues(alpha: 0.1),
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
