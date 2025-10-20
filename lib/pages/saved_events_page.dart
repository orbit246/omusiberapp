import 'package:flutter/material.dart';
import 'package:omusiber/widgets/home/simple_appbar.dart';
import 'package:omusiber/widgets/saved_events/saved_events_appbar.dart';
import 'package:omusiber/widgets/shared/navbar.dart';

class SavedEventsPage extends StatelessWidget {
  const SavedEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Scaffold(
      bottomNavigationBar: AppNavigationBar(),
      appBar: PreferredSize(preferredSize: const Size.fromHeight(60), child: SimpleAppbar(title: "Kaydedilenler")),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // Image with rounded corners & elevation via Card
                    SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset("assets/image.png", fit: BoxFit.cover),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Title
                    Text(
                      "Etkinlik Adı — Çok Uzun Başlık Buraya Sığar ve En Fazla İki Satır Olur",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),

                    const Divider(),

                    // Info rows (you can keep your Item widget;
                    // here’s a theme-friendly ListTile version)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.calendar_today),
                      title: Text("Tarih / Zaman", style: tt.labelLarge),
                      subtitle: const Text("11:00 AM, Perş 23 Ağustos"),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const Divider(),

                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on),
                      title: Text("Lokasyon", style: tt.labelLarge),
                      subtitle: const Text("Samsun Teknoloji Merkezi, Atakum"),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const Divider(),
                    const SizedBox(height: 8),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 45,
                            child: ElevatedButton(
                              onPressed: () {},
                              child: Text("Detaylar", style: Theme.of(context).textTheme.labelLarge),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Use filled-tonal icon buttons for surfaceVariant backgrounds
                        IconButton.filledTonal(
                          onPressed: () {},
                          icon: const Icon(Icons.bookmark_outline),
                          style: ButtonStyle(
                            fixedSize: const WidgetStatePropertyAll(Size(45, 45)),
                            backgroundColor: WidgetStatePropertyAll(cs.surfaceVariant),
                            iconSize: const WidgetStatePropertyAll(28),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          onPressed: () {},
                          icon: const Icon(Icons.share_outlined),
                          style: ButtonStyle(
                            fixedSize: const WidgetStatePropertyAll(Size(45, 45)),
                            backgroundColor: WidgetStatePropertyAll(cs.surfaceVariant),
                            iconSize: const WidgetStatePropertyAll(28),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
