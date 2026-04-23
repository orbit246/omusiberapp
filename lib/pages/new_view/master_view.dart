import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';
import 'package:omusiber/backend/tab_badge_service.dart';
import 'package:omusiber/backend/startup_logger.dart';
import 'package:omusiber/pages/new_view/events_tab_view.dart';
import 'package:omusiber/pages/new_view/news_tab_view.dart';
import 'package:omusiber/pages/new_view/notifications_tab_view.dart';
import 'package:omusiber/pages/new_view/notes_placeholder_page.dart';
import 'package:omusiber/pages/new_view/notes_tab_view.dart';
import 'package:omusiber/pages/new_view/community_tab_view.dart';
import 'package:omusiber/backend/update_service.dart';

import 'package:omusiber/pages/new_view/settings_page.dart';
import 'package:omusiber/pages/new_view/food_menu_page.dart';
import 'package:omusiber/pages/schedule_page.dart';
import 'package:omusiber/pages/new_view/academic_calendar_page.dart';
import 'package:omusiber/pages/new_view/edit_profile_page.dart';
import 'package:omusiber/widgets/profile/account_profile_entry.dart';

class MasterView extends StatefulWidget {
  const MasterView({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<MasterView> createState() => _MasterViewState();
}

class _MasterViewState extends State<MasterView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _appBarTitle = "Haberler";

  // News, Events, Community
  final List<bool> _unreadStates = [true, false, false];
  bool _unreadNotifications = false;
  final List<Widget?> _tabBodies = List<Widget?>.filled(3, null);

  final TabBadgeService _badgeService = TabBadgeService();
  final AppStartupController _startupController = AppStartupController.instance;
  static const Duration _notificationsInitDelay = Duration(seconds: 15);
  static const Duration _permissionReminderDelay = Duration(seconds: 10);
  static const Duration _updateCheckDelay = Duration(seconds: 12);
  static const Duration _updateCheckScheduleDelay = Duration(seconds: 10);
  bool _notificationsInitialized = false;
  bool _notificationsInitScheduled = false;
  bool _updateCheckScheduled = false;
  Timer? _notificationsInitTimer;
  Timer? _permissionReminderStartTimer;
  Timer? _permissionReminderTimer;
  Timer? _updateCheckStartTimer;
  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();
    StartupLogger.log(
      'MasterView.initState() initialTabIndex=${widget.initialTabIndex}',
    );
    _appBarTitle = _titleForIndex(widget.initialTabIndex);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabBodies[widget.initialTabIndex] = _buildTabBodyForIndex(
      widget.initialTabIndex,
    );

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _handleTabSelection(_tabController.index);
      }
    });

    _startupController.addListener(_handleStartupChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _permissionReminderStartTimer?.cancel();
      _permissionReminderStartTimer = Timer(_permissionReminderDelay, () {
        if (!mounted) return;
        _startPermissionReminder();
      });
      _handleStartupChanged();
      _scheduleUpdateCheckAfterStartupBreath();
    });
  }

  void _handleStartupChanged() {
    if (!_startupController.isFirebaseReady ||
        _notificationsInitialized ||
        _notificationsInitScheduled) {
      return;
    }

    _notificationsInitScheduled = true;
    final delay = _startupController.startupDeferral(_notificationsInitDelay);
    _notificationsInitTimer?.cancel();
    if (delay == Duration.zero) {
      _notificationsInitialized = true;
      unawaited(SimpleNotifications().init());
      return;
    }
    _notificationsInitTimer = Timer(delay, () {
      if (!mounted || _notificationsInitialized) {
        return;
      }
      _notificationsInitialized = true;
      unawaited(SimpleNotifications().init());
    });
  }

  void _scheduleUpdateCheck() {
    final delay = _startupController.startupDeferral(_updateCheckDelay);
    _updateCheckTimer?.cancel();
    if (delay == Duration.zero) {
      if (!mounted) return;
      UpdateService().checkForUpdate();
      return;
    }
    _updateCheckTimer = Timer(delay, () {
      if (!mounted) return;
      UpdateService().checkForUpdate();
    });
  }

  void _scheduleUpdateCheckAfterStartupBreath() {
    if (_updateCheckScheduled) {
      return;
    }

    _updateCheckScheduled = true;
    _updateCheckStartTimer?.cancel();
    _updateCheckStartTimer = Timer(_updateCheckScheduleDelay, () {
      if (!mounted) return;
      _scheduleUpdateCheck();
    });
  }

  void _startPermissionReminder() {
    _permissionReminderTimer?.cancel();
    _permissionReminderTimer = Timer(const Duration(seconds: 30), () async {
      if (!mounted) return;
      final hasPermission = await SimpleNotifications().checkPermission();
      if (!hasPermission && mounted) {
        _showPermissionBanner();
      }
    });
  }

  void _showPermissionBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        elevation: 1,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: Icon(
          Icons.notifications_active_outlined,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        content: Text(
          "Önemli duyurulardan haberdar olmak için bildirimleri açın.",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text("BİRAZDAN"),
          ),
          TextButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              await SimpleNotifications().requestPermission();
            },
            child: const Text("ŞİMDİ AÇ"),
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return "Etkinlikler";
      case 2:
        return "Topluluk";
      case 0:
      default:
        return "Haberler";
    }
  }

  void _handleTabSelection(int index) {
    setState(() {
      _tabBodies[index] ??= _buildTabBodyForIndex(index);
      _appBarTitle = _titleForIndex(index);
      switch (index) {
        case 0:
          _badgeService.markNewsViewed();
          break;
        case 1:
          _badgeService.markEventsViewed();
          break;
        case 2:
          _badgeService.markCommunityViewed();
          break;
      }
      if (_unreadStates[index]) {
        _unreadStates[index] = false;
      }
    });
  }

  Widget _buildTabBodyForIndex(int index) {
    switch (index) {
      case 1:
        return const EventsTabView();
      case 2:
        return const CommunityTabView();
      case 0:
      default:
        return const NewsTabView();
    }
  }

  void _openSettingsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SettingsPage()));
  }

  void _openCurrentProfile() {
    if (!_startupController.isFirebaseReady) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _openSettingsPage();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => EditProfilePage(uid: user.uid)),
    );
  }

  void _openAcademicCalendarSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: const AcademicCalendarPage(),
      ),
    );
  }

  void _openNotificationsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text("Bildirimler")),
          body: const NotificationsTabView(),
        ),
      ),
    );
    _badgeService.markNotifsViewed();
    setState(() => _unreadNotifications = false);
  }

  void _openGradesPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NotesPlaceholderPage()),
    );
  }

  void _openMyNotesPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotesTabView(showAppBar: true),
      ),
    );
  }

  Widget _buildBadgedTab({required String text, required int index}) {
    return Tab(text: text);
  }

  Color _tabAccentColor(int index, ColorScheme colorScheme) {
    return switch (index) {
      1 => const Color(0xFFE5484D),
      2 => const Color(0xFFF97316),
      _ => colorScheme.primary,
    };
  }

  Widget _buildDrawerHeader(
    BuildContext context, {
    required User? user,
    required bool isAuthLoading,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1A2435),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A4D6B)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AccountProfileEntry(
            user: user,
            isAuthLoading: isAuthLoading,
            variant: AccountProfileEntryVariant.drawer,
            onGuestTap: () {
              Navigator.of(context).pop();
              _openCurrentProfile();
            },
            onProfileTap: () {
              Navigator.of(context).pop();
              _openCurrentProfile();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerContent(
    BuildContext context, {
    required User? user,
    required bool isAuthLoading,
  }) {
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context, user: user, isAuthLoading: isAuthLoading),
          _buildDrawerDivider(),
          _buildDrawerSectionTitle(context, "Akademik"),
          _buildDrawerTile(
            context: context,
            icon: Icons.calendar_month_outlined,
            title: "Ders Programı",
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SchedulePage()),
              );
            },
          ),
          _buildDrawerTile(
            context: context,
            icon: Icons.description_rounded,
            title: "Akademik\nTakvim",
            onTap: () {
              Navigator.of(context).pop();
              _openAcademicCalendarSheet();
            },
          ),
          _buildDrawerTile(
            context: context,
            icon: Icons.edit_note_rounded,
            title: "Notlar",
            onTap: () {
              Navigator.of(context).pop();
              _openGradesPage();
            },
          ),
          _buildDrawerSectionTitle(context, "Kampüs"),
          _buildDrawerTile(
            context: context,
            icon: Icons.restaurant_menu_rounded,
            title: "Yemek Menüsü",
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const FoodMenuPage()),
              );
            },
          ),
          _buildDrawerTile(
            context: context,
            icon: Icons.edit_note_rounded,
            title: "Notlarım",
            onTap: () {
              Navigator.of(context).pop();
              _openMyNotesPage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 24, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFF4385F5),
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _buildDrawerDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Color(0xFF31415D), thickness: 1),
    );
  }

  Widget _buildDrawerTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: const Color(0xFF1A2435),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF3A4D6B), width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 22, color: const Color(0xFFAEB8C8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFD8DEE9),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: Color(0xFF63718A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShellButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
    Widget? child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: child ?? Icon(icon, size: 20, color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _startupController.removeListener(_handleStartupChanged);
    _notificationsInitTimer?.cancel();
    _permissionReminderStartTimer?.cancel();
    _permissionReminderTimer?.cancel();
    _updateCheckStartTimer?.cancel();
    _updateCheckTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tabAccentColor = _tabAccentColor(_tabController.index, colorScheme);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: Drawer(
        width: MediaQuery.of(context).size.width.clamp(0, 258).toDouble(),
        shape: const RoundedRectangleBorder(),
        backgroundColor: const Color(0xFF1F2D46),
        child: AnimatedBuilder(
          animation: _startupController,
          builder: (context, _) {
            if (!_startupController.isFirebaseReady) {
              return _buildDrawerContent(
                context,
                user: null,
                isAuthLoading: true,
              );
            }

            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                return _buildDrawerContent(
                  context,
                  user: snapshot.data,
                  isAuthLoading:
                      snapshot.connectionState == ConnectionState.waiting,
                );
              },
            );
          },
        ),
      ),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        leadingWidth: 58,
        leading: Builder(
          builder: (context) => Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: _buildShellButton(
                context: context,
                icon: Icons.menu_rounded,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Text(
            _appBarTitle,
            key: ValueKey(_appBarTitle),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildShellButton(
              context: context,
              icon: Icons.notifications_outlined,
              onPressed: _openNotificationsPage,
              child: Badge(
                isLabelVisible: _unreadNotifications,
                smallSize: 8,
                child: Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildShellButton(
              context: context,
              icon: Icons.settings_outlined,
              onPressed: _openSettingsPage,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(71),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 3, 12, 12),
            child: Container(
              height: 54,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.38),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: tabAccentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: tabAccentColor.withValues(alpha: 0.24),
                  ),
                ),
                labelColor: tabAccentColor,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                labelPadding: EdgeInsets.zero,
                splashBorderRadius: BorderRadius.circular(18),
                overlayColor: WidgetStatePropertyAll(
                  tabAccentColor.withValues(alpha: 0.06),
                ),
                onTap: (index) => _handleTabSelection(index),
                tabs: [
                  _buildBadgedTab(text: "Haberler", index: 0),
                  _buildBadgedTab(text: "Etkinlikler", index: 1),
                  _buildBadgedTab(text: "Topluluk", index: 2),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _MasterBackgroundBlobs(accentColor: tabAccentColor),
          IndexedStack(
            index: _tabController.index,
            children: List<Widget>.generate(3, (index) {
              return _tabBodies[index] ?? const SizedBox.expand();
            }),
          ),
        ],
      ),
    );
  }
}

class _MasterBackgroundBlobs extends StatelessWidget {
  const _MasterBackgroundBlobs({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: CustomPaint(
        painter: _MasterBackgroundBlobPainter(
          primary: accentColor,
          secondary: Color.lerp(accentColor, colorScheme.secondary, 0.35)!,
          tertiary: Color.lerp(accentColor, colorScheme.tertiary, 0.45)!,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MasterBackgroundBlobPainter extends CustomPainter {
  const _MasterBackgroundBlobPainter({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = primary.withValues(alpha: 0.11);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.04, size.height * 0.06)
        ..cubicTo(
          size.width * 0.28,
          size.height * -0.02,
          size.width * 0.48,
          size.height * 0.08,
          size.width * 0.43,
          size.height * 0.24,
        )
        ..cubicTo(
          size.width * 0.37,
          size.height * 0.42,
          size.width * 0.10,
          size.height * 0.34,
          size.width * 0.02,
          size.height * 0.22,
        )
        ..cubicTo(
          size.width * -0.04,
          size.height * 0.14,
          size.width * -0.02,
          size.height * 0.09,
          size.width * 0.04,
          size.height * 0.06,
        )
        ..close(),
      paint,
    );

    paint.color = secondary.withValues(alpha: 0.095);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.78, size.height * 0.22)
        ..cubicTo(
          size.width * 1.02,
          size.height * 0.12,
          size.width * 1.10,
          size.height * 0.42,
          size.width * 0.94,
          size.height * 0.58,
        )
        ..cubicTo(
          size.width * 0.78,
          size.height * 0.74,
          size.width * 0.58,
          size.height * 0.58,
          size.width * 0.62,
          size.height * 0.40,
        )
        ..cubicTo(
          size.width * 0.65,
          size.height * 0.30,
          size.width * 0.70,
          size.height * 0.25,
          size.width * 0.78,
          size.height * 0.22,
        )
        ..close(),
      paint,
    );

    paint.color = tertiary.withValues(alpha: 0.085);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.22, size.height * 0.78)
        ..cubicTo(
          size.width * 0.44,
          size.height * 0.66,
          size.width * 0.70,
          size.height * 0.80,
          size.width * 0.62,
          size.height * 0.98,
        )
        ..cubicTo(
          size.width * 0.55,
          size.height * 1.14,
          size.width * 0.20,
          size.height * 1.08,
          size.width * 0.10,
          size.height * 0.94,
        )
        ..cubicTo(
          size.width * 0.04,
          size.height * 0.86,
          size.width * 0.10,
          size.height * 0.81,
          size.width * 0.22,
          size.height * 0.78,
        )
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MasterBackgroundBlobPainter oldDelegate) {
    return primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        tertiary != oldDelegate.tertiary;
  }
}
