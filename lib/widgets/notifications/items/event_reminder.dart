import 'package:flutter/material.dart';

class EventReminder extends StatelessWidget {
  const EventReminder({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications, size: 28, color: Colors.yellow),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Yaklaşan Etkinlik',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 22),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "20 Eylül 2024 - Flutter Geliştirici Konferansı",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Stack(
                children: [
                  Image(image: AssetImage('assets/image.png'), fit: BoxFit.fitWidth),
                  /*    Positioned(
                              top: 4,
                              left: 4,
                              right: 4,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  TagChip(tag: EventTag("Ücretsiz", Icons.money_off)),
                                  TagChip(tag: EventTag("Siber Güvenlik", Icons.shield, color: Colors.blue)),
                                  TagChip(tag: EventTag("Konuklu", Icons.person, color: Colors.orange)),
                                  TagChip(
                                    tag: EventTag(
                                      "Son 20 Bilet",
                                      Icons.radio_button_checked_sharp,
                                      color: Colors.purpleAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ), */
                ],
              ),
            ),
            SizedBox(height: 10),
            Row(
              spacing: 6,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),

                      elevation: MaterialStateProperty.all<double>(4),
                    ),

                    child: Row(
                      children: [
                        Text('Detayları Gör', style: Theme.of(context).textTheme.bodyLarge),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios, size: 20, color: Theme.of(context).colorScheme.onSurface),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
