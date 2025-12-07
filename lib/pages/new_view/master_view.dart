import 'package:flutter/material.dart';
import 'package:omusiber/pages/new_view/events_tab_view.dart';
import 'package:omusiber/pages/new_view/news_tab_view.dart';
import 'package:omusiber/pages/new_view/notifications_tab_view.dart';
import 'package:omusiber/widgets/create_event_sheet.dart';
import 'package:omusiber/pages/new_view/settings_page.dart';

class MasterView extends StatefulWidget {
  const MasterView({super.key});

  @override
  State<MasterView> createState() => _MasterViewState();
}

class _MasterViewState extends State<MasterView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _appBarTitle = "Haberler";

  final List<bool> _unreadStates = [true, false, true];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _handleTabSelection(_tabController.index);
      }
    });
  }

  void _handleTabSelection(int index) {
    setState(() {
      switch (index) {
        case 0:
          _appBarTitle = "Haberler";
          break;
        case 1:
          _appBarTitle = "Etkinlikler";
          break;
        case 2:
          _appBarTitle = "Bildirimler";
          break;
      }
      if (_unreadStates[index]) {
        _unreadStates[index] = false;
      }
    });
  }

  void _openSettingsPage() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsPage()));
  }

  void _showCreateEventSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => CreateEventSheet(onCreate: (data) {}, onFinishLater: (data) {}),
    );
  }

  // UPDATED: Dynamic Collapsing Row
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

            // Logic: 6px (Gap) + 8px (Dot) = 14px
            width: isUnread ? 14.0 : 0.0,

            height: 8,
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),

            // FIX: Wrap inside SingleChildScrollView
            // This suppresses the error when the container is narrow (e.g. 5px)
            // but the content is wide (14px) during the animation.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(), // User can't scroll it
              child: Row(
                children: [
                  const SizedBox(width: 6), // The Gap
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
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

      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _showCreateEventSheet,
              child: Icon(Icons.add, color: colorScheme.onPrimaryContainer),
            )
          : null,

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _appBarTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
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

                    // Standard padding ensures good spacing when the dot is gone
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),

                    onTap: (index) => _handleTabSelection(index),

                    tabs: [
                      _buildBadgedTab(text: "Haberler", index: 0),
                      _buildBadgedTab(text: "Etkinlikler", index: 1),
                      _buildBadgedTab(text: "Bildirimler", index: 2),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: const [NewsTabView(), EventsTabView(), NotificationsTabView()],
        ),
      ),
    );
  }
}
