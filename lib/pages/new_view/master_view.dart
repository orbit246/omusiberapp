import 'package:flutter/material.dart';
import 'package:omusiber/backend/notifications/simple_push.dart';
import 'package:omusiber/backend/tab_badge_service.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/community_repository.dart';
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
import 'package:omusiber/pages/new_view/user_search_page.dart';

class MasterView extends StatefulWidget {
  const MasterView({super.key});

  @override
  State<MasterView> createState() => _MasterViewState();
}

class _MasterViewState extends State<MasterView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _appBarTitle = "Haberler";

  // News, Events, Notes, Community
  final List<bool> _unreadStates = [true, false, false, false];
  bool _unreadNotifications = false;

  final TabBadgeService _badgeService = TabBadgeService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _handleTabSelection(_tabController.index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SimpleNotifications().init();
    });

    // Check for badges
    _checkBadges();

    // Check for updates
    UpdateService().checkForUpdate();

    // Notification permission reminder after 30s
    _startPermissionReminder();
  }

  void _startPermissionReminder() {
    Future.delayed(const Duration(seconds: 30), () async {
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

  Future<void> _checkBadges() async {
    // 0: News
    final lastViewedNews = await _badgeService.getLastViewedNews();
    if (lastViewedNews != null) {
      // Use getCachedNews instead of fetchLatestNews to avoid network on startup
      final news = await NewsFetcher().getCachedNews();
      if (news.isNotEmpty) {
        final latest = news.first.publishedAt ?? DateTime.now();
        if (latest.isAfter(lastViewedNews)) {
          if (mounted) setState(() => _unreadStates[0] = true);
        } else {
          if (mounted) setState(() => _unreadStates[0] = false);
        }
      }
    } else {
      if (mounted) setState(() => _unreadStates[0] = true);
    }

    // 1: Events
    final lastViewedEvents = await _badgeService.getLastViewedEvents();
    if (lastViewedEvents != null) {
      // Use getCachedEvents to avoid network
      final events = await EventRepository().getCachedEvents();
      if (events.isNotEmpty) {
        DateTime? latestEventDate;
        for (final e in events) {
          final createdStr = e.metadata['createdAt'];
          if (createdStr != null) {
            final dt = DateTime.tryParse(createdStr);
            if (dt != null) {
              if (latestEventDate == null || dt.isAfter(latestEventDate)) {
                latestEventDate = dt;
              }
            }
          }
        }

        if (latestEventDate != null &&
            latestEventDate.isAfter(lastViewedEvents)) {
          if (mounted) setState(() => _unreadStates[1] = true);
        } else {
          if (mounted) setState(() => _unreadStates[1] = false);
        }
      }
    } else {
      if (mounted) setState(() => _unreadStates[1] = true);
    }

    // Notifications (Discrete Badge)
    final lastViewedNotifs = await _badgeService.getLastViewedNotifs();
    final notifs = await SimpleNotifications().loadSaved();
    if (notifs.isNotEmpty) {
      final latest = notifs.first.receivedAt;
      if (lastViewedNotifs == null || latest.isAfter(lastViewedNotifs)) {
        if (mounted) setState(() => _unreadNotifications = true);
      } else {
        if (mounted) setState(() => _unreadNotifications = false);
      }
    }

    // 3: Community
    final lastViewedCommunity = await _badgeService.getLastViewedCommunity();
    // CommunityRepository currently doesn't have persistent cache, but it has mock data
    final posts = await CommunityRepository().getCachedPosts();
    if (posts.isNotEmpty) {
      final latest = posts.first.createdAt;
      if (lastViewedCommunity == null || latest.isAfter(lastViewedCommunity)) {
        if (mounted) setState(() => _unreadStates[3] = true);
      } else {
        if (mounted) setState(() => _unreadStates[3] = false);
      }
    }
  }

  void _handleTabSelection(int index) {
    setState(() {
      switch (index) {
        case 0:
          _appBarTitle = "Haberler";
          _badgeService.markNewsViewed();
          break;
        case 1:
          _appBarTitle = "Etkinlikler";
          _badgeService.markEventsViewed();
          break;
        case 2:
          _appBarTitle = "Notlar";
          break;
        case 3:
          _appBarTitle = "Topluluk";
          _badgeService.markCommunityViewed();
          break;
      }
      if (_unreadStates[index]) {
        _unreadStates[index] = false;
      }
    });
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

  Widget _buildDrawerTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }

  BoxDecoration _buildShellDecoration(
    BuildContext context, {
    bool emphasize = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: colorScheme.surface.withValues(alpha: isDark ? 0.92 : 0.86),
      borderRadius: BorderRadius.circular(emphasize ? 30 : 26),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(
          alpha: isDark ? 0.28 : 0.55,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: isDark ? 0.18 : 0.08),
          blurRadius: emphasize ? 28 : 22,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Widget _buildShellButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onPressed,
    Widget? child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.34 : 0.72,
      ),
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
        ),
        backgroundColor: colorScheme.surface,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              _buildDrawerSectionTitle(context, "Araclar"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
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
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                    theme.scaffoldBackgroundColor,
                    theme.scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 0.22, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -30,
            child: IgnorePointer(
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.12 : 0.10,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 86,
            right: -48,
            child: IgnorePointer(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.secondary.withValues(
                    alpha: isDark ? 0.08 : 0.08,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Container(
                    height: 62,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: _buildShellDecoration(context, emphasize: true),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            Builder(
                              builder: (context) => _buildShellButton(
                                context: context,
                                icon: Icons.menu_rounded,
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                              ),
                            ),
                            const Spacer(),
                            if (_tabController.index == 3) ...[
                              _buildShellButton(
                                context: context,
                                icon: Icons.search_rounded,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const UserSearchPage(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                            _buildShellButton(
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
                            const SizedBox(width: 8),
                            _buildShellButton(
                              context: context,
                              icon: Icons.settings_outlined,
                              onPressed: _openSettingsPage,
                            ),
                          ],
                        ),
                        IgnorePointer(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.08),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Row(
                                  key: ValueKey(_appBarTitle),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _appBarTitle,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                    if (_tabController.index == 2) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.all(6),
                    decoration: _buildShellDecoration(context),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.24 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      labelColor: colorScheme.primary,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                      splashBorderRadius: BorderRadius.circular(18),
                      overlayColor: WidgetStatePropertyAll(
                        colorScheme.primary.withValues(alpha: 0.06),
                      ),
                      onTap: (index) => _handleTabSelection(index),
                      tabs: [
                        _buildBadgedTab(text: "Haberler", index: 0),
                        _buildBadgedTab(text: "Etkinlikler", index: 1),
                        _buildBadgedTab(text: "Notlar", index: 2),
                        _buildBadgedTab(text: "Topluluk", index: 3),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      NewsTabView(),
                      EventsTabView(),
                      NotesTabView(),
                      CommunityTabView(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
