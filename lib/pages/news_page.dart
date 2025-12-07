import 'package:flutter/material.dart';
import 'package:omusiber/pages/new_view/events_tab_view.dart';
import 'package:omusiber/pages/new_view/news_tab_view.dart';
import 'package:omusiber/pages/new_view/notifications_tab_view.dart';
import 'package:omusiber/pages/new_view/settings_page.dart';
import 'package:omusiber/widgets/create_event_sheet.dart';
// Yeni oluşturduğumuz SettingsSheet'i import et

class MasterWidget extends StatefulWidget {
  const MasterWidget({super.key});

  @override
  State<MasterWidget> createState() => _MasterWidgetState();
}

class _MasterWidgetState extends State<MasterWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _appBarTitle = "Haberler";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
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
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Ayarlar Popup'ını açan fonksiyon
  void _showSettingsSheet() {
  }

  void _showCreateEventSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
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
                  // GÜNCELLENEN KISIM: Ayarlar Butonu
                  IconButton(
                    icon: Icon(Icons.settings, color: colorScheme.onSurface),
                    onPressed: _showSettingsSheet, // Artık yeni fonksiyonu çağırıyor
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