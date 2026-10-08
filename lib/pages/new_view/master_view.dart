import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/notifications/notification_navigation_intent.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';
import 'package:omusiber/backend/tab_badge_service.dart';
import 'package:omusiber/backend/startup_logger.dart';
import 'package:omusiber/pages/new_view/events_tab_view.dart';
import 'package:omusiber/pages/new_view/news_tab_view.dart';
import 'package:omusiber/pages/new_view/notifications_tab_view.dart';
import 'package:omusiber/pages/new_view/notes_placeholder_page.dart';
import 'package:omusiber/pages/new_view/notes_tab_view.dart';
import 'package:omusiber/pages/new_view/exam_schedule_page.dart';
import 'package:omusiber/pages/new_view/community_tab_view.dart';
import 'package:omusiber/pages/new_view/today_page.dart';
import 'package:omusiber/backend/update_service.dart';

import 'package:omusiber/pages/new_view/settings_page.dart';
import 'package:omusiber/pages/new_view/food_menu_page.dart';
import 'package:omusiber/pages/schedule_page.dart';
import 'package:omusiber/pages/new_view/academic_calendar_page.dart';
import 'package:omusiber/pages/new_view/edit_profile_page.dart';
import 'package:omusiber/widgets/profile/account_profile_entry.dart';
import 'package:omusiber/widgets/shared/navbar.dart';

class MasterView extends StatefulWidget {
  const MasterView({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<MasterView> createState() => _MasterViewState();
}

class _MasterViewState extends State<MasterView>
    with SingleTickerProviderStateMixin {
  static final DateTime _temporaryExamMenuEndsAt = DateTime(2026, 6, 21);
  bool _showHeader = true;
  double _headerScrollAccumulator = 0;
  static const double _headerHideDistance = 32;
  static const double _headerShowDistance = 10;
  late TabController _tabController;
  String _appBarTitle = 'Bugün';

  // Today, News, Events, Community
  final List<bool> _unreadStates = [false, true, false, false];
  bool _unreadNotifications = false;
  final List<Widget?> _tabBodies = List<Widget?>.filled(4, null);

  final TabBadgeService _badgeService = TabBadgeService();
  final AppStartupController _startupController = AppStartupController.instance;
  static const Duration _notificationsInitDelay = Duration(seconds: 15);
  static const Duration _updateCheckDelay = Duration(seconds: 12);
  static const Duration _updateCheckScheduleDelay = Duration(seconds: 10);
  bool _notificationsInitialized = false;
  bool _notificationsInitScheduled = false;
  bool _updateCheckScheduled = false;
  bool _updatePromptVisible = false;
  Timer? _notificationsInitTimer;
  Timer? _updateCheckStartTimer;
  Timer? _updateCheckTimer;
  StreamSubscription<int>? _notificationNavigationSubscription;

  @override
  void initState() {
    super.initState();
    final launchTabIndex = NotificationNavigationIntentService.instance
        .consumePendingTabIndex();
    final initialTabIndex = launchTabIndex ?? widget.initialTabIndex;
    StartupLogger.log(
      'MasterView.initState() initialTabIndex=$initialTabIndex',
    );
    _appBarTitle = _titleForIndex(initialTabIndex);
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialTabIndex,
    );
    _tabBodies[initialTabIndex] = _buildTabBodyForIndex(initialTabIndex);

    _notificationNavigationSubscription = NotificationNavigationIntentService
        .instance
        .tabIndexStream
        .listen(_openTabFromNotification);

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
      final pendingTabIndex = NotificationNavigationIntentService.instance
          .consumePendingTabIndex();
      if (pendingTabIndex != null) {
        _openTabFromNotification(pendingTabIndex);
      }
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
      unawaited(_runUpdateCheck());
      return;
    }
    _updateCheckTimer = Timer(delay, () {
      if (!mounted) return;
      unawaited(_runUpdateCheck());
    });
  }

  Future<void> _runUpdateCheck() async {
    final result = await UpdateService().checkForUpdate();
    if (!mounted || result.status != UpdateCheckStatus.updateAvailable) {
      return;
    }
    await _showUpdateAvailableDialog();
  }

  Future<void> _showUpdateAvailableDialog() async {
    if (_updatePromptVisible || !mounted) {
      return;
    }

    _updatePromptVisible = true;
    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Guncelleme hazir'),
          content: const Text(
            'Uygulamanin yeni bir surumu mevcut. Simdi guncellemek ister misin?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Daha sonra'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guncelle'),
            ),
          ],
        );
      },
    );

    _updatePromptVisible = false;
    if (shouldUpdate != true || !mounted) {
      return;
    }

    final result = await UpdateService().startUpdate();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  bool get _shouldShowTemporaryExamMenu {
    return DateTime.now().isBefore(_temporaryExamMenuEndsAt);
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

  void _handleTabSelection(int index) {
    setState(() {
      // Every page change starts with the shell header visible.
      _showHeader = true;
      _headerScrollAccumulator = 0;
      _tabBodies[index] ??= _buildTabBodyForIndex(index);
      _appBarTitle = _titleForIndex(index);
      switch (index) {
        case 1:
          _badgeService.markNewsViewed();
          break;
        case 2:
          _badgeService.markEventsViewed();
          break;
        case 3:
          _badgeService.markCommunityViewed();
          break;
      }
      if (_unreadStates[index]) {
        _unreadStates[index] = false;
      }
    });
  }

  String _titleForIndex(int index) {
    return switch (index) {
      1 => 'Haberler',
      2 => 'Etkinlikler',
      3 => 'Topluluk',
      _ => 'Bugün',
    };
  }

  void _openTabFromNotification(int index) {
    if (!mounted || index < 0 || index >= _tabController.length) {
      return;
    }

    if (_tabController.index == index) {
      _handleTabSelection(index);
      return;
    }

    _tabBodies[index] ??= _buildTabBodyForIndex(index);
    _tabController.animateTo(index);
  }

  void _selectTab(int index) {
    if (_tabController.index == index) {
      _handleTabSelection(index);
      return;
    }

    _tabBodies[index] ??= _buildTabBodyForIndex(index);
    _tabController.animateTo(index);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    // A new gesture starts a fresh direction decision. This prevents a
    // previous downward scroll from carrying into a later elastic rebound.
    if (notification is ScrollStartNotification) {
      _headerScrollAccumulator = 0;
      return false;
    }

    if (notification is ScrollEndNotification) {
      _headerScrollAccumulator = 0;
      return false;
    }

    // Scroll updates without drag details are ballistic/programmatic updates
    // (including the bounce-back after elastic overscroll). They do not count
    // as the user intentionally scrolling upward.
    if (notification is! ScrollUpdateNotification ||
        notification.dragDetails == null ||
        notification.metrics.outOfRange) {
      return false;
    }

    final scrollDelta = notification.scrollDelta;
    if (scrollDelta == null || scrollDelta == 0) {
      return false;
    }

    if (scrollDelta > 0) {
      _headerScrollAccumulator =
          (_headerScrollAccumulator > 0 ? _headerScrollAccumulator : 0) +
          scrollDelta;
      if (_showHeader && _headerScrollAccumulator >= _headerHideDistance) {
        _headerScrollAccumulator = 0;
        setState(() => _showHeader = false);
      }
    } else {
      _headerScrollAccumulator =
          (_headerScrollAccumulator < 0 ? _headerScrollAccumulator : 0) +
          scrollDelta;
      if (!_showHeader && _headerScrollAccumulator <= -_headerShowDistance) {
        _headerScrollAccumulator = 0;
        setState(() => _showHeader = true);
      }
    }

    return false;
  }

  Widget _buildTabBodyForIndex(int index) {
    switch (index) {
      case 0:
        return TodayPage(onOpenPage: _selectTab);
      case 2:
        return const EventsTabView();
      case 3:
        return const CommunityTabView();
      case 1:
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

  void _openAttendancePage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotesPlaceholderPage(
          title: 'Devamsızlıklar',
          icon: Icons.fact_check_outlined,
        ),
      ),
    );
  }

  void _openMyNotesPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotesTabView(showAppBar: true),
      ),
    );
  }

  Color _tabAccentColor(int index, ColorScheme colorScheme) {
    return NavigationSurface.accentColor(index, colorScheme);
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
          if (_shouldShowTemporaryExamMenu)
            _buildDrawerTile(
              context: context,
              icon: Icons.fact_check_rounded,
              title: "Sınav\nTakvimi",
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ExamSchedulePage(),
                  ),
                );
              },
            ),
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
          _buildDrawerTile(
            context: context,
            icon: Icons.fact_check_outlined,
            title: "Devamsızlıklar",
            onTap: () {
              Navigator.of(context).pop();
              _openAttendancePage();
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

  @override
  void dispose() {
    _startupController.removeListener(_handleStartupChanged);
    _notificationsInitTimer?.cancel();
    _updateCheckStartTimer?.cancel();
    _updateCheckTimer?.cancel();
    unawaited(_notificationNavigationSubscription?.cancel());
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tabAccentColor = _tabAccentColor(_tabController.index, colorScheme);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
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
              stream: FirebaseAuth.instance.userChanges(),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRect(
          child: AnimatedSlide(
            offset: _showHeader ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            child: AnimatedOpacity(
              opacity: _showHeader ? 1 : 0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              child: AppBar(
                backgroundColor: Color.lerp(
                  theme.scaffoldBackgroundColor,
                  colorScheme.onSurface,
                  0.035,
                ),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
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
                ],
              ),
            ),
          ),
        ),
      ),
      // Keep the content at a fixed Y position while the header animates over
      // it. Changing this padding when the header hides would move the page
      // and make the user's scroll position jump.
      body: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 64),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          transform: Matrix4.translationValues(0, _showHeader ? 0 : -64, 0),
          transformAlignment: Alignment.topCenter,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MasterBackgroundBlobs(accentColor: tabAccentColor),
                IndexedStack(
                  index: _tabController.index,
                  children: List<Widget>.generate(4, (index) {
                    return _tabBodies[index] ?? const SizedBox.expand();
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: FloatingClassicNavbar(
          currentIndex: _tabController.index,
          onDestinationSelected: _selectTab,
          onSettingsSelected: _openSettingsPage,
        ),
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
