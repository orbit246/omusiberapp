import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omusiber/backend/auth/auth_service.dart';
import 'package:omusiber/pages/new_view/edit_profile_page.dart';
import 'package:omusiber/pages/new_view/settings_page.dart';

class HomePageAppbar extends StatelessWidget {
  HomePageAppbar({super.key});

  final GlobalKey _profileKey = GlobalKey();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showSideMenu(context),
                child: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  child: Icon(
                    Icons.menu,
                    size: 28,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Etkinlikler',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: GoogleFonts.ptSans().fontFamily,
                ),
              ),
              const Spacer(),
              GestureDetector(
                key: _profileKey,
                onTap: () => _showProfileMenu(context),
                child: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 28,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSideMenu(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final width = MediaQuery.of(context).size.width;
    final panelWidth = width >= 480 ? 320.0 : width * 0.86;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerLeft,
        child: SafeArea(
          child: SizedBox(
            width: panelWidth,
            child: Material(
              elevation: 12,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: _SideMenu(
                onClose: () => Navigator.of(context).pop(),
                showLogout: user != null && !user.isAnonymous,
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) {
        final slide = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return SlideTransition(position: slide, child: child);
      },
    );
  }

  Future<void> _showProfileMenu(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = _profileKey.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      box.size.width,
      box.size.height,
    );

    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        rect,
        Offset.zero & overlay.size,
      ).shift(const Offset(0, 50)),
      menuPadding: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profilim'),
            subtitle: Text(
              user?.isAnonymous == true
                  ? 'Giris yaparak profilini ac'
                  : (user?.email ?? 'Profilini ac'),
            ),
          ),
        ),
        const PopupMenuDivider(height: 0),
        const PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Ayarlar'),
          ),
        ),
        if (user != null && !user.isAnonymous)
          const PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout),
              title: Text('Cikis yap'),
            ),
          ),
      ],
    );

    if (selection == null || !context.mounted) return;

    switch (selection) {
      case 'profile':
        await _openProfilePage(context);
        break;
      case 'settings':
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const SettingsPage()));
        break;
      case 'logout':
        await _authService.signOut();
        break;
    }
  }

  Future<void> _openProfilePage(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profili acmak icin once giris yapmalisin.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => EditProfilePage(uid: user.uid)),
    );
  }
}

class _SideMenu extends StatelessWidget {
  final VoidCallback onClose;
  final bool showLogout;

  const _SideMenu({required this.onClose, required this.showLogout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Container(
      color: theme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 140,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: theme.primary),
            alignment: Alignment.bottomLeft,
            child: Text(
              'MenÃ¼',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: theme.onSurface),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Ana Sayfa'),
            onTap: onClose,
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Etkinliklerim'),
            onTap: onClose,
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: const Text('Kaydedilenler'),
            onTap: onClose,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Ayarlar'),
            onTap: onClose,
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('YardÄ±m'),
            onTap: onClose,
          ),
          if (showLogout)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Ã‡Ä±kÄ±ÅŸ yap'),
              onTap: onClose,
            ),
        ],
      ),
    );
  }
}
