import 'package:flutter/material.dart';

class HomePageAppbar extends StatefulWidget {
  const HomePageAppbar({super.key});

  @override
  State<HomePageAppbar> createState() => _HomePageAppbarState();
}

class _HomePageAppbarState extends State<HomePageAppbar>
    with TickerProviderStateMixin {
  // ===== Cached inherited data (filled in didChangeDependencies) =====
  MediaQueryData? _media;
  ThemeData? _theme;

  // ===== Profile popover state =====
  final LayerLink _profileLink = LayerLink();
  OverlayEntry? _profileEntry;

  // ===== Side menu state & animations =====
  OverlayEntry? _menuEntry;
  late AnimationController _menuController;
  late Animation<double> _dimAnimation;
  late Animation<Offset> _slideAnimation;

  // ---------------- LIFECYCLE ----------------
  @override
  void initState() {
    super.initState();
    _menuController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _dimAnimation = CurvedAnimation(parent: _menuController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _menuController, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SAFELY capture inherited widgets here (recommended by the error message)
    _media = MediaQuery.of(context);
    _theme = Theme.of(context);
  }

  @override
  void dispose() {
    // Remove overlays without doing any ancestor lookups
    _profileEntry?.remove();
    _profileEntry = null;
    _menuEntry?.remove();
    _menuEntry = null;

    _menuController.dispose();
    super.dispose();
  }

  // ---------------- PROFILE POPOVER ----------------
  void _showProfilePopover() {
    if (_profileEntry != null || _media == null || _theme == null) return;

    // Use cached media/theme; do NOT read from context here.
    final media = _media!;
    final theme = _theme!;
    final overlay = Overlay.of(context, rootOverlay: true);

    _profileEntry = OverlayEntry(
      builder: (_) => MediaQuery(
        data: media,
        child: Theme(
          data: theme,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ModalBarrier(
                  dismissible: true,
                  color: Colors.transparent,
                ),
              ),
              CompositedTransformFollower(
                link: _profileLink,
                showWhenUnlinked: false,
                offset: const Offset(-200, 50),
                child: Material(
                  type: MaterialType.transparency,
                  child: _Bubble(
                    // _Bubble itself uses Theme via the injected Theme wrapper above
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: const Text("Samet"),
                          subtitle: const Text("mail@mail.com"),
                          onTap: _hideProfilePopover,
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.settings),
                          title: const Text("Ayarlar"),
                          onTap: _hideProfilePopover,
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text("Çıkış yap"),
                          onTap: _hideProfilePopover,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    overlay.insert(_profileEntry!);
  }

  void _hideProfilePopover() {
    _profileEntry?.remove();
    _profileEntry = null;
  }

  // ---------------- SIDE MENU (LEFT OVERLAY) ----------------
  void _showSideMenu() {
    if (_menuEntry != null || _media == null || _theme == null) return;

    final media = _media!;
    final theme = _theme!;
    final overlay = Overlay.of(context, rootOverlay: true);

    final width = media.size.width;
    final panelWidth = width >= 480 ? 320.0 : width * 0.86;

    _menuEntry = OverlayEntry(
      builder: (_) => MediaQuery(
        data: media,
        child: Theme(
          data: theme,
          child: _SideMenuOverlay(
            dimAnimation: _dimAnimation,
            slideAnimation: _slideAnimation,
            panelWidth: panelWidth,
            onClose: _hideSideMenu,
            child: _SideMenuContent(onClose: _hideSideMenu),
            onDragUpdate: (dx) {
              if (!mounted) return;
              final delta = -dx / panelWidth;
              _menuController.value =
                  (_menuController.value + delta).clamp(0.0, 1.0);
            },
            onDragEnd: (vx) async {
              final shouldClose = vx < -300 || _menuController.value < 0.5;
              if (!mounted) return;
              if (shouldClose) {
                await _menuController.reverse();
                _hideSideMenu();
              } else {
                _menuController.forward();
              }
            },
          ),
        ),
      ),
    );

    overlay.insert(_menuEntry!);
    if (mounted) _menuController.forward(from: 0);
  }

  void _hideSideMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: _showSideMenu,
          child: const CircleAvatar(child: Icon(Icons.menu, size: 28)),
        ),
        const Spacer(),
        Text("Etkinlikler", style: Theme.of(context).textTheme.headlineMedium),
        const Spacer(),
        CompositedTransformTarget(
          link: _profileLink,
          child: GestureDetector(
            onTap: () => (_profileEntry == null)
                ? _showProfilePopover()
                : _hideProfilePopover(),
            child: const CircleAvatar(child: Icon(Icons.person, size: 28)),
          ),
        ),
      ],
    );
  }
}

// ===== Side Menu overlay scaffolding =====

class _SideMenuOverlay extends StatelessWidget {
  final Animation<double> dimAnimation;
  final Animation<Offset> slideAnimation;
  final double panelWidth;
  final VoidCallback onClose;
  final Widget child;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  const _SideMenuOverlay({
    required this.dimAnimation,
    required this.slideAnimation,
    required this.panelWidth,
    required this.onClose,
    required this.child,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dim background (tap to dismiss)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: dimAnimation,
            builder: (_, __) => GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: Colors.black.withOpacity(0.22 * dimAnimation.value),
              ),
            ),
          ),
        ),

        // Sliding panel from LEFT
        Align(
          alignment: Alignment.centerLeft,
          child: SlideTransition(
            position: slideAnimation,
            child: SizedBox(
              width: panelWidth,
              child: SafeArea(
                child: Material(
                  elevation: 12,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => onDragUpdate(d.delta.dx),
                    onHorizontalDragEnd: (d) => onDragEnd(d.primaryVelocity ?? 0),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SideMenuContent extends StatelessWidget {
  final VoidCallback onClose;
  const _SideMenuContent({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: 140,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: primary),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              "Menü",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: onPrimary),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text("Ana Sayfa"),
          onTap: onClose,
        ),
        ListTile(
          leading: const Icon(Icons.event),
          title: const Text("Etkinliklerim"),
          onTap: onClose,
        ),
        ListTile(
          leading: const Icon(Icons.bookmark),
          title: const Text("Kaydedilenler"),
          onTap: onClose,
        ),
        const Divider(height: 0),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text("Ayarlar"),
          onTap: onClose,
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text("Yardım"),
          onTap: onClose,
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text("Çıkış yap"),
          onTap: onClose,
        ),
      ],
    );
  }
}

// ===== Bubble (for the profile popover) =====

class _Bubble extends StatelessWidget {
  final Widget child;
  const _Bubble({required this.child});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).cardColor;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(20, 10),
            painter: _TrianglePainter(color: bg),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(blurRadius: 18, color: Colors.black26)],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
