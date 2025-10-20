import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:omusiber/widgets/event_card.dart';
import 'package:omusiber/widgets/event_details/event_details_appbar.dart';
import 'package:omusiber/widgets/home/simple_appbar.dart';
import 'package:omusiber/widgets/shared/square_action.dart';

class EventDetailsPage extends StatelessWidget {
  const EventDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: SimpleAppbar(title: "Detaylar"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: ListView(
                  children: [
                    Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Stack(
                        children: [
                          SizedBox(
                            height: 250,
                            child: CarouselSlider(
                              options: CarouselOptions(height: 250, viewportFraction: 1, enableInfiniteScroll: false),
                              items: [1, 2, 3, 4, 5].map((i) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 5),
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  child: Center(
                                    child: Text('Resim $i', style: Theme.of(context).textTheme.headlineMedium),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            right: 4,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: const [
                                TagChip(tag: EventTag("Ücretsiz", Icons.money_off)),
                                TagChip(tag: EventTag("Siber Güvenlik", Icons.shield, color: Colors.blue)),
                                TagChip(tag: EventTag("Konuklu", Icons.person, color: Colors.orange)),
                                TagChip(tag: EventTag("Android", Icons.android, color: Colors.blueAccent)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Location
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Samsun Teknoloji Merkezi, Atakum (Mekan bilgisi çok uzun olabilir ve taşabilir)",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),

                    // Title & description
                    Text(
                      'Android Development Workshop',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    // Your cards (no nested scrolling)
                    const SizedBox(height: 12),
                    ...List.generate(5, (_) => newMethod(context)),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // Pinned bottom actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.event_available, size: 20, color: Theme.of(context).colorScheme.onSurface),
                      label: Text("Katıl", style: Theme.of(context).textTheme.labelLarge),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SquareEventAction(icon: Icons.bookmark_outline, onTap: () {}),
                  const SizedBox(width: 6),
                  SquareEventAction(icon: Icons.share_outlined, onTap: () {}),
                  const SizedBox(width: 6),
                  SquareEventAction(icon: Icons.alarm, onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Card newMethod(BuildContext context) {
  return Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.image, color: Theme.of(context).colorScheme.onSurface),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Placeholder Title',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Placeholder Subtitle',
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
