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

    // Initialize Push Notifications
    SimpleNotifications().init();

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

  @override
  void dispose() {
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

      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: theme.appBarTheme.backgroundColor,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              floating: true,
              snap: true,
              scrolledUnderElevation: 0,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, color: colorScheme.onSurface),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              centerTitle: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _appBarTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (_tabController.index == 2) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ],
                ],
              ),
              actions: [
                if (_tabController.index == 3)
                  IconButton(
                    icon: Icon(Icons.search, color: colorScheme.onSurface),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const UserSearchPage(),
                        ),
                      );
                    },
                  ),
                IconButton(
                  icon: Badge(
                    isLabelVisible: _unreadNotifications,
                    smallSize: 8,
                    child: Icon(
                      Icons.notifications_outlined,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  onPressed: _openNotificationsPage,
                ),
                IconButton(
                  icon: Icon(Icons.settings, color: colorScheme.onSurface),
                  onPressed: _openSettingsPage,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    indicatorColor: colorScheme.primary,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
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
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: const [
            NewsTabView(),
            EventsTabView(),
            NotesTabView(),
            CommunityTabView(),
          ],
        ),
      ),
    );
  }
}
