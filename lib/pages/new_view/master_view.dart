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
  }

  Future<void> _checkBadges() async {
    // 0: News
    final lastViewedNews = await _badgeService.getLastViewedNews();
    if (lastViewedNews != null) {
      final news = await NewsFetcher().fetchLatestNews(); // Use cache if avail
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
      final events = await EventRepository().fetchEvents();
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

    // 2: Notes (No badge usually)
    // _unreadStates[2] = false;

    // 3: Community
    final lastViewedCommunity = await _badgeService.getLastViewedCommunity();
    final posts = await CommunityRepository().fetchPosts();
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

              title: Row(
                children: [
                  Expanded(
                    child: Row(
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
                  ),
                  // Quick Access Menu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
                    onSelected: (value) {
                      if (value == 'food') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const FoodMenuPage(),
                          ),
                        );
                      } else if (value == 'schedule') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SchedulePage(),
                          ),
                        );
                      } else if (value == 'calendar') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            height: MediaQuery.of(context).size.height * 0.9,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            child: const AcademicCalendarPage(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'food',
                        child: Row(
                          children: [
                            Icon(Icons.restaurant_menu, size: 20),
                            SizedBox(width: 12),
                            Text("Yemek Menüsü"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'schedule',
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, size: 20),
                            SizedBox(width: 12),
                            Text("Ders Programı"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'calendar',
                        child: Row(
                          children: [
                            Icon(Icons.description_outlined, size: 20),
                            SizedBox(width: 12),
                            Text("Akademik Takvim"),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Notifications Button
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
                  // Settings Button
                  IconButton(
                    icon: Icon(Icons.settings, color: colorScheme.onSurface),
                    onPressed: _openSettingsPage,
                  ),
                ],
              ),
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
