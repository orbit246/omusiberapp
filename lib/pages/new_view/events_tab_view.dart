import 'package:flutter/material.dart';
import 'package:omusiber/backend/event_repository.dart';
import 'package:omusiber/backend/post_view.dart';
import 'package:omusiber/pages/removed/event_details_page.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/event_toggle.dart';
import 'package:omusiber/widgets/home/search_bar.dart';
import 'package:omusiber/widgets/no_events.dart';

class EventsTabView extends StatefulWidget {
  const EventsTabView({super.key});

  @override
  State<EventsTabView> createState() => _EventsTabViewState();
}

class _EventsTabViewState extends State<EventsTabView> {
  final EventRepository _repo = EventRepository();

  Future<List<PostView>>? _future;
  Object? _lastError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _lastError = null;
      _future = _repo.fetchEvents();
    });
  }

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
                        const SizedBox(height: 8),

                        FutureBuilder<List<PostView>>(
                          future: _future,
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              // Keep 3 example cards while loading
                              return Column(
                                children: const [
                                  _ExampleCard(),
                                  _ExampleCard(),
                                  _ExampleCard(),
                                ],
                              );
                            }

                            if (snap.hasError) {
                              _lastError = snap.error;
                              return _ErrorState(
                                error: snap.error,
                                onRetry: _refresh,
                              );
                            }

                            final events = snap.data ?? const <PostView>[];

                            if (events.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: _EmptyState(onRefresh: _refresh),
                              );
                            }

                            // Real data
                            return Column(
                              children: events.map((e) => _eventToCard(context, e)).toList(),
                            );
                          },
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

  Widget _eventToCard(BuildContext context, PostView e) {
    // Minimal defensive mapping. Your schema might be inconsistent at first.
    final imageUrl = (e.thubnailUrl.trim().isNotEmpty)
        ? e.thubnailUrl.trim()
        : (e.imageLinks.isNotEmpty ? e.imageLinks.first.trim() : '');

    final tags = e.tags.map((t) => EventTag(t, Icons.tag)).toList();

    // Optional metadata fields if you store them
    final duration = _stringFromMeta(e, 'durationText');
    final datetime = _stringFromMeta(e, 'datetimeText') ?? 'Tarih yok';
    final ticket = _stringFromMeta(e, 'ticketText') ??
        (e.ticketPrice <= 0 ? 'Bilet: Ücretsiz' : 'Bilet: ₺${e.ticketPrice.toStringAsFixed(0)}');
    final capacity = (e.maxContributors > 0)
        ? 'Katılımcı: ${e.remainingContributors}/${e.maxContributors}'
        : null;

    return EventCard(
      title: e.title,
      datetimeText: datetime,
      location: e.location,
      imageUrl: imageUrl,
      durationText: duration,
      ticketText: ticket,
      capacityText: capacity,
      description: e.description,
      tags: tags,
      onJoin: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailsPage()),
        );
      },
      onBookmark: () {},
      onShare: () {},
    );
  }

  String? _stringFromMeta(PostView e, String key) {
    final v = e.metadata[key];
    if (v == null) return null;
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return v.toString();
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard();

  @override
  Widget build(BuildContext context) {
    return EventCard(
      title: "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
      datetimeText: "11:00 AM, Perş 23 Ağustos",
      location: "Samsun Teknoloji Merkezi, Atakum, Samsun",
      // Use a non-network placeholder since this is only for loading.
      // Your EventCard already handles invalid URL with a fallback.
      imageUrl: "",
      durationText: "Süre: 2 saat • 11:00 - 13:00",
      ticketText: "Bilet: Ücretsiz • Kayıt gerekli",
      capacityText: "Katılımcı Sayısı: 150",
      description: "Yükleniyor...",
      tags: const [
        EventTag("Ücretsiz", Icons.money_off, color: Colors.green),
        EventTag("Siber Güvenlik", Icons.shield, color: Colors.blue),
        EventTag("Konuklu", Icons.person, color: Colors.orange),
        EventTag("Son 20 Bilet", Icons.radio_button_checked_sharp, color: Colors.purpleAccent),
      ],
      onJoin: null,
      onBookmark: null,
      onShare: null,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String msg = 'Bir hata oluştu.';
    final s = error?.toString() ?? '';
    if (s.contains('permission-denied')) msg = 'Erişim reddedildi.';
    if (s.contains('unauthenticated')) msg = 'Giriş yapmalısınız.';
    if (s.contains('unavailable')) msg = 'Servis şu an kullanılamıyor. İnternetinizi kontrol edin.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              s.isEmpty ? 'Bilinmeyen hata' : s,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar dene'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_busy_outlined),
          const SizedBox(width: 10),
          const Expanded(child: Text('Henüz etkinlik yok.')),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Yenile'),
          ),
        ],
      ),
    );
  }
}
