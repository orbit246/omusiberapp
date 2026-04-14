import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omusiber/backend/app_startup_controller.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';
import 'package:omusiber/backend/tab_badge_service.dart';
import 'package:omusiber/backend/startup_logger.dart';
import 'package:omusiber/pages/new_view/events_tab_view.dart';
import 'package:omusiber/pages/new_view/news_tab_view.dart';
import 'package:omusiber/pages/new_view/notifications_tab_view.dart';
import 'package:omusiber/pages/new_view/notes_tab_view.dart';
import 'package:omusiber/pages/new_view/community_tab_view.dart';
import 'package:omusiber/backend/update_service.dart';

import 'package:omusiber/pages/new_view/settings_page.dart';
import 'package:omusiber/pages/new_view/food_menu_page.dart';
import 'package:omusiber/pages/schedule_page.dart';
import 'package:omusiber/pages/new_view/academic_calendar_page.dart';

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

  void _openNotesPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotesTabView(showAppBar: true),
      ),
    );
  }

  Widget _buildBadgedTab({required String text, required int index}) {
    final bool isUnread = _unreadStates[index];

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: isUnread ? 14.0 : 0.0,
            height: 8,
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildDrawerPanel({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDrawerTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
        ),
        backgroundColor: colorScheme.surface,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            children: [
              _buildDrawerSectionTitle(context, "Kisisel"),
              _buildDrawerPanel(
                context: context,
                children: [
                  _buildDrawerTile(
                    context: context,
                    icon: Icons.edit_note_rounded,
                    title: "Notlar",
                    onTap: () {
                      Navigator.of(context).pop();
                      _openNotesPage();
                    },
                  ),
                ],
              ),
              _buildDrawerSectionTitle(context, "Araclar"),
              _buildDrawerPanel(
                context: context,
                children: [
                  _buildDrawerTile(
                    context: context,
                    icon: Icons.restaurant_menu,
                    title: "Yemek Menusu",
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const FoodMenuPage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    context: context,
                    icon: Icons.calendar_month,
                    title: "Ders Programi",
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SchedulePage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    context: context,
                    icon: Icons.description_outlined,
                    title: "Akademik Takvim",
                    onTap: () {
                      Navigator.of(context).pop();
                      _openAcademicCalendarSheet();
                    },
                  ),
                ],
              ),
            ],
          ),
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
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.16),
                  ),
                ),
                labelColor: colorScheme.primary,
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
                  colorScheme.primary.withValues(alpha: 0.06),
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
      body: IndexedStack(
        index: _tabController.index,
        children: List<Widget>.generate(3, (index) {
          return _tabBodies[index] ?? const SizedBox.expand();
        }),
      ),
    );
  }
}
