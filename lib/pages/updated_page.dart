import 'package:flutter/material.dart';
import 'package:omusiber/widgets/create_event_sheet.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/event_toggle.dart';
import 'package:omusiber/widgets/no_events.dart';
import 'package:omusiber/widgets/shared/navbar.dart';

class SimplifiedHomePageState extends StatefulWidget {
  const SimplifiedHomePageState({super.key});
  static final selectedIndexNotifier = ValueNotifier<int>(0);

  @override
  State<SimplifiedHomePageState> createState() =>
      SimplifiedHomePageStateState();
}

class SimplifiedHomePageStateState extends State<SimplifiedHomePageState> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // optional: explicitly set background if you want
      floatingActionButton: FloatingActionButton(
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
                  // data.title, data.description, data.tags, data.imageBytes (nullable)
                },
                onFinishLater: (data) {
                  // TODO: handle "Finish later" (save draft)
                },
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    
      bottomNavigationBar: AppNavigationBar(),
    
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsetsGeometry.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(width: 28),
                    Spacer(),
                    Text(
                      "Etkinlikler",
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Spacer(),
                    Icon(Icons.search, size: 28),
                  ],
                ),
    
                SizedBox(height: 14),
                Center(child: EventToggle()),
                ValueListenableBuilder(
                  valueListenable: EventToggle.selectedIndexNotifier,
                  builder: (context, int selectedIndex, _) {
                    return selectedIndex == 1
                        ? const NoEventsFoundWidget()
                        : Column(
                            children: [
                              EventCard(
                                title:
                                    "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
                                datetimeText: "11:00 AM, Perş 23 Ağustos",
                                location:
                                    "Samsun Teknoloji Merkezi, Atakum, Samsun",
                                imageAsset: "assets/image.png",
                                durationText: "Süre: 2 saat • 11:00 - 13:00",
                                ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                                capacityText: "Katılımcı Sayısı: 150",
                                description:
                                    "Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                                tags: const [
                                  EventTag("Ücretsiz", Icons.money_off),
                                  EventTag(
                                    "Siber Güvenlik",
                                    Icons.shield,
                                    color: Colors.blue,
                                  ),
                                  EventTag(
                                    "Konuklu",
                                    Icons.person,
                                    color: Colors.orange,
                                  ),
                                  EventTag(
                                    "Son 20 Bilet",
                                    Icons.radio_button_checked_sharp,
                                    color: Colors.purpleAccent,
                                  ),
                                ],
                                onJoin: () {},
                                onBookmark: () {},
                                onShare: () {},
                              ),
                              EventCard(
                                title:
                                    "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
                                datetimeText: "11:00 AM, Perş 23 Ağustos",
                                location:
                                    "Samsun Teknoloji Merkezi, Atakum, Samsun",
                                imageAsset: "assets/image.png",
                                durationText: "Süre: 2 saat • 11:00 - 13:00",
                                ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                                capacityText: "Katılımcı Sayısı: 150",
                                description:
                                    "Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                                tags: const [
                                  EventTag("Ücretsiz", Icons.money_off),
                                  EventTag(
                                    "Siber Güvenlik",
                                    Icons.shield,
                                    color: Colors.blue,
                                  ),
                                  EventTag(
                                    "Konuklu",
                                    Icons.person,
                                    color: Colors.orange,
                                  ),
                                  EventTag(
                                    "Son 20 Bilet",
                                    Icons.radio_button_checked_sharp,
                                    color: Colors.purpleAccent,
                                  ),
                                ],
                                onJoin: () {},
                                onBookmark: () {},
                                onShare: () {},
                              ),
                              EventCard(
                                title:
                                    "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
                                datetimeText: "11:00 AM, Perş 23 Ağustos",
                                location:
                                    "Samsun Teknoloji Merkezi, Atakum, Samsun",
                                imageAsset: "assets/image.png",
                                durationText: "Süre: 2 saat • 11:00 - 13:00",
                                ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                                capacityText: "Katılımcı Sayısı: 150",
                                description:
                                    "Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                                tags: const [
                                  EventTag("Ücretsiz", Icons.money_off),
                                  EventTag(
                                    "Siber Güvenlik",
                                    Icons.shield,
                                    color: Colors.blue,
                                  ),
                                  EventTag(
                                    "Konuklu",
                                    Icons.person,
                                    color: Colors.orange,
                                  ),
                                  EventTag(
                                    "Son 20 Bilet",
                                    Icons.radio_button_checked_sharp,
                                    color: Colors.purpleAccent,
                                  ),
                                ],
                                onJoin: () {},
                                onBookmark: () {},
                                onShare: () {},
                              ),
                              EventCard(
                                title:
                                    "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
                                datetimeText: "11:00 AM, Perş 23 Ağustos",
                                location:
                                    "Samsun Teknoloji Merkezi, Atakum, Samsun",
                                imageAsset: "assets/image.png",
                                durationText: "Süre: 2 saat • 11:00 - 13:00",
                                ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                                capacityText: "Katılımcı Sayısı: 150",
                                description:
                                    "Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                                tags: const [
                                  EventTag("Ücretsiz", Icons.money_off),
                                  EventTag(
                                    "Siber Güvenlik",
                                    Icons.shield,
                                    color: Colors.blue,
                                  ),
                                  EventTag(
                                    "Konuklu",
                                    Icons.person,
                                    color: Colors.orange,
                                  ),
                                  EventTag(
                                    "Son 20 Bilet",
                                    Icons.radio_button_checked_sharp,
                                    color: Colors.purpleAccent,
                                  ),
                                ],
                                onJoin: () {},
                                onBookmark: () {},
                                onShare: () {},
                              ),
                              EventCard(
                                title:
                                    "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
                                datetimeText: "11:00 AM, Perş 23 Ağustos",
                                location:
                                    "Samsun Teknoloji Merkezi, Atakum, Samsun",
                                imageAsset: "assets/image.png",
                                durationText: "Süre: 2 saat • 11:00 - 13:00",
                                ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                                capacityText: "Katılımcı Sayısı: 150",
                                description:
                                    "Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                                tags: const [
                                  EventTag("Ücretsiz", Icons.money_off),
                                  EventTag(
                                    "Siber Güvenlik",
                                    Icons.shield,
                                    color: Colors.blue,
                                  ),
                                  EventTag(
                                    "Konuklu",
                                    Icons.person,
                                    color: Colors.orange,
                                  ),
                                  EventTag(
                                    "Son 20 Bilet",
                                    Icons.radio_button_checked_sharp,
                                    color: Colors.purpleAccent,
                                  ),
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
      ),
    );
  }
}
