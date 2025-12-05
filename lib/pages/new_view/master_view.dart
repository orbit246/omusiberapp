import 'package:flutter/material.dart';
import 'package:omusiber/pages/new_view/events_tab_view.dart';
import 'package:omusiber/pages/new_view/news_tab_view.dart';
import 'package:omusiber/pages/new_view/notifications_tab_view.dart';
import 'package:omusiber/pages/new_view/settings_sheet.dart';
import 'package:omusiber/widgets/create_event_sheet.dart';

class MasterView extends StatefulWidget {
  const MasterView({super.key});

  @override
  State<MasterView> createState() => _MasterViewState();
}

class _MasterViewState extends State<MasterView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _appBarTitle = "Haberler";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _updateAppBar(_tabController.index);
      }
    });
  }

  void _updateAppBar(int index) {
    setState(() {
      switch (index) {
        case 0: _appBarTitle = "Haberler"; break;
        case 1: _appBarTitle = "Etkinlikler"; break;
        case 2: _appBarTitle = "Bildirimler"; break;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 2. UPDATED FUNCTION: Navigates to the new page
  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  void _showCreateEventSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      useRootNavigator: true, 
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        return CreateEventSheet(
          onCreate: (data) {},
          onFinishLater: (data) {},
        );
      },
    );
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
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
              pinned: true,
              floating: true,
              snap: true,
              scrolledUnderElevation: 2,
              
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
                  // 3. UPDATED BUTTON ACTION
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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onTap: (index) => _updateAppBar(index),
                    tabs: const [
                      Tab(text: "Haberler"),
                      Tab(text: "Etkinlikler"),
                      Tab(text: "Bildirimler"),
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
            NotificationsTabView(),
          ],
        ),
      ),
    );
  }
}