import 'package:flutter/material.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/event_toggle.dart';
import 'package:omusiber/widgets/home/search_bar.dart';
import 'package:omusiber/widgets/no_events.dart';

class EventsTabView extends StatelessWidget {
  const EventsTabView({super.key});

  @override
  Widget build(BuildContext context) {
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
                    if (selectedIndex == 1) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: NoEventsFoundWidget(),
                      );
                    }
                    return Column(
                      children: [
                        const SizedBox(height: 8),
                        const ExpandableSearchBar(hintText: 'Etkinlik ara...'),
                        // Example Event 1
                        EventCard(
                          title:
                              "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
                          datetimeText: "11:00 AM, Perş 23 Ağustos",
                          location: "Samsun Teknoloji Merkezi, Atakum, Samsun",
                          imageAsset: "assets/image.png",
                          durationText: "Süre: 2 saat • 11:00 - 13:00",
                          ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                          capacityText: "Katılımcı Sayısı: 150",
                          description:
                              "Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                          tags: const [
                            EventTag(
                              "Ücretsiz",
                              Icons.money_off,
                              color: Colors.green,
                            ),
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
                          onJoin: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EventDetailsPage(),
                              ),
                            );
                          },
                          onBookmark: () {},
                          onShare: () {},
                        ),
                        EventCard(
                          title:
                              "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
                          datetimeText: "11:00 AM, Perş 23 Ağustos",
                          location: "Samsun Teknoloji Merkezi, Atakum, Samsun",
                          imageAsset: "assets/image.png",
                          durationText: "Süre: 2 saat • 11:00 - 13:00",
                          ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                          capacityText: "Katılımcı Sayısı: 150",
                          description:
                              "Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                          tags: const [
                            EventTag(
                              "Ücretsiz",
                              Icons.money_off,
                              color: Colors.green,
                            ),
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
                          location: "Samsun Teknoloji Merkezi, Atakum, Samsun",
                          imageAsset: "assets/image.png",
                          durationText: "Süre: 2 saat • 11:00 - 13:00",
                          ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                          capacityText: "Katılımcı Sayısı: 150",
                          description:
                              "Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                          tags: const [
                            EventTag(
                              "Ücretsiz",
                              Icons.money_off,
                              color: Colors.green,
                            ),
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
                          location: "Samsun Teknoloji Merkezi, Atakum, Samsun",
                          imageAsset: "assets/image.png",
                          durationText: "Süre: 2 saat • 11:00 - 13:00",
                          ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                          capacityText: "Katılımcı Sayısı: 150",
                          description:
                              "Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                          tags: const [
                            EventTag(
                              "Ücretsiz",
                              Icons.money_off,
                              color: Colors.green,
                            ),
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
                          location: "Samsun Teknoloji Merkezi, Atakum, Samsun",
                          imageAsset: "assets/image.png",
                          durationText: "Süre: 2 saat • 11:00 - 13:00",
                          ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
                          capacityText: "Katılımcı Sayısı: 150",
                          description:
                              "Bu etkinlikte konuşmacılar yapay zekâ, güvenlik ve modern mobil geliştirme pratiklerini anlatacak.",
                          tags: const [
                            EventTag(
                              "Ücretsiz",
                              Icons.money_off,
                              color: Colors.green,
                            ),
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
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }
}
