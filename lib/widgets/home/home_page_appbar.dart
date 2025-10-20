import 'package:flutter/material.dart';

class HomePageAppbar extends StatelessWidget {
  HomePageAppbar({super.key});

  final GlobalKey _profileKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.headlineMedium;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 3))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showSideMenu(context),
                child: const CircleAvatar(child: Icon(Icons.menu, size: 28)),
              ),
              const Spacer(),
              Text('Etkinlikler', style: text),
              const Spacer(),
              GestureDetector(
                key: _profileKey,
                onTap: () => _showProfileMenu(context),
                child: const CircleAvatar(child: Icon(Icons.person, size: 28)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSideMenu(BuildContext context) {
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
              borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: _SideMenu(onClose: () => Navigator.of(context).pop()),
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
    // Anchor the menu to the avatar
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = _profileKey.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(offset.dx, offset.dy, box.size.width, box.size.height);

    await showMenu(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size).shift(const Offset(0, 50)),
      menuPadding: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem<dynamic>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('Samet'),
            subtitle: const Text('samet@bytforge.com'),
            onTap: () => Navigator.pop(context),
          ),
        ),
        const PopupMenuDivider(height: 0),
        PopupMenuItem<dynamic>(
          child: const ListTile(leading: Icon(Icons.settings), title: Text('Ayarlar')),
          onTap: () => Navigator.pop(context),
        ),
        PopupMenuItem<dynamic>(
          child: const ListTile(leading: Icon(Icons.logout), title: Text('Çıkış yap')),
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _SideMenu extends StatelessWidget {
  final VoidCallback onClose;
  const _SideMenu({required this.onClose});

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
            child: Text('Menü', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: theme.onSurface)),
          ),
          ListTile(leading: const Icon(Icons.home), title: const Text('Ana Sayfa'), onTap: onClose),
          ListTile(leading: const Icon(Icons.event), title: const Text('Etkinliklerim'), onTap: onClose),
          ListTile(leading: const Icon(Icons.bookmark), title: const Text('Kaydedilenler'), onTap: onClose),
          const Divider(height: 0),
          ListTile(leading: const Icon(Icons.settings), title: const Text('Ayarlar'), onTap: onClose),
          ListTile(leading: const Icon(Icons.help_outline), title: const Text('Yardım'), onTap: onClose),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Çıkış yap'), onTap: onClose),
        ],
      ),
    );
  }
}
