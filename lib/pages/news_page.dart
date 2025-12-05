import 'package:flutter/material.dart';
import 'package:omusiber/backend/news_fetcher.dart';
import 'package:omusiber/widgets/news/fetch_news_button.dart';
import 'package:omusiber/widgets/news/news_card.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/event_toggle.dart';
import 'package:omusiber/widgets/home/search_bar.dart';
import 'package:omusiber/widgets/no_events.dart';
import 'package:omusiber/widgets/create_event_sheet.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Default title
  String _appBarTitle = "Haberler";

  @override
  void initState() {
    super.initState();
    // Initialize controller for 3 tabs
    _tabController = TabController(length: 3, vsync: this);
    
    // Listen to tab changes to update Title and FAB
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      
      // Floating Action Button: Only show on "Etkinlikler" (Index 1)
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  builder: (context) {
                    return CreateEventSheet(
                      onCreate: (data) {
                        // TODO: handle "Create"
                      },
                      onFinishLater: (data) {
                        // TODO: handle "Finish later"
                      },
                    );
                  },
                );
              },
              child: Icon(Icons.add, color: colorScheme.onPrimaryContainer),
            )
          : null,

      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surface,
              pinned: true,
              floating: true,
              snap: true,
              forceMaterialTransparency: false,
              elevation: 0,
              scrolledUnderElevation: 2,
              toolbarHeight: 60,
              
              // Dynamic Title + Gear Icon
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
                    onPressed: () {
                      // TODO: Implement settings
                    },
                  ),
                ],
              ),
              
              // Tabs: Haberler -> Etkinlikler -> Bildirimler
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
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    labelColor: colorScheme.primary,
                    labelStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelColor: colorScheme.onSurfaceVariant.withOpacity(0.6),
                    unselectedLabelStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
          children: [
            // TAB 1: Haberler
            _buildNewsTab(context),

            // TAB 2: Etkinlikler
            _buildEventsTab(context),

            // TAB 3: Bildirimler
            _buildNotificationsTab(colorScheme),
          ],
        ),
      ),
    );
  }

  // --- Helper: News Tab ---
  Widget _buildNewsTab(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey('news_tab'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FutureBuilder(
              future: NewsFetcher().fetchLatestNews(),
              builder: (context, asyncSnapshot) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: FetchNewsButton(
                        onFetch: () async {
                          await Future.delayed(const Duration(seconds: 5));
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (asyncSnapshot.connectionState == ConnectionState.waiting)
                      const CircularProgressIndicator()
                    else if (asyncSnapshot.hasError)
                      Text(
                        "Haberler yüklenirken bir hata oluştu.${asyncSnapshot.error}",
                        textAlign: TextAlign.center,
                      )
                    else if (asyncSnapshot.hasData)
                      ...asyncSnapshot.data!
                          .map((newsView) => Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: NewsCard(view: newsView),
                              ))
                          .toList(),
                    const SizedBox(height: 80), // Extra padding for scrolling
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Helper: Events Tab ---
  // Converted to CustomScrollView to fix the "1 pixel overflow" glitch in NestedScrollView
  Widget _buildEventsTab(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey('events_tab'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              children: [
                const SizedBox(height: 14),
                const Center(child: EventToggle()),
                ValueListenableBuilder(
                  valueListenable: EventToggle.selectedIndexNotifier,
                  builder: (context, int selectedIndex, _) {
                    return selectedIndex == 1
                        ? const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: NoEventsFoundWidget(),
                          )
                        : Column(
                            children: [
                              const SizedBox(height: 8),
                              const ExpandableSearchBar(hintText: 'Etkinlik ara...'),
                              EventCard(
                                title: "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar",
                                datetimeText: "11:00 AM, Perş 23 Ağustos",
                                location: "Samsun Teknoloji Merkezi",
                                imageAsset: "assets/image.png",
                                durationText: "Süre: 2 saat • 11:00 - 13:00",
                                ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                                capacityText: "Katılımcı Sayısı: 150",
                                description: "Bu etkinlikte konuşmacılar yapay zekâ ve güvenlik anlatacak.",
                                tags: const [
                                  EventTag("Ücretsiz", Icons.money_off, color: Colors.green),
                                  EventTag("Siber Güvenlik", Icons.shield, color: Colors.blue),
                                ],
                                onJoin: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EventDetailsPage()));
                                },
                                onBookmark: () {},
                                onShare: () {},
                              ),
                              EventCard(
                                title: "Flutter Geliştirici Zirvesi",
                                datetimeText: "09:00 AM, Cuma 24 Ağustos",
                                location: "OMÜ Mühendislik Fakültesi",
                                imageAsset: "assets/image.png",
                                durationText: "Süre: 4 saat",
                                ticketText: "Bilet: Ücretsiz",
                                capacityText: "Katılımcı Sayısı: 200",
                                description: "Mobil uygulama geliştirme trendleri ve Flutter ekosistemi.",
                                tags: const [
                                  EventTag("Konuklu", Icons.person, color: Colors.orange),
                                  EventTag("Son 20 Bilet", Icons.radio_button_checked, color: Colors.purpleAccent),
                                ],
                                onJoin: () {},
                                onBookmark: () {},
                                onShare: () {},
                              ),
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ),
        // Add bottom padding to avoid FAB overlap
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  // --- Helper: Notifications Tab ---
  Widget _buildNotificationsTab(ColorScheme colorScheme) {
    return CustomScrollView(
      key: const PageStorageKey('notifs_tab'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(Icons.notifications, size: 20, color: colorScheme.primary),
                      ),
                      title: const Text(
                        "Yeni bir duyuru yayınlandı",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "2 saat önce • Sistem",
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                    Divider(color: colorScheme.outlineVariant.withOpacity(0.3)),
                  ],
                );
              },
              childCount: 8,
            ),
          ),
        ),
      ],
    );
  }
}